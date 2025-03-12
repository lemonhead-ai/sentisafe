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

import 'theme_provider.dart';

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

    // OPTION 1: Define a complete TextTheme with ALL non-null font sizes
    final baseTextTheme = ThemeData.light().textTheme.copyWith(
      displayLarge: const TextStyle(fontSize: 96),
      displayMedium: const TextStyle(fontSize: 60),
      displaySmall: const TextStyle(fontSize: 48),
      headlineLarge: const TextStyle(fontSize: 40),
      headlineMedium: const TextStyle(fontSize: 34),
      headlineSmall: const TextStyle(fontSize: 24),
      titleLarge: const TextStyle(fontSize: 20),
      titleMedium: const TextStyle(fontSize: 16),
      titleSmall: const TextStyle(fontSize: 14),
      bodyLarge: const TextStyle(fontSize: 16),
      bodyMedium: const TextStyle(fontSize: 14),
      bodySmall: const TextStyle(fontSize: 12),
      labelLarge: const TextStyle(fontSize: 14),
      labelMedium: const TextStyle(fontSize: 12),
      labelSmall: const TextStyle(fontSize: 10),
    );

    // OPTION 2: Create separate themes for regular and blind mode
    final regularTextTheme = baseTextTheme;
    final blindTextTheme = TextTheme(
      displayLarge: baseTextTheme.displayLarge?.copyWith(fontSize: 125),
      displayMedium: baseTextTheme.displayMedium?.copyWith(fontSize: 78),
      displaySmall: baseTextTheme.displaySmall?.copyWith(fontSize: 62),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontSize: 52),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontSize: 44),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 31),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: 26),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 21),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontSize: 18),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 21),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 18),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 16),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: 18),
      labelMedium: baseTextTheme.labelMedium?.copyWith(fontSize: 16),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontSize: 13),
    );

    return MaterialApp(
      title: 'Safety App',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        colorScheme: const ColorScheme.light(
          secondary: Colors.blueAccent,
        ),
        // Use Option 2: Separate themes approach (safer and more explicit)
        textTheme: userMode.isBlindMode ? blindTextTheme : regularTextTheme,
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
        colorScheme: const ColorScheme.dark(
          secondary: Colors.blueAccent,
        ),
        // Use Option 2: Separate themes approach (safer and more explicit)
        textTheme: userMode.isBlindMode ? blindTextTheme : regularTextTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(userMode.isBlindMode ? 20.0 : 16.0),
            textStyle: TextStyle(
              fontSize: userMode.isBlindMode ? 20.0 : 16.0,
            ),
          ),
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