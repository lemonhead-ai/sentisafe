import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({Key? key}) : super(key: key);

  @override
  _VoiceRecordScreenState createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  final Record _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentFilePath;
  List<String> _recordings = [];
  int? _playingIndex;
  String _recordingDuration = '00:00';
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _setupDurationTimer();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupDurationTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          final difference = DateTime.now().difference(_recordingStartTime!);
          _recordingDuration = _formatDuration(difference);
        });
        _setupDurationTimer();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _loadRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = dir.listSync();
      final recordingFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.m4a'))
          .map((file) => file.path)
          .toList();

      setState(() {
        _recordings = recordingFiles;
      });
    } catch (e) {
      print('Error loading recordings: $e');
    }
  }

  String _getRecordingName(String path) {
    final fileName = path.split('/').last;
    if (fileName.startsWith('recording_')) {
      // Extract timestamp and format it
      final timestampStr = fileName.split('_')[1].split('.')[0];
      final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
      return DateFormat('MMM dd, yyyy - HH:mm:ss').format(timestamp);
    }
    return fileName;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _currentFilePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(path: _currentFilePath!);
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = '00:00';
        });
        _setupDurationTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      await _loadRecordings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _playRecording(int index) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.setFilePath(_recordings[index]);
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isPlaying = false;
            _playingIndex = null;
          });
        }
      });

      await _audioPlayer.play();
      setState(() {
        _isPlaying = true;
        _playingIndex = index;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing recording: $e')),
      );
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingIndex = null;
      });
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  Future<void> _deleteRecording(int index) async {
    try {
      final file = File(_recordings[index]);
      if (await file.exists()) {
        await file.delete();
        await _loadRecordings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.indigo),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All recordings are stored only on your device and never uploaded anywhere.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Recorder section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red.shade100 : Colors.grey.shade100,
                      ),
                      child: IconButton(
                        iconSize: 50,
                        icon: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          color: _isRecording ? Colors.red : Colors.grey.shade700,
                        ),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? _recordingDuration : 'Ready to Record',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: _isRecording ? Colors.red : Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recordings list header
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.list, size: 20),
                SizedBox(width: 8),
                Text(
                  'Your Recordings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Recordings list
          Expanded(
            child: _recordings.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                final isPlaying = _playingIndex == index && _isPlaying;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isPlaying ? Colors.indigo.shade100 : Colors.grey.shade100,
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: isPlaying ? Colors.indigo : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      _getRecordingName(_recordings[index]),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Tap to ${isPlaying ? 'pause' : 'play'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteRecording(index),
                    ),
                    onTap: () {
                      if (isPlaying) {
                        _stopPlaying();
                      } else {
                        _playRecording(index);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}