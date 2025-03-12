import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:share_plus/share_plus.dart';

import 'safety_types.dart';

class AccessibilityService {
  Function(String)? onAnalysisResult;
  final FlutterTts flutterTts = FlutterTts();
  bool isScreenReaderActive = false;
  CameraController? _cameraController;
  Timer? _scanTimer;
  bool _isProcessingFrame = false;
  DateTime _lastAnalysisTime = DateTime.now();
  String _lastAnalysisResult = '';

  // Configurable parameters
  final int _minTimeBetweenAnalysis = 3000; // Milliseconds between analyses
  final int _continuousScanInterval = 500; // Milliseconds between frame captures

  /// Initialize TTS with Google's engine
  Future<void> initTTS(double speechRate) async {
    // Set the TTS engine to Google's engine (only works on Android)
    await flutterTts.setEngine("com.google.android.tts");

    // Configure TTS settings
    await flutterTts.setLanguage("en-US"); // Set language to US English
    await flutterTts.setSpeechRate(speechRate); // Set speech rate
    await flutterTts.setVolume(1.0); // Set volume to max
    await flutterTts.setPitch(1.0); // Set pitch to normal

    // Set handlers for TTS events
    flutterTts.setStartHandler(() {
      isScreenReaderActive = true;
    });

    flutterTts.setCompletionHandler(() {
      isScreenReaderActive = false;
    });

    flutterTts.setErrorHandler((msg) {
      isScreenReaderActive = false;
      HapticFeedback.vibrate(); // Vibrate on error
    });
  }

  /// Check if Google TTS is installed and prompt the user to install it if not
  Future<void> checkAndInstallGoogleTTS() async {
    final bool isGoogleTTSInstalled = await flutterTts.isLanguageInstalled("en-US");

    if (!isGoogleTTSInstalled) {
      // Prompt the user to install Google TTS
      // You can use a dialog or any other UI element to inform the user
      // and redirect them to the Play Store to install Google TTS.
      // For example:
      // openStore(url: 'https://play.google.com/store/apps/details?id=com.google.android.tts');
      print("Google TTS is not installed. Please install it from the Play Store.");
    }
  }

  /// Initialize TTS and check for Google TTS installation
  Future<void> setupTTS(double speechRate) async {
    await checkAndInstallGoogleTTS();
    await initTTS(speechRate);
  }

  /// Speak a message using Google TTS
  Future<void> speak(String message) async {
    if (isScreenReaderActive) {
      await flutterTts.stop(); // Stop any ongoing speech
    }
    await flutterTts.speak(message); // Speak the new message
  }

  /// Vibrate the device
  Future<void> vibrate({int duration = 100}) async {
    await HapticFeedback.vibrate();
  }

  /// Speak an error message with vibration
  Future<void> speakError(String message) async {
    await vibrate(duration: 500); // Vibrate for 500ms
    await speak("Error: $message"); // Speak the error message
  }

  /// Initialize continuous scanning with the camera
  Future<void> initContinuousScanning() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
  }

  /// Start continuous scanning
  Future<void> startContinuousScanning(bool safetyFocused) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await initContinuousScanning();
    }

    if (_scanTimer != null) {
      _scanTimer!.cancel();
    }

    // Start the continuous scanning timer
    _scanTimer = Timer.periodic(Duration(milliseconds: _continuousScanInterval), (timer) async {
      if (!_isProcessingFrame &&
          DateTime.now().difference(_lastAnalysisTime).inMilliseconds > _minTimeBetweenAnalysis) {
        await _processCurrentFrame(safetyFocused);
      }
    });
  }

  /// Stop continuous scanning
  Future<void> stopContinuousScanning() async {
    if (_scanTimer != null) {
      _scanTimer!.cancel();
      _scanTimer = null;
    }

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  /// Process the current camera frame
  Future<void> _processCurrentFrame(bool safetyFocused) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessingFrame = true;

    try {
      // Capture image from camera stream
      final XFile image = await _cameraController!.takePicture();

      // Analyze the image
      String analysisResult = await performImageAnalysis(image, safetyFocused);

      // Only speak if analysis result has changed significantly
      if (_shouldSpeakNewResult(analysisResult)) {
        await speak(analysisResult);
        _lastAnalysisResult = analysisResult;
      }

      _lastAnalysisTime = DateTime.now();

      // Delete temporary image file
      await File(image.path).delete();
    } catch (e) {
      // Silent error handling for continuous mode
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Determine if the new result is different enough to speak
  bool _shouldSpeakNewResult(String newResult) {
    if (_lastAnalysisResult.isEmpty) return true;

    // Simple difference threshold - can be improved with more sophisticated comparison
    return _calculateSimilarity(_lastAnalysisResult, newResult) < 0.7;
  }

  /// Calculate similarity between two strings
  double _calculateSimilarity(String a, String b) {
    final Set<String> wordsA = a.toLowerCase().split(' ').toSet();
    final Set<String> wordsB = b.toLowerCase().split(' ').toSet();

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    return union == 0 ? 0 : intersection / union;
  }

  /// Perform image analysis using Google Generative AI
  Future<String> performImageAnalysis(XFile imageFile, bool safetyFocused) async {
    try {
      final File image = File(imageFile.path);
      final imageBytes = await image.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      String promptText = safetyFocused
          ? "Briefly describe only essential safety hazards with precise locations. "
          "Focus only on immediate dangers using directional terms (left, right, ahead). "
          "If no hazards exist, provide minimal guidance for navigation."
          : "Provide a brief description focusing only on essential elements for navigation. "
          "Use concise directional terms for orientation. "
          "Mention only key obstacles or pathways needed for safe movement.";

      final promptPart = TextPart(promptText);
      final response = await SafetyConstants.generativeModel.generateContent([
        Content.multi([imagePart, promptPart])
      ]);

      return response.text ?? 'No description available';
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  /// Get the current location
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );
    } catch (e) {
      return null;
    }
  }

  /// Send an emergency alert
  Future<void> sendEmergencyAlert(String message) async {
    try {
      await Share.share(message, subject: "Emergency Alert");
      await speak("Emergency alert sent with your location.");
    } catch (e) {
      await speak("Failed to send emergency alert. Please try again or call emergency services directly.");
    }
  }
}