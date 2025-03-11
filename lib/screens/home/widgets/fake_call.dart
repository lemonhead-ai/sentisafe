import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({Key? key}) : super(key: key);

  @override
  _FakeCallScreenState createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isCallActive = false;
  bool _isIncomingCall = false;
  Timer? _callTimer;
  Timer? _durationTimer;
  int _delaySeconds = 10;
  int _callDuration = 0;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  String? _selectedContactName;
  String? _selectedContactPhone;
  DateTime _currentCallTime = DateTime.now();
  bool _isSpeakerOn = false;
  bool _isMuted = false;
  final Random _random = Random();
  List<String> _emergencyContacts = [];
  int _countdownValue = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // For testing, add a default contact if none exist
      final contacts = prefs.getStringList('emergency_contacts') ?? [];
      if (contacts.isEmpty) {
        _emergencyContacts = ['Emergency Contact - 555-123-4567'];
      } else {
        _emergencyContacts = contacts;
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _callTimer?.cancel();
    _durationTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getCurrentTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  Future<void> _startFakeCall(BuildContext context) async {
    if (_emergencyContacts.isEmpty) {
      _showNoContactsError();
      return;
    }

    // Randomly select a contact
    final randomContact =
    _emergencyContacts[_random.nextInt(_emergencyContacts.length)];

    // Extract name if the contact is in "Name - Number" format
    final contactParts = randomContact.split(' - ');
    final contactName = contactParts.length > 1 ? contactParts[0] : 'Unknown';
    final contactPhone =
    contactParts.length > 1 ? contactParts[1] : randomContact;

    setState(() {
      _selectedContactName = contactName;
      _selectedContactPhone = contactPhone;
      _isCallActive = false;
      _isIncomingCall = false;
      _currentCallTime = DateTime.now();
      _countdownValue = _delaySeconds;
    });

    // Start countdown timer directly in the state
    _startCountdownTimer(context);
  }

  void _startCountdownTimer(BuildContext context) {
    // Show countdown dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }
              setState(() {
                if (_countdownValue > 0) {
                  _countdownValue--;
                } else {
                  timer.cancel();
                  Navigator.of(dialogContext).pop();
                  // Important: Use the original context, not the dialog context
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showIncomingCallScreen(context);
                  });
                }
              });
            });

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Incoming call in $_countdownValue seconds',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _callTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNoContactsError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Emergency Contacts'),
          content: const Text(
            'Please add emergency contacts in the contacts section first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showIncomingCallScreen(BuildContext context) async {
    if (!mounted) return;

    setState(() {
      _isIncomingCall = true;
    });

    // Start bouncing animation
    _bounceController.repeat();

    // Start vibration
    HapticFeedback.vibrate();
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isIncomingCall || !mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.vibrate();
    });

    // Play ringtone using audioplayers
    try {
      await _audioPlayer.play(AssetSource('audio/custom_ringtone.mp3'));
      _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the ringtone
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: _buildCallScreen(context),
        );
      },
    );
  }

  Widget _buildCallScreen(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Dialog.fullscreen(
      backgroundColor: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // Background pattern for iOS-like call screen
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: statusBarHeight, bottom: 16),
                  child: Text(
                    _getCurrentTime(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ),
                const Spacer(flex: 1),
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isIncomingCall && !_isCallActive
                          ? _bounceAnimation.value
                          : 1.0,
                      child: Hero(
                        tag: 'contactAvatar',
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.blue[700],
                          child: Text(
                            _selectedContactName?[0] ?? 'U',
                            style: const TextStyle(fontSize: 60, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _selectedContactName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedContactPhone ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isCallActive)
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.wifi_calling_3,
                              size: 16,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cellular Call',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const Spacer(flex: 2),
                if (_isCallActive) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCallButton(
                          icon: Icons.add_call,
                          color: Colors.transparent,
                          backgroundColor: Colors.white24,
                          onPressed: () {},
                          label: 'Add',
                        ),
                        _buildCallButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          color: _isMuted ? Colors.white : Colors.white70,
                          backgroundColor: _isMuted ? Colors.white24 : Colors.white10,
                          onPressed: () {
                            setState(() => _isMuted = !_isMuted);
                          },
                          label: 'Mute',
                        ),
                        _buildCallButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_up_outlined,
                          color: _isSpeakerOn ? Colors.white : Colors.white70,
                          backgroundColor: _isSpeakerOn ? Colors.white24 : Colors.white10,
                          onPressed: () {
                            setState(() => _isSpeakerOn = !_isSpeakerOn);
                            // Set volume based on speaker state
                            _audioPlayer.setVolume(_isSpeakerOn ? 1.0 : 0.5);
                          },
                          label: 'Speaker',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isCallActive) ...[
                        _buildActionButton(
                          icon: Icons.message,
                          backgroundColor: Colors.white30,
                          label: 'Message',
                          onPressed: () {
                            _audioPlayer.stop();
                            Navigator.of(context).pop();
                            setState(() {
                              _isIncomingCall = false;
                            });
                          },
                        ),
                        const SizedBox(width: 24),
                        _buildActionButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          label: 'Decline',
                          onPressed: () {
                            _audioPlayer.stop();
                            Navigator.of(context).pop();
                            setState(() {
                              _isIncomingCall = false;
                            });
                          },
                        ),
                        const SizedBox(width: 24),
                        _buildActionButton(
                          icon: Icons.call,
                          backgroundColor: Colors.green,
                          label: 'Accept',
                          onPressed: () {
                            _audioPlayer.stop();
                            _bounceController.stop();
                            setState(() {
                              _isCallActive = true;
                              _isIncomingCall = false;
                              _callDuration = 0;
                            });
                            _startDurationTimer();
                          },
                        ),
                      ] else
                        _buildActionButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          label: 'End',
                          onPressed: () {
                            _durationTimer?.cancel();
                            Navigator.of(context).pop();
                            setState(() {
                              _isCallActive = false;
                              _isIncomingCall = false;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
          child: Icon(
            icon,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _callDuration++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fake Call',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 48,
                      color: accentColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Schedule your escape call',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your phone will ring after the selected delay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _delaySeconds,
                          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: textColor.withOpacity(0.7),
                          ),
                          isExpanded: true,
                          items: [5, 10, 15, 30, 60, 120]
                              .map((int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              value < 60
                                  ? '$value seconds'
                                  : '${value ~/ 60} ${value == 60 ? 'minute' : 'minutes'}',
                            ),
                          ))
                              .toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _delaySeconds = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isIncomingCall ? null : () => _startFakeCall(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Schedule Fake Call',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_emergencyContacts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Available Contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _emergencyContacts.length > 3
                        ? 3
                        : _emergencyContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _emergencyContacts[index];
                      final contactParts = contact.split(' - ');
                      final name = contactParts.length > 1
                          ? contactParts[0]
                          : 'Unknown';
                      final phone = contactParts.length > 1
                          ? contactParts[1]
                          : contact;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accentColor.withOpacity(0.2),
                          child: Text(
                            name[0],
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          phone,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}