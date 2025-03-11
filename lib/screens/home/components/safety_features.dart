import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../widgets/fake_call.dart';
import 'ai_assistant.dart';
import 'navigate.dart';
import 'voice_recorder.dart';

class SafetyFeatures extends StatelessWidget {
  final List<CameraDescription> cameras; // Add cameras as a parameter
  final bool isBlindMode; // Add isBlindMode as a parameter

  const SafetyFeatures({
    super.key,
    required this.cameras,
    required this.isBlindMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.call,
                  title: 'Fake Call',
                  screen: const FakeCallScreen(),
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.chat,
                  title: 'AI Companion',
                  screen: AICompanionScreen(),
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.navigation,
                  title: 'Navigate',
                  screen: const Navigation(),
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.record_voice_over,
                  title: 'Voice Record',
                  screen: const VoiceRecordScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget screen,
      }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade50,
              Colors.red.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}