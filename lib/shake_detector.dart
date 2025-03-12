import 'package:SentiSafe/screens/authentication/login.dart';
import 'package:flutter/material.dart';
import 'package:shake_detector/shake_detector.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:provider/provider.dart';


import 'screens/blind_mode/blind_mode_home.dart';
import 'wrapper.dart';

class ShakeDetectorWrapper extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ShakeDetectorWrapper({Key? key, required this.cameras}) : super(key: key);

  @override
  _ShakeDetectorWrapperState createState() => _ShakeDetectorWrapperState();
}

class _ShakeDetectorWrapperState extends State<ShakeDetectorWrapper> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Timer? _listeningTimer;
  bool _speechInitialized = false;
  List<String> _emergencyContacts = [];
  Timer? _shakeResetTimer;
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
    _initSpeechRecognition();

    final userMode = Provider.of<UserModeProvider>(context, listen: false);
    if (userMode.isBlindMode) {
      userMode.speakMessage("Shake detection is active. Shake device for emergency.");
    }
  }

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
    });
    debugPrint('Loaded ${_emergencyContacts.length} emergency contacts');

    final userMode = Provider.of<UserModeProvider>(context, listen: false);
    if (userMode.isBlindMode) {
      if (_emergencyContacts.isEmpty) {
        userMode.speakMessage("No emergency contacts found. Please add contacts in settings.");
      } else {
        userMode.speakMessage("${_emergencyContacts.length} emergency contacts loaded.");
      }
    }
  }

  Future<void> _initSpeechRecognition() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          final userMode = Provider.of<UserModeProvider>(context, listen: false);
          if (userMode.isBlindMode) {
            userMode.speakMessage("Speech recognition error occurred.");
          }
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' && _isListening) {
            _startListening();
          }
        },
      );
    } catch (e) {
      debugPrint('Speech recognition initialization error: $e');
      final userMode = Provider.of<UserModeProvider>(context, listen: false);
      if (userMode.isBlindMode) {
        userMode.speakMessage("Error initializing speech recognition.");
      }
    }
  }

  // ... (previous code remains the same until _startBackgroundListening method)

  void _startBackgroundListening() {
    if (_isListening) return;

    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    String message = 'SOS Mode Activated - Listening for 10 seconds';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );

    if (userMode.isBlindMode) {
      userMode.speakMessage(message);
    }

    setState(() => _isListening = true);

    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 10), () {
      _stopListening();
      String deactivatedMessage = 'SOS Monitoring Deactivated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deactivatedMessage),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 2),
        ),
      );
      if (userMode.isBlindMode) {
        userMode.speakMessage(deactivatedMessage);
      }
    });

    _startListening();
  }

  void _startListening() {
    if (!_speechInitialized || !_isListening) return;

    _speech.listen(
      onResult: (result) {
        final recognizedWords = result.recognizedWords.toLowerCase();
        debugPrint('Recognized: $recognizedWords');

        if (recognizedWords.contains('help') ||
            recognizedWords.contains('danger') ||
            recognizedWords.contains('emergency') ||
            recognizedWords.contains('sos')) {
          _triggerSOS();
        }
      },
      listenFor: const Duration(seconds: 2),
      pauseFor: const Duration(seconds: 1),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    _listeningTimer?.cancel();
  }

  Future<void> _triggerSOS() async {
    _stopListening();
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied');
          if (userMode.isBlindMode) {
            userMode.speakMessage("Location permission denied. Sending SOS without location.");
          }
          _sendSOSWithoutLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied');
        if (userMode.isBlindMode) {
          userMode.speakMessage("Location permanently denied. Sending SOS without location.");
        }
        _sendSOSWithoutLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );
      _sendSOSWithLocation(position);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (userMode.isBlindMode) {
        userMode.speakMessage("Error getting location. Sending SOS without location.");
      }
      _sendSOSWithoutLocation();
    }
  }

  Future<void> _sendSOSWithLocation(Position position) async {
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    if (_emergencyContacts.isEmpty) {
      _showNoContactsAlert();
      return;
    }

    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final String message = 'EMERGENCY! I need help! My location: $googleMapsUrl';

    await _sendSMS(message, _emergencyContacts);
    if (userMode.isBlindMode) {
      userMode.speakMessage("Emergency message sent with location to ${_emergencyContacts.length} contacts.");
    }
  }

  Future<void> _sendSOSWithoutLocation() async {
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    if (_emergencyContacts.isEmpty) {
      _showNoContactsAlert();
      return;
    }

    final String message = 'EMERGENCY! I need help! (Location unavailable)';
    await _sendSMS(message, _emergencyContacts);

    if (userMode.isBlindMode) {
      userMode.speakMessage("Emergency message sent without location to ${_emergencyContacts.length} contacts.");
    }
  }

  void _showNoContactsAlert() {
    final userMode = Provider.of<UserModeProvider>(context, listen: false);
    const message = 'No emergency contacts found. Please add contacts in settings.';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );

    if (userMode.isBlindMode) {
      userMode.speakMessage(message);
    }
  }

  Future<void> _sendSMS(String message, List<String> recipients) async {
    final bool? permissionsGranted = await telephony.requestSmsPermissions;
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    if (permissionsGranted == true) {
      for (String recipient in recipients) {
        await telephony.sendSms(to: recipient, message: message);
      }
      if (userMode.isBlindMode) {
        userMode.speakMessage("Messages sent successfully.");
      }
    } else {
      if (userMode.isBlindMode) {
        userMode.speakMessage("SMS permission denied. Cannot send emergency messages.");
      }
    }
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _shakeResetTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userMode = Provider.of<UserModeProvider>(context);
    return ShakeDetectWrap(
      onShake: _startBackgroundListening,
      child: userMode.isBlindMode
          ? BlindModeHome(cameras: widget.cameras)
          : Wrapper(cameras: widget.cameras),
    );
  }
}