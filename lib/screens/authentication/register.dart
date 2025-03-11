// register.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'dart:ui';
import '../../main.dart';


class Register extends StatefulWidget {
  final Function toggleView;
  const Register({Key? key, required this.toggleView}) : super(key: key);

  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  String _nickname = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _error = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _nicknameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

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

    // Announce screen for blind users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userMode = Provider.of<UserModeProvider>(context, listen: false);
      if (userMode.isBlindMode) {
        userMode.speakMessage("Registration screen. Please fill in your details to create an account.");
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _nicknameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final userMode = Provider.of<UserModeProvider>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      if (userMode.isBlindMode) {
        await userMode.speakMessage("Creating your account, please wait");
      }

      try {
        final UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: _email.trim(),
          password: _password,
        );

        if (result.user != null) {
          await _firestore.collection('users').doc(result.user!.uid).set({
            'nickname': _nickname,
            'email': _email.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'isBlindModeEnabled': userMode.isBlindMode,
            'lastLogin': DateTime.now().toUtc().toString(),
          });

          if (userMode.isBlindMode) {
            await userMode.speakMessage("Account created successfully");
            Navigator.pushReplacementNamed(context, Routes.blindHome);
          } else {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _error = e.message ?? 'An error occurred during registration';
          _loading = false;
        });
        if (userMode.isBlindMode) {
          await userMode.speakMessage("Registration failed. ${_error}");
        }
      }
    }
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required void Function(String) onChanged,
    bool isPassword = false,
    bool isConfirmPassword = false,
    required FocusNode focusNode,
    TextInputType? keyboardType,
  }) {
    final userMode = Provider.of<UserModeProvider>(context);
    bool obscureText = isPassword ? _obscurePassword : (isConfirmPassword ? _obscureConfirmPassword : false);

    return GlassmorphicContainer(
      margin: EdgeInsets.symmetric(vertical: 8),
      borderRadius: 12,
      blur: 10,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.2),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: userMode.isBlindMode ? 8 : 4,
      ),
      child: TextFormField(
        style: TextStyle(
          color: Colors.white,
          fontSize: userMode.isBlindMode ? 20 : 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white70,
            fontSize: userMode.isBlindMode ? 20 : 16,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white70,
            size: userMode.isBlindMode ? 28 : 24,
          ),
          suffixIcon: (isPassword || isConfirmPassword)
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
              size: userMode.isBlindMode ? 28 : 24,
            ),
            onPressed: () {
              setState(() {
                if (isPassword) {
                  _obscurePassword = !_obscurePassword;
                } else {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                }
              });
              if (userMode.isBlindMode) {
                userMode.speakMessage(
                    obscureText ? "Password hidden" : "Password visible");
              }
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white30),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        focusNode: focusNode,
        keyboardType: keyboardType,
        onTap: () {
          if (userMode.isBlindMode) {
            userMode.speakMessage("$label field selected");
          }
        },
      ),
    );
  }

  Widget _buildModeToggle() {
    final userMode = Provider.of<UserModeProvider>(context);

    return GlassmorphicContainer(
      margin: EdgeInsets.symmetric(vertical: 16),
      borderRadius: 12,
      blur: 10,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.2),
        ],
      ),
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
  }

  @override
  Widget build(BuildContext context) {
    final userMode = Provider.of<UserModeProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
          children: [
          // Background with wave
          ClipPath(
          clipper: WaveClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.9),
              Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ],
          ),
        ),
        height: size.height * 0.7,
      ),
    ),

    // Content
    SafeArea(
    child: SingleChildScrollView(
    child: Padding(
    padding: const EdgeInsets.all(24.0),
    child: FadeTransition(
    opacity: _fadeAnimation,
    child: Form(
    key: _formKey,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    SizedBox(height: size.height * 0.05),

    // App Logo
    Center(
    child: GlassmorphicContainer(
    padding: const EdgeInsets.all(20),
    borderRadius: 20,
    blur: 20,
    border: 2,
    linearGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
    Colors.white.withOpacity(0.2),
    Colors.white.withOpacity(0.1),
    ],
    ),
    borderGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
    Colors.white.withOpacity(0.4),
    Colors.white.withOpacity(0.2),
    ],
    ),
    child: Image.asset(
    'assets/img.png',
    height: userMode.isBlindMode ? 80 : 60,
    fit: BoxFit.contain,
    ),
    ),
    ),
    SizedBox(height: 20),

    // Title
    Text(
    'Create Account',
    style: TextStyle(
    fontSize: userMode.isBlindMode ? 32 : 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1.2,
    ),
    textAlign: TextAlign.center,
    ),

    // Mode Toggle
    _buildModeToggle(),

    SizedBox(height: 30),

    // Form Fields
    _buildFormField(
    label: 'Nickname',
    icon: Icons.person_outline,
    validator: (val) => val?.isEmpty ?? true
    ? 'Please enter a nickname'
        : null,
    onChanged: (val) => setState(() => _nickname = val),
    focusNode: _nicknameFocus,
    ),

    _buildFormField(
    label: 'Email',
    icon: Icons.email_outlined,
    validator: (val) {
    if (val?.isEmpty ?? true) return 'Please enter an email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(val!)) {
    return 'Please enter a valid email';
    }
    return null;
    },
    onChanged: (val) => setState(() => _email = val),
    focusNode: _emailFocus,
    keyboardType: TextInputType.emailAddress,
    ),

    _buildFormField(
    label: 'Password',
    icon: Icons.lock_outline,
    validator: (val) => (val?.length ?? 0) < 6
    ? 'Password must be at least 6 characters'
        : null,
    onChanged: (val) => setState(() => _password = val),
    isPassword: true,
    focusNode: _passwordFocus,
    ),

    _buildFormField(
    label: 'Confirm Password',
    icon: Icons.lock_outline,
    validator: (val) =>
    val != _password ? 'Passwords do not match' : null,
    onChanged: (val) =>
    setState(() => _confirmPassword = val),
    isConfirmPassword: true,
    focusNode: _confirmPasswordFocus,
    ),

    // Error Text
    if (_error.isNotEmpty)
    Container(
    margin: EdgeInsets.symmetric(vertical: 16),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.red.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
    color: Colors.red.withOpacity(0.5),
    ),
    ),
    child: Text(
    _error,
    style: TextStyle(
    color: Colors.red,
    fontSize: userMode.isBlindMode ? 18 : 14,
    ),
    textAlign: TextAlign.center,
    ),
    ),

    SizedBox(height: 24),

    // Register Button
    ElevatedButton(
    onPressed: _loading ? null : _register,
    style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).primaryColor,
    padding: EdgeInsets.symmetric(
    vertical: userMode.isBlindMode ? 20 : 16,
    ),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    child: _loading
    ? SizedBox(
    height: userMode.isBlindMode ? 28 : 24,
    width: userMode.isBlindMode ? 28 : 24,
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
    )
        : Text(
      'REGISTER',
      style: TextStyle(
        fontSize: userMode.isBlindMode ? 20 : 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
    ),

      SizedBox(height: 20),

      // Login Link
      TextButton(
        onPressed: () {
          if (userMode.isBlindMode) {
            userMode.speakMessage("Going to login screen");
          }
          widget.toggleView();
        },
        child: Text(
          'Already have an account? Sign In',
          style: TextStyle(
            color: Colors.white,
            fontSize: userMode.isBlindMode ? 18 : 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),

      // Accessibility Instructions
      if (userMode.isBlindMode)
        Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: GlassmorphicContainer(
            borderRadius: 12,
            blur: 10,
            border: 2,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0.2),
              ],
            ),
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
                  '• Voice guidance is enabled\n'
                      '• All fields are required\n'
                      '• Double tap to interact\n'
                      '• Swipe to navigate between fields',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
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

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final double border;
  final Gradient linearGradient;
  final Gradient borderGradient;

  const GlassmorphicContainer({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 12,
    this.blur = 10,
    this.border = 2,
    required this.linearGradient,
    required this.borderGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: linearGradient,
        border: Border.all(
          width: border,
          color: Colors.white.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: blur,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: border,
                color: Colors.transparent,
              ),
              gradient: borderGradient,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.75);

    var firstControlPoint = Offset(size.width * 0.25, size.height * 0.85);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.75);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height * 0.65);
    var secondEndPoint = Offset(size.width, size.height * 0.75);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
