// authenticate.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import 'login.dart';
import 'register.dart';

class Authenticate extends StatefulWidget {
  const Authenticate({Key? key}) : super(key: key);

  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> with SingleTickerProviderStateMixin {
  bool showSignIn = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  // Add these constants
  static const String currentDateTime = '2025-03-11 15:42:55';
  static const String currentUser = 'lemonhead-ai';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleView() {
    setState(() {
      showSignIn = !showSignIn;
      if (showSignIn) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: showSignIn
                ? Login(toggleView: toggleView, key: const ValueKey('login'))
                : Register(toggleView: toggleView, key: const ValueKey('register')),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
          // Add timestamp and user info at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Text(
              'Last updated: $currentDateTime UTC\n'
                  'User: $currentUser',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}