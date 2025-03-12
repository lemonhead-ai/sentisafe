import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'accessibility_service.dart';
import 'accessibility_settings.dart';
import 'safety_helpers.dart';
import 'safety_types.dart';
import 'safety_ui_components.dart';

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
  late AccessibilityService _accessibilityService;
  late SafetyState _safetyState;

  Timer? safetyCheckTimer;
  Position? currentPosition;
  String? emergencyContact = "";

  bool isProcessing = false;
  bool isContinuousMode = false;
  bool isInitialized = false;
  double speechRate = 0.45;

  // For tracking analysis redundancy
  final Queue<String> _lastResults = Queue<String>();
  final int _maxStoredResults = 3;
  DateTime _lastAnalysisTime = DateTime.now();
  final int _minAnalysisInterval = 3000; // milliseconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _safetyState = SafetyState();
    _accessibilityService = AccessibilityService();
    _initializeServices();
    SafetyHelpers.keepScreenOn(true);
  }

  Future<void> _initializeServices() async {
    try {
      await _accessibilityService.initTTS(speechRate);

      if (!await SafetyHelpers.requestPermissions()) {
        throw Exception('Required permissions not granted');
      }

      await _initCamera();
      await _updateLocation();

      if (!await SafetyHelpers.checkLocationService()) {
        await _accessibilityService.speak(
            "Location services are disabled. Some safety features may not work."
        );
      }

      setState(() => isInitialized = true);
      await _speakWelcomeMessage();
      _startSafetyChecks();
    } catch (e) {
      debugPrint('Initialization error: $e');
      await _accessibilityService.speakError("App initialization failed. Please restart the app.");
    }
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController.initialize();
      await _cameraController.setFlashMode(FlashMode.auto);
      await _cameraController.setFocusMode(FocusMode.auto);
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }

  Future<void> _updateLocation() async {
    currentPosition = await _accessibilityService.getCurrentLocation();
  }

  void _startSafetyChecks() {
    safetyCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _updateLocation();
      if (!isContinuousMode && !isProcessing) {
        await _analyzeEnvironment(safetyFocused: true);
      }
    });
  }

  Future<void> _speakWelcomeMessage() async {
    const welcome = """
      Welcome to your Personal Safety Assistant.
      Touch anywhere on the screen to analyze your surroundings.
      Double tap for continuous safety monitoring.
      Swipe down to hear the last analysis again.
      Swipe up for settings.
      Triple tap to activate emergency mode.
    """;
    await _accessibilityService.speak(welcome);
  }

  Future<void> _startContinuousScanningMode(bool safetyFocused) async {
    if (!_cameraController.value.isInitialized) {
      await _initCamera();
    }

    await _accessibilityService.initContinuousScanning();
    await _accessibilityService.startContinuousScanning(safetyFocused);

    // Set up result handler to process analysis results
    _accessibilityService.onAnalysisResult = (String result) async {
      if (_shouldProcessResult(result)) {
        setState(() {
          _safetyState.lastAnalysis = result;
          _lastAnalysisTime = DateTime.now();
        });

        if (safetyFocused || SafetyHelpers.containsSafetyKeywords(result)) {
          setState(() => _safetyState.hazardDetected = true);
          await _handleSafetyAlert(result);
        } else {
          setState(() => _safetyState.hazardDetected = false);
          await _accessibilityService.speak(result);
        }
      }
    };
  }

  void _stopContinuousScanningMode() async {
    await _accessibilityService.stopContinuousScanning();
  }

  bool _shouldProcessResult(String newResult) {
    // Skip if too recent from last analysis
    if (DateTime.now().difference(_lastAnalysisTime).inMilliseconds < _minAnalysisInterval) {
      return false;
    }

    // Check for similar previous results
    for (final prevResult in _lastResults) {
      if (_calculateSimilarity(prevResult, newResult) > 0.7) {
        return false;
      }
    }

    // Store new result
    _lastResults.add(newResult);
    if (_lastResults.length > _maxStoredResults) {
      _lastResults.removeFirst();
    }

    return true;
  }

  double _calculateSimilarity(String a, String b) {
    // Simple Jaccard similarity implementation
    final Set<String> wordsA = a.toLowerCase().split(' ').toSet();
    final Set<String> wordsB = b.toLowerCase().split(' ').toSet();

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    return union == 0 ? 0 : intersection / union;
  }

  Future<void> _analyzeEnvironment({
    bool isSingleAnalysis = true,
    bool safetyFocused = false
  }) async {
    if (isProcessing) {
      await _accessibilityService.speak("Still analyzing. Please wait.");
      return;
    }

    setState(() => isProcessing = true);
    await _accessibilityService.vibrate();

    try {
      safetyFocused
          ? await _accessibilityService.speak("Scanning for potential hazards")
          : await _accessibilityService.speak("Analyzing surroundings");

      final XFile image = await _cameraController.takePicture();
      final String description =
      await _accessibilityService.performImageAnalysis(image, safetyFocused);

      setState(() {
        _safetyState.lastAnalysis = description;
        isProcessing = false;
      });

      if (safetyFocused || SafetyHelpers.containsSafetyKeywords(description)) {
        setState(() => _safetyState.hazardDetected = true);
        await _handleSafetyAlert(description);
      } else {
        setState(() => _safetyState.hazardDetected = false);
        await _accessibilityService.speak(description);
      }
    } catch (e) {
      setState(() => isProcessing = false);
      await _accessibilityService.speakError("Analysis failed. Please try again.");
      debugPrint('Analysis error: $e');
    }
  }

  Future<void> _handleSafetyAlert(String description) async {
    _safetyState.safetyAlertCount++;

    String alertMessage = "SAFETY ALERT: $description";
    await _accessibilityService.speak(alertMessage);

    if (_safetyState.safetyAlertCount > SafetyConstants.maxSafetyAlerts) {
      await _accessibilityService.speak(
          "Multiple safety concerns detected. Would you like to activate emergency mode? Triple tap to confirm."
      );
      _safetyState.safetyAlertCount = 0;
    }
  }

  Future<void> _activateEmergencyMode() async {
    if (_safetyState.sosMode) {
      await _accessibilityService.speak("Emergency mode already active.");
      return;
    }

    setState(() => _safetyState.sosMode = true);
    await _accessibilityService.speak(
        "Emergency mode activated. Current location being monitored. Swipe right to send emergency alert with your location."
    );
  }

  Future<void> _sendEmergencyAlert() async {
    await _updateLocation();
    String message = SafetyHelpers.constructEmergencyMessage(currentPosition);

    if (emergencyContact!.isNotEmpty) {
      await _accessibilityService.sendEmergencyAlert(message);
    } else {
      await Share.share(message, subject: "Emergency Alert");
      await _accessibilityService.speak(
          "No emergency contact set. Please share this message with someone who can help."
      );
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
        emergencyContact: emergencyContact ?? "",
        onSpeechRateChanged: (newRate) async {
          setState(() => speechRate = newRate);
          await _accessibilityService.initTTS(newRate);
          await _accessibilityService.speak("Speech rate updated");
        },
        onContinuousModeChanged: (enabled) {
          setState(() => isContinuousMode = enabled);
          if (enabled) {
            _startContinuousScanningMode(true);
          } else {
            _stopContinuousScanningMode();
          }
        },
        onEmergencyContactChanged: (contact) {
          setState(() => emergencyContact = contact);
          _accessibilityService.speak("Emergency contact updated");
        },
      ),
    );
  }

  void _handleTap() async {
    final now = DateTime.now();
    if (_safetyState.lastTapTime != null) {
      final difference = now.difference(_safetyState.lastTapTime!);
      if (difference < SafetyConstants.doubleTapThreshold) {
        return; // Ignore rapid taps
      }

      if (difference < SafetyConstants.emergencyTapWindow) {
        _safetyState.safetyAlertCount++;
        if (_safetyState.safetyAlertCount >= SafetyConstants.maxSafetyAlerts) {
          _safetyState.safetyAlertCount = 0;
          await _activateEmergencyMode();
          return;
        }
      } else {
        _safetyState.safetyAlertCount = 1;
      }
    } else {
      _safetyState.safetyAlertCount = 1;
    }

    _safetyState.lastTapTime = now;
    await _analyzeEnvironment();
  }

  void _handleDoubleTap() async {
    setState(() => isContinuousMode = !isContinuousMode);
    if (isContinuousMode) {
      await _accessibilityService.speak("Starting continuous safety monitoring");
      _startContinuousScanningMode(true);
    } else {
      _stopContinuousScanningMode();
      await _accessibilityService.speak("Continuous monitoring stopped");
    }
  }

  void _handleVerticalDrag(DragEndDetails details) async {
    if (details.velocity.pixelsPerSecond.dy > 0) {
      if (_safetyState.lastAnalysis.isNotEmpty) {
        await _accessibilityService.speak(_safetyState.lastAnalysis);
      } else {
        await _accessibilityService.speak(
            "No analysis available yet. Tap to analyze your surroundings."
        );
      }
    } else {
      _showSettings();
    }
  }

  void _handleHorizontalDrag(DragEndDetails details) async {
    if (_safetyState.sosMode && details.velocity.pixelsPerSecond.dx > 0) {
      await _sendEmergencyAlert();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return SafetyUIComponents.buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _handleTap(),
        onDoubleTap: () => _handleDoubleTap(),
        onVerticalDragEnd: (details) => _handleVerticalDrag(details),
        onHorizontalDragEnd: (details) => _handleHorizontalDrag(details),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController),

            // Overlay gradients
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

            // SOS Mode Indicator
            if (_safetyState.sosMode)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red.withOpacity(0.7),
                    width: 12.0,
                  ),
                ),
              ),

            SafetyUIComponents.buildAnalysisOverlay(
              isProcessing: isProcessing,
              hazardDetected: _safetyState.hazardDetected,
              isContinuousMode: isContinuousMode,
              lastAnalysis: _safetyState.lastAnalysis,
              onRefresh: () {
                if (_safetyState.lastAnalysis.isNotEmpty) {
                  _accessibilityService.speak(_safetyState.lastAnalysis);
                }
              },
            ),

            // Mode indicators and help button
            Positioned(
              top: 40,
              right: 20,
              child: Column(
                children: [
                  if (isContinuousMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8
                      ),
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
                            'CONTINUOUS SAFETY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (isContinuousMode) {
      _stopContinuousScanningMode();
    }
    safetyCheckTimer?.cancel();
    _cameraController.dispose();
    SafetyHelpers.keepScreenOn(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}