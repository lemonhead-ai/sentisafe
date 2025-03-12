import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

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
                'Last updated: $CURRENT_DATETIME UTC\n'
                    'User: $CURRENT_USER',
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