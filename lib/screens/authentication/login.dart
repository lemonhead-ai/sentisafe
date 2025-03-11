// login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui';
import '../../main.dart';
import 'shared_components.dart';

// UserModeProvider for managing blind mode state
class UserModeProvider extends ChangeNotifier {
  bool _isBlindMode = false;
  bool get isBlindMode => _isBlindMode;
  FlutterTts flutterTts = FlutterTts();

  UserModeProvider() {
    _loadUserMode();
    _initTTS();
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
    notifyListeners();
  }

  Future<void> toggleBlindMode(bool value) async {
    _isBlindMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blind_mode', value);
    if (value) {
      await flutterTts.speak("Blind mode enabled");
    } else {
      await flutterTts.speak("Blind mode disabled");
    }
    notifyListeners();
  }

  Future<void> speakMessage(String message) async {
    if (_isBlindMode) {
      await flutterTts.speak(message);
    }
  }
}

class Login extends StatefulWidget {
  final Function toggleView;
  const Login({Key? key, required this.toggleView}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  String _email = '';
  String _password = '';
  String _error = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
    _emailFocusNode.addListener(() {
      _updateBlur(_emailFocusNode.hasFocus);
    });

    _passwordFocusNode.addListener(() {
      _updateBlur(_passwordFocusNode.hasFocus);
    });

    // Announce initial screen for blind users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userMode = Provider.of<UserModeProvider>(context, listen: false);
      if (userMode.isBlindMode) {
        userMode.speakMessage(
            "Login screen. Please enter your email and password.");
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      if (userMode.isBlindMode) {
        await userMode.speakMessage("Logging in, please wait");
      }

      try {
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password,
        );

        if (result.user != null) {
          if (userMode.isBlindMode) {
            await userMode.speakMessage("Login successful");
            Navigator.pushReplacementNamed(context, Routes.blindHome);
          } else {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _error = e.message ?? 'Failed to login. Please check your credentials.';
          _loading = false;
        });
        if (userMode.isBlindMode) {
          await userMode.speakMessage("Login failed. ${_error}");
        }
      }
    }
  }

  double _blurValue = 1.0;

  void _updateBlur(bool hasFocus) {
    setState(() {});
  }

  Widget _buildAccessibilitySwitch() {
    return Consumer<UserModeProvider>(
      builder: (context, userMode, child) {
        return GlassmorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Enable Blind Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: userMode.isBlindMode ? 20 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: userMode.isBlindMode,
                onChanged: (bool value) {
                  userMode.toggleBlindMode(value);
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final userMode = Provider.of<UserModeProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.9),
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.15),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blurValue, sigmaY: _blurValue),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 50),
                        Center(
                          child: GlassmorphicContainer(
                            padding: const EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/img.png',
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAccessibilitySwitch(),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome Back',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: userMode.isBlindMode ? 36 : 30,
                            color: Colors.white,
                            letterSpacing: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: userMode.isBlindMode ? 24 : 18,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        GlassmorphicContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextFormField(
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: userMode.isBlindMode ? 20 : 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: userMode.isBlindMode ? 20 : 16,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.white,
                                size: userMode.isBlindMode ? 28 : 24,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: userMode.isBlindMode ? 20.0 : 16.0,
                                horizontal: 16.0,
                              ),
                              hintText: 'Enter your email address',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val?.isEmpty ?? true)
                                return 'Please enter your email';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(val!)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            onChanged: (val) => setState(() => _email = val),
                            focusNode: _emailFocusNode,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GlassmorphicContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextFormField(
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: userMode.isBlindMode ? 20 : 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: userMode.isBlindMode ? 20 : 16,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: userMode.isBlindMode ? 28 : 24,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: userMode.isBlindMode ? 28 : 24,
                                ),
                                onPressed: () {
                                  setState(() =>
                                  _obscurePassword = !_obscurePassword);
                                  if (userMode.isBlindMode) {
                                    userMode.speakMessage(_obscurePassword
                                        ? "Password hidden"
                                        : "Password visible");
                                  }
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: userMode.isBlindMode ? 20.0 : 16.0,
                                horizontal: 16.0,
                              ),
                              hintText: 'Enter your password',
                            ),
                            obscureText: _obscurePassword,
                            validator: (val) => val?.isEmpty ?? true
                                ? 'Please enter your password'
                                : null,
                            onChanged: (val) => setState(() => _password = val),
                            focusNode: _passwordFocusNode,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: TextButton(
                              onPressed: () {
                                if (userMode.isBlindMode) {
                                  userMode.speakMessage(
                                      "Forgot password option selected");
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: userMode.isBlindMode ? 8 : 1,
                                  horizontal: userMode.isBlindMode ? 16 : 10,
                                ),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: userMode.isBlindMode ? 16 : 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16, top: 16),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.25),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.7),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _error,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: userMode.isBlindMode ? 18 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          height: userMode.isBlindMode ? 65 : 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.5),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                                spreadRadius: 1,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () {
                              if (userMode.isBlindMode) {
                                userMode.speakMessage("Logging in");
                              }
                              _login();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: userMode.isBlindMode ? 16 : 12,
                              ),
                            ),
                            child: _loading
                                ? SizedBox(
                              height: userMode.isBlindMode ? 28 : 24,
                              width: userMode.isBlindMode ? 28 : 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                                : Text(
                              'LOGIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: userMode.isBlindMode ? 22 : 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: userMode.isBlindMode ? 10 : 5,
                            horizontal: userMode.isBlindMode ? 20 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w400,
                                  fontSize: userMode.isBlindMode ? 18 : 14,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4.0,
                                      color: Colors.blueGrey.withOpacity(0.5),
                                      offset: const Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (userMode.isBlindMode) {
                                      userMode.speakMessage(
                                          "Going to registration screen");
                                    }
                                    widget.toggleView();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: userMode.isBlindMode ? 4 : 1,
                                      horizontal:
                                      userMode.isBlindMode ? 16 : 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: userMode.isBlindMode ? 18 : 14,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userMode.isBlindMode)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: GlassmorphicContainer(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Accessibility Instructions:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '• Double tap to activate buttons\n'
                                        '• Swipe left/right to navigate fields\n'
                                        '• Voice feedback is enabled\n'
                                        '• Larger text and buttons available',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'Last updated: 2025-03-11 15:40:40 UTC\n'
                              'User: lemonhead-ai',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}