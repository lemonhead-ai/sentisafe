import 'package:SentiSafe/shake_detector.dart';
import 'package:SentiSafe/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'app.dart';
import 'models/the_user.dart';
import 'screens/chat.dart';
import 'screens/home/home.dart';
import 'screens/settings.dart';
import 'screens/blind_mode/blind_mode_home.dart';
import 'services/auth.dart';
import 'wrapper.dart';
import 'theme_provider.dart';
// Make sure to import the file containing UserModeProvider and Routes

// Constants for current date/time and user
const String CURRENT_DATETIME = '2025-03-11 16:59:33';
const String CURRENT_USER = 'lemonhead-ai';

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