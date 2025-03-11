// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shake_detector/shake_detector.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

import 'app.dart';
import 'models/the_user.dart';
import 'screens/chat.dart';
import 'screens/home/home.dart';
import 'screens/settings.dart';
import 'screens/blind_mode/blind_mode_home.dart';
import 'services/auth.dart';
import 'wrapper.dart';
import 'theme_provider.dart';

// Constants for current date/time and user
const String CURRENT_DATETIME = '2025-03-11 15:58:41';
const String CURRENT_USER = 'lemonhead-ai';

class Routes {
  static const String app = '/app';
  static const String wrapper = '/wrapper';
  static const String home = '/home';
  static const String blindHome = '/blind-home';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String modeSelection = '/mode-selection';
}

class UserModeProvider extends ChangeNotifier {
  bool _isBlindMode = false;
  bool get isBlindMode => _isBlindMode;
  FlutterTts flutterTts = FlutterTts();

  UserModeProvider() {
    _initTTS();
    _loadUserMode();
  }

  Future<void> _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _loadUserMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isBlindMode = prefs.getBool('blind_mode') ?? false;
    if (_isBlindMode) {
      await speakMessage("Blind mode is active");
    }
    notifyListeners();
  }

  Future<void> toggleBlindMode(bool value) async {
    _isBlindMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blind_mode', value);
    await speakMessage(value ? "Blind mode activated" : "Standard mode activated");
    notifyListeners();
  }

  Future<void> speakMessage(String message) async {
    if (_isBlindMode) {
      await flutterTts.speak(message);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('CameraError: ${e.description}');
  }

  try {
    await Firebase.initializeApp();
    final fcm = FirebaseMessaging.instance;

    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
    String? token = await fcm.getToken();
    debugPrint('FCM Token: $token');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    runApp(
      MultiProvider(
        providers: [
          StreamProvider<TheUser?>.value(
            value: AuthService().user,
            initialData: null,
            catchError: (_, __) => null,
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserModeProvider()),
        ],
        child: MyApp(cameras: cameras),
      ),
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    runApp(
      MultiProvider(
        providers: [
          StreamProvider<TheUser?>.value(
            value: AuthService().user,
            initialData: null,
            catchError: (_, __) => null,
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserModeProvider()),
        ],
        child: MyApp(cameras: cameras),
      ),
    );
  }
}
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userMode = Provider.of<UserModeProvider>(context);

    return MaterialApp(
      title: 'Safety App',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.light(
          secondary: Colors.blueAccent,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontSizeFactor: userMode.isBlindMode ? 1.3 : 1.0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(userMode.isBlindMode ? 20.0 : 16.0),
            textStyle: TextStyle(
              fontSize: userMode.isBlindMode ? 20.0 : 16.0,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey,
        colorScheme: ColorScheme.dark(
          secondary: Colors.blueAccent,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontSizeFactor: userMode.isBlindMode ? 1.3 : 1.0,
        ),
      ),
      themeMode: themeProvider.currentTheme,
      initialRoute: Routes.modeSelection,
      routes: {
        Routes.modeSelection: (context) => UserModeSelectionScreen(),
        Routes.app: (context) => const App(),
        Routes.wrapper: (context) => ShakeDetectorWrapper(cameras: cameras),
        Routes.home: (context) => HomePage(cameras: cameras),
        Routes.blindHome: (context) => BlindModeHome(cameras: cameras),
        Routes.chat: (context) => Chat(),
        Routes.settings: (context) => SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class UserModeSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userMode = Provider.of<UserModeProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to Safety App',
                    style: TextStyle(
                      fontSize: userMode.isBlindMode ? 32 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: size.height * 0.05),
                  Text(
                    'Please select your preferred mode:',
                    style: TextStyle(
                      fontSize: userMode.isBlindMode ? 24 : 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: size.height * 0.08),
                  _buildModeCard(
                    context: context,
                    title: 'Standard Mode',
                    description: 'Regular app interface with standard features',
                    icon: Icons.visibility,
                    isSelected: !userMode.isBlindMode,
                    onTap: () async {
                      await userMode.toggleBlindMode(false);
                      Navigator.pushReplacementNamed(context, Routes.home);
                    },
                  ),
                  SizedBox(height: size.height * 0.03),
                  _buildModeCard(
                    context: context,
                    title: 'Blind Mode',
                    description: 'Enhanced accessibility with voice guidance',
                    icon: Icons.accessibility_new,
                    isSelected: userMode.isBlindMode,
                    onTap: () async {
                      await userMode.toggleBlindMode(true);
                      Navigator.pushReplacementNamed(context, Routes.blindHome);
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Text(
                'Last updated: 2025-03-11 15:59:26 UTC\n'
                    'User: lemonhead-ai',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final userMode = Provider.of<UserModeProvider>(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: userMode.isBlindMode ? 48 : 40,
              color: isSelected ? Colors.white : Colors.grey[800],
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: userMode.isBlindMode ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: userMode.isBlindMode ? 18 : 16,
                color: isSelected ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          : const Wrapper(),
    );
  }
}