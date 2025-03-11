// home/components/sos_button.dart
import 'package:flutter/material.dart';
import 'dart:async';

class SOSButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const SOSButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isWaveAnimating = false;
  List<double> _waveRadii = [];
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveTimer?.cancel();
    super.dispose();
  }

  void _startWaveAnimation() {
    if (_isWaveAnimating) return;

    setState(() {
      _isWaveAnimating = true;
      _waveRadii = [0];
    });

    // Generate new waves every 300ms
    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_waveRadii.length < 5) {
        setState(() {
          _waveRadii.add(0);
        });
      }

      // Stop after 3 seconds
      if (timer.tick >= 10) {
        timer.cancel();
        setState(() {
          _isWaveAnimating = false;
          _waveRadii = [];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Wave animations
        if (_isWaveAnimating)
          ..._waveRadii.map((radius) => _buildWaveRing(radius)).toList(),

        // Main SOS button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: GestureDetector(
                onTap: () {
                  _startWaveAnimation();
                  _handleSOSPress(context);
                },
                child: Container(
                  width: 200,
                  height: 200,
                  child: Stack(
                    children: [
                      // 3D Effect Shadow (bottom layer)
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.shade900,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 15,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),

                      // Main Button (middle layer)
                      Positioned(
                        top: 5,
                        left: 5,
                        right: 5,
                        bottom: 15,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.red.shade500,
                                Colors.red.shade800,
                              ],
                              focal: Alignment(0.1, 0.1),
                              focalRadius: 0.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top highlight (edge effect)
                      Positioned(
                        top: 10,
                        left: 25,
                        right: 25,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.elliptical(100, 40),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.4),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Content
                      Center(
                        child: widget.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to Activate',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWaveRing(double initialRadius) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 150),
      duration: const Duration(seconds: 3),
      builder: (context, double radius, _) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withOpacity(1 - (radius / 150)),
              width: 4,
            ),
          ),
        );
      },
    );
  }

  void _handleSOSPress(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Send SOS Alert'),
          ],
        ),
        content: const Text(
          'This will send an emergency alert to all your emergency contacts. '
              'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade800],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPressed();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Send SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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