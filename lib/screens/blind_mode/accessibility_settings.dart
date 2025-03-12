import 'package:flutter/material.dart';

class AccessibilitySettings extends StatelessWidget {
  final double speechRate;
  final bool isContinuousMode;
  final String emergencyContact;
  final ValueChanged<double> onSpeechRateChanged;
  final ValueChanged<bool> onContinuousModeChanged;
  final ValueChanged<String> onEmergencyContactChanged;

  const AccessibilitySettings({
    Key? key,
    required this.speechRate,
    required this.isContinuousMode,
    required this.emergencyContact,
    required this.onSpeechRateChanged,
    required this.onContinuousModeChanged,
    required this.onEmergencyContactChanged,
  }) : super(key: key);

  String _getSpeechRateLabel(double rate) {
    if (rate < 0.4) return 'Slow';
    if (rate < 0.7) return 'Normal';
    return 'Fast';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 60,
            height: 5,
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(5),
            ),
          ),

          // Title
          const Text(
            'Safety & Accessibility Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),

          // Main Settings Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Speech Rate Setting
                ListTile(
                  leading: const Icon(
                    Icons.speed,
                    color: Colors.indigo,
                    size: 28,
                  ),
                  title: const Text(
                    'Speech Rate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.voice_over_off,
                            color: Colors.white54,
                            size: 18,
                          ),
                          Expanded(
                            child: Slider(
                              value: speechRate,
                              min: 0.25,
                              max: 1.0,
                              divisions: 6,
                              activeColor: Colors.indigo,
                              inactiveColor: Colors.grey.shade700,
                              onChanged: onSpeechRateChanged,
                            ),
                          ),
                          const Icon(
                            Icons.record_voice_over,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                          _getSpeechRateLabel(speechRate),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),

                // Continuous Mode Setting
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isContinuousMode
                          ? Colors.indigo.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.loop,
                      color: isContinuousMode ? Colors.indigo : Colors.grey,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Continuous Safety Monitoring',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'Automatically scan for hazards',
                    style: TextStyle(color: Colors.white54),
                  ),
                  value: isContinuousMode,
                  activeColor: Colors.indigo,
                  onChanged: onContinuousModeChanged,
                ),
                const Divider(color: Colors.grey),

                // Emergency Contact Setting
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emergency_share,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Emergency Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    emergencyContact.isNotEmpty
                        ? emergencyContact
                        : 'No emergency contact set',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.white54),
                  onTap: () => _showEmergencyContactDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Emergency Features Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.emergency,
                      color: Colors.red,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Emergency Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEmergencyFeatureItem(
                    '• Triple tap the screen to activate emergency mode'
                ),
                const SizedBox(height: 8),
                _buildEmergencyFeatureItem(
                    '• In emergency mode, swipe right to send an alert with your location'
                ),
                const SizedBox(height: 8),
                _buildEmergencyFeatureItem(
                    '• Your emergency contact will receive your location details'
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Close Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyFeatureItem(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
      ),
    );
  }

  void _showEmergencyContactDialog(BuildContext context) {
    final TextEditingController contactController =
    TextEditingController(text: emergencyContact);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Set Emergency Contact',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contactController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Phone number or email',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.indigo),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.indigo, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This contact will receive emergency alerts with your location',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              onEmergencyContactChanged(contactController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}