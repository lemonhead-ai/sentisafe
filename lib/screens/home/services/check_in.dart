import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyCheckInScreen extends StatefulWidget {
  const SafetyCheckInScreen({Key? key}) : super(key: key);

  @override
  _SafetyCheckInScreenState createState() => _SafetyCheckInScreenState();
}

class _SafetyCheckInScreenState extends State<SafetyCheckInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  DateTime? _selectedTime;
  bool _isTimerActive = false;
  int _remainingTime = 0; // Remaining time in seconds
  int _totalDuration = 0; // Total duration of the timer
  late AnimationController _animationController;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  Timer? _countdownTimer;
  int _notificationId = 0; // Unique ID for notifications

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeNotifications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'safety_check_in_channel',
      'Safety Check-In',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      _notificationId++, // Use unique ID for each notification
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Ensure the selected time is in the future
      if (selectedDateTime.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected time must be in the future.')),
        );
        return;
      }

      setState(() {
        _selectedTime = selectedDateTime;
      });
    }
  }

  Future<List<String>> _getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('emergency_contacts') ?? [];
  }

  Future<void> _sendEmergencyAlerts() async {
    // Check and request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    // Get current location
    final Position position = await Geolocator.getCurrentPosition();
    final String location =
        'Lat: ${position.latitude}, Long: ${position.longitude}';

    // Send emergency alerts to contacts
    final contacts = await _getEmergencyContacts();
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts found.')),
      );
      return;
    }

    for (final contact in contacts) {
      print('Sending emergency alert to: $contact with location: $location');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency alerts sent to contacts.')),
    );
  }

  void _startCheckInTimer() {
    if (_selectedTime == null || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination and select a time.')),
      );
      return;
    }

    final now = DateTime.now();
    final difference = _selectedTime!.difference(now).inSeconds;

    if (difference <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected time must be in the future.')),
      );
      return;
    }

    setState(() {
      _isTimerActive = true;
      _remainingTime = difference;
      _totalDuration = difference;
    });

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime--;
      });

      // Send notifications at 10 minutes, 5 minutes, and 1 minute remaining
      if (_remainingTime <= 600 && _remainingTime > 599) {
        _showNotification('Safety Check-In', '10 minutes remaining!');
      } else if (_remainingTime <= 300 && _remainingTime > 299) {
        _showNotification('Safety Check-In', '5 minutes remaining!');
      } else if (_remainingTime <= 60 && _remainingTime > 59) {
        _showNotification('Safety Check-In', '1 minute remaining!');
      }

      if (_remainingTime <= 0) {
        timer.cancel();
        _sendEmergencyAlerts();
      }
    });
  }

  void _cancelCheckIn() {
    _countdownTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _remainingTime = 0;
    });
    _notificationsPlugin.cancelAll(); // Cancel all pending notifications
  }

  void _manualCheckIn() {
    _cancelCheckIn();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have checked in safely!')),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Check-In'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: 'Where are you going?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a destination';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _selectTime(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'By what time will you be back?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time),
                      ),
                      child: Text(
                        _selectedTime != null
                            ? _formatTime(_selectedTime!)
                            : 'Select Time',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isTimerActive)
                    Column(
                      children: [
                        CircularProgressIndicator(
                          value: _remainingTime > 0 ? _remainingTime / _totalDuration : 0,
                          strokeWidth: 8,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Time remaining: $_remainingTime seconds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _manualCheckIn,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                          child: const Text('Check In Safely'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cancelCheckIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                          child: const Text('Cancel Check-In'),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _startCheckInTimer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      child: const Text('Start Check-In'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}