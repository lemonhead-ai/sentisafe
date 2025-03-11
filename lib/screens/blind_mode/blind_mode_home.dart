import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

class BlindModeHome extends StatefulWidget {
  final List<CameraDescription> cameras;

  const BlindModeHome({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  _BlindModeHomeState createState() => _BlindModeHomeState();
}

class _BlindModeHomeState extends State<BlindModeHome>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  late FlutterTts flutterTts;
  Timer? analysisTimer;

  bool isProcessing = false;
  bool isContinuousMode = false;
  bool isInitialized = false;
  String lastAnalysis = "";
  double speechRate = 0.45;
  bool isScreenReaderActive = false;
  DateTime? lastTapTime;

  // Analysis Queue
  final Queue<DateTime> analysisQueue = Queue<DateTime>();
  static const int minAnalysisInterval = 3; // seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    // Keep screen on without wakelock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _keepScreenOn(true);
  }

  // Alternative to wakelock - keep screen on
  void _keepScreenOn(bool on) {
    if (on) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) {
        if (!systemOverlaysAreVisible) {
          Future.delayed(const Duration(seconds: 2), () {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          });
        }
        return Future.value();
      });
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _initTTS();
      await _requestPermissions();
      await _initCamera();

      setState(() => isInitialized = true);
      await _speakWelcomeMessage();
    } catch (e) {
      debugPrint('Initialization error: $e');
      _speakError("App initialization failed. Please restart the app.");
    }
  }

  Future<void> _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    flutterTts.setStartHandler(() {
      setState(() => isScreenReaderActive = true);
    });

    flutterTts.setCompletionHandler(() {
      setState(() => isScreenReaderActive = false);
    });

    flutterTts.setErrorHandler((msg) {
      setState(() => isScreenReaderActive = false);
      _vibrate(duration: 500);
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();

    // Verify critical permissions
    if (!(await Permission.camera.isGranted)) {
      throw Exception('Camera permission is required');
    }
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.auto);
      await _cameraController.setFocusMode(FocusMode.auto);
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }

  Future<void> _speakWelcomeMessage() async {
    const welcome = """
      Welcome to Vision Assistant.
      Touch anywhere on the screen to analyze what's in front of you.
      Double tap for continuous analysis.
      Swipe down to hear the last description again.
      Swipe up for settings.
    """;

    await _speak(welcome);
  }

  Future<void> _speak(String message) async {
    if (isScreenReaderActive) {
      await flutterTts.stop();
    }
    await flutterTts.speak(message);
  }

  Future<void> _vibrate({int duration = 100}) async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _speakError(String message) async {
    await _vibrate(duration: 500);
    await _speak("Error: $message");
  }

  Future<void> _analyzeEnvironment({bool isSingleAnalysis = true}) async {
    if (isProcessing) {
      await _speak("Still analyzing. Please wait.");
      return;
    }

    setState(() => isProcessing = true);
    await _vibrate();

    try {
      await _speak("Analyzing environment");

      final XFile image = await _cameraController.takePicture();
      final String description = await _performImageAnalysis(image);

      setState(() {
        lastAnalysis = description;
        isProcessing = false;
      });

      await _speak(description);

      if (!isSingleAnalysis && isContinuousMode) {
        analysisTimer = Timer(
          const Duration(seconds: minAnalysisInterval),
          () => _analyzeEnvironment(isSingleAnalysis: false),
        );
      }
    } catch (e) {
      setState(() => isProcessing = false);
      await _speakError("Analysis failed. Please try again.");
      debugPrint('Analysis error: $e');
    }
  }

  Future<String> _performImageAnalysis(XFile imageFile) async {
    try {
      final File image = File(imageFile.path);
      final List<int> imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('YOUR_API_ENDPOINT'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
        body: jsonEncode({
          'image': base64Image,
          'mode': 'blind_assistance',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['description'] ?? "No description available";
      } else {
        throw Exception('API request failed');
      }
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) => AccessibilitySettings(
        speechRate: speechRate,
        isContinuousMode: isContinuousMode,
        onSpeechRateChanged: (newRate) async {
          setState(() => speechRate = newRate);
          await flutterTts.setSpeechRate(newRate);
          await _speak("Speech rate updated");
        },
        onContinuousModeChanged: (enabled) {
          setState(() => isContinuousMode = enabled);
          if (enabled) {
            _analyzeEnvironment(isSingleAnalysis: false);
          } else {
            analysisTimer?.cancel();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.indigo.shade900, Colors.black],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 6,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Vision Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Initializing services...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _handleTap(),
        onDoubleTap: () => _handleDoubleTap(),
        onVerticalDragEnd: (details) => _handleVerticalDrag(details),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController),

            // Help indicators - fade out after initialization
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // Processing Overlay
            if (isProcessing)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Analyzing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Mode indicator
            Positioned(
              top: 40,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isContinuousMode ? 1.0 : 0.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CONTINUOUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Help indicator
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _speakWelcomeMessage,
              ),
            ),

            // Analysis results panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.indigo.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.remove_red_eye,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              isContinuousMode
                                  ? 'Continuous Analysis Active'
                                  : 'Tap to Analyze',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (lastAnalysis.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                if (lastAnalysis.isNotEmpty) {
                                  _speak(lastAnalysis);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    if (lastAnalysis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                        child: Text(
                          lastAnalysis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Gesture hints
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.2),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _gestureHint(Icons.touch_app, 'Tap'),
                          _gestureHint(Icons.touch_app, 'Double Tap'),
                          _gestureHint(Icons.swipe, 'Swipe Down'),
                          _gestureHint(Icons.settings, 'Swipe Up'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gestureHint(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap() async {
    final now = DateTime.now();
    if (lastTapTime != null &&
        now.difference(lastTapTime!) < const Duration(milliseconds: 300)) {
      return; // Ignore rapid taps
    }
    lastTapTime = now;
    await _analyzeEnvironment();
  }

  void _handleDoubleTap() async {
    setState(() => isContinuousMode = !isContinuousMode);
    if (isContinuousMode) {
      await _speak("Starting continuous analysis");
      _analyzeEnvironment(isSingleAnalysis: false);
    } else {
      analysisTimer?.cancel();
      await _speak("Continuous analysis stopped");
    }
  }

  void _handleVerticalDrag(DragEndDetails details) async {
    if (details.velocity.pixelsPerSecond.dy > 0) {
      // Swipe down - repeat last analysis
      if (lastAnalysis.isNotEmpty) {
        await _speak(lastAnalysis);
      }
    } else {
      // Swipe up - show settings
      _showSettings();
    }
  }

  @override
  void dispose() {
    analysisTimer?.cancel();
    _cameraController.dispose();
    flutterTts.stop();
    _keepScreenOn(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class AccessibilitySettings extends StatelessWidget {
  final double speechRate;
  final bool isContinuousMode;
  final ValueChanged<double> onSpeechRateChanged;
  final ValueChanged<bool> onContinuousModeChanged;

  const AccessibilitySettings({
    Key? key,
    required this.speechRate,
    required this.isContinuousMode,
    required this.onSpeechRateChanged,
    required this.onContinuousModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 60,
            height: 5,
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const Text(
            'Accessibility Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.speed,
                    color: Colors.indigo,
                    size: 28,
                  ),
                  title: const Text(
                    'Speech Rate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.voice_over_off,
                            color: Colors.white54,
                            size: 18,
                          ),
                          Expanded(
                            child: Slider(
                              value: speechRate,
                              min: 0.25,
                              max: 1.0,
                              divisions: 6,
                              activeColor: Colors.indigo,
                              inactiveColor: Colors.grey.shade700,
                              onChanged: onSpeechRateChanged,
                            ),
                          ),
                          const Icon(
                            Icons.record_voice_over,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                          speechRate < 0.4
                              ? 'Slow'
                              : speechRate < 0.7
                                  ? 'Normal'
                                  : 'Fast',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isContinuousMode
                          ? Colors.indigo.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.loop,
                      color: isContinuousMode ? Colors.indigo : Colors.grey,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Continuous Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'Automatically scan environment',
                    style: TextStyle(color: Colors.white54),
                  ),
                  value: isContinuousMode,
                  activeColor: Colors.indigo,
                  onChanged: onContinuousModeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
