import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'components/sos_button.dart';
import 'components/contacts_section.dart';
import 'components/safety_features.dart';
import 'services/location_service.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({
    super.key,
    required this.cameras,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final List<String> _contacts;
  bool _isSending = false;
  final LocationService _locationService = LocationService();
  final Telephony telephony = Telephony.instance;
  bool _hasPermissions = false;
  bool _isBlindMode = false;
  String _nickname = "Friend"; // Default nickname

  // Sidebar state management
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _contacts = []; // Initialize the list
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _loadContacts();
    await _loadUserNickname();
    await _locationService.checkPermissions();
  }

  Future<void> _loadUserNickname() async {
    try {
      // First try to get from shared preferences for quicker loading
      final prefs = await SharedPreferences.getInstance();
      String? savedNickname = prefs.getString('user_nickname');

      if (savedNickname != null && savedNickname.isNotEmpty) {
        if (mounted) {
          setState(() {
            _nickname = savedNickname;
          });
        }
        print('Loaded nickname from SharedPreferences: $_nickname');
      } else {
        // Try to fetch from Firebase if not in SharedPreferences
        await _fetchNicknameFromFirebase();
      }
    } catch (e) {
      print('Error loading nickname from SharedPreferences: $e');
    }
  }

  Future<void> _fetchNicknameFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists && userData.data()?['nickname'] != null) {
          final nickname = userData.data()?['nickname'] as String;

          // Save to SharedPreferences for future quick access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_nickname', nickname);

          if (mounted) {
            setState(() {
              _nickname = nickname;
            });
          }
          print('Fetched and saved nickname from Firebase: $_nickname');
        }
      }
    } catch (e) {
      print('Error fetching nickname from Firebase: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final bool? permissionsGranted =
      await telephony.requestPhoneAndSmsPermissions;
      print('SMS permissions granted: $permissionsGranted');

      if (mounted) {
        setState(() {
          _hasPermissions = permissionsGranted ?? false;
        });
      }
    } catch (e) {
      print('Error checking permissions: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to check SMS permissions');
      }
    }
  }

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('emergency_contacts') ?? [];
      print('Loaded contacts: $savedContacts');
      print('Contact list length: ${savedContacts.length}');

      if (mounted) {
        setState(() {
          _contacts.clear();
          _contacts.addAll(savedContacts);
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load emergency contacts');
      }
    }
  }

  Future<void> _sendSOS() async {
    if (!_hasPermissions) {
      _showErrorSnackBar('SMS permissions not granted');
      await _checkPermissions();
      return;
    }

    // Create a local copy of contacts to prevent race conditions
    final contactsList = List<String>.from(_contacts);

    if (contactsList.isEmpty) {
      _showErrorSnackBar('Please add emergency contacts first');
      return;
    }

    if (mounted) {
      setState(() => _isSending = true);
    }

    try {
      print('Attempting to send SOS to contacts: $contactsList');

      Position? position;
      try {
        position = await _locationService.getCurrentLocation();
        print(
            'Location obtained: ${position?.latitude}, ${position?.longitude}');
      } catch (e) {
        print('Location error: $e');
        // Continue without location if it fails
      }

      String message = 'EMERGENCY SOS!\n\nI need immediate assistance!';
      if (position != null) {
        message += '\n\nMy current location:\n'
            'https://www.google.com/maps/search/?api=1&query='
            '${position.latitude},${position.longitude}';
      }

      List<String> failedContacts = [];
      for (String contact in contactsList) {
        try {
          print('Sending SMS to: $contact');

          // Validate phone number format
          String sanitizedContact = contact.replaceAll(RegExp(r'[^\d+]'), '');
          if (sanitizedContact.isEmpty) {
            throw Exception('Invalid phone number format');
          }

          await telephony.sendSms(
            to: sanitizedContact,
            message: message,
          );

          print('SMS sent successfully to: $contact');
        } catch (e) {
          print('Failed to send SMS to $contact: $e');
          failedContacts.add(contact);
        }
      }

      if (mounted) {
        if (failedContacts.isEmpty) {
          _showSuccessSnackBar('SOS sent successfully to all contacts');
        } else if (failedContacts.length == contactsList.length) {
          throw Exception('Failed to send SMS to any contact');
        } else {
          _showWarningSnackBar(
              'SOS sent partially. Failed for: ${failedContacts.join(", ")}');
        }
      }
    } catch (e) {
      print('SOS error: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to send SOS message: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSafetyTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety Tips'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('• Stay aware of your surroundings'),
              SizedBox(height: 8),
              Text('• Keep your emergency contacts updated'),
              SizedBox(height: 8),
              Text('• Share your location with trusted contacts'),
              SizedBox(height: 8),
              Text('• Keep your phone charged'),
              SizedBox(height: 8),
              Text('• Know your emergency exits'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('SMS Permissions'),
                subtitle: Text(_hasPermissions ? 'Granted' : 'Not Granted'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkPermissions,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location Settings'),
                onTap: () async {
                  await _locationService.checkPermissions();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Change Nickname'),
                subtitle: Text(_nickname),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeNicknameDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_red_eye),
                title: const Text('Blind Mode'),
                subtitle: Text(_isBlindMode ? 'Enabled' : 'Disabled'),
                trailing: Switch(
                  value: _isBlindMode,
                  onChanged: (value) {
                    setState(() {
                      _isBlindMode = value;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangeNicknameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: _nickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Your Nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            hintText: 'Enter your preferred nickname',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                // Save to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_nickname', newNickname);

                // Also save to Firebase if user is logged in
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'nickname': newNickname});
                  }
                } catch (e) {
                  print('Error updating nickname in Firebase: $e');
                }

                if (mounted) {
                  setState(() {
                    _nickname = newNickname;
                  });
                  Navigator.pop(context);
                  _showSuccessSnackBar('Nickname updated successfully!');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Function to change the selected index
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Close the drawer after selection on mobile
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.pop(context);
    }
  }

  // Function to get the current widget based on selected index
  Widget _getCurrentWidget() {
    switch (_selectedIndex) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Personalized greeting with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Hello, $_nickname!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We hope you're safe. If you need help, press the SOS button below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Safety status card
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safety Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _contacts.isEmpty
                              ? 'Please add emergency contacts'
                              : 'You have ${_contacts.length} emergency contact${_contacts.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // SOS Button positioned at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                width: double.infinity,
                child: SOSButton(
                  onPressed: _sendSOS,
                  isLoading: _isSending,
                ),
              ),
            ),
          ],
        );
      case 1:
        return ContactsSection(
          contacts: _contacts,
          onContactsChanged: _loadContacts,
        );
      case 2:
        return SafetyFeatures(
          cameras: widget.cameras,
          isBlindMode: _isBlindMode,
        );
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // Custom app bar with menu button - removed settings icon
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield, size: 24),
            const SizedBox(width: 8),
            const Text('Personal Safety'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState!.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Safety Tips',
            onPressed: () => _showSafetyTips(context),
          ),
        ],
      ),
      // Drawer for navigation
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.red.shade800,
                      Colors.red.shade600,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hi, $_nickname',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Stay Safe with Us',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: const Text('Emergency SOS'),
                selected: _selectedIndex == 0,
                selectedTileColor: Colors.red.shade50,
                onTap: () => _onItemTapped(0),
              ),
              ListTile(
                leading: const Icon(Icons.contacts, color: Colors.blue),
                title: const Text('Emergency Contacts'),
                selected: _selectedIndex == 1,
                selectedTileColor: Colors.red.shade50,
                onTap: () => _onItemTapped(1),
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: const Text('Safety Features'),
                selected: _selectedIndex == 2,
                selectedTileColor: Colors.red.shade50,
                onTap: () => _onItemTapped(2),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettings(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('About Safety App'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield,
                            color: Colors.red,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'This app is designed to help you in emergency situations by quickly connecting you with your emergency contacts.',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Version 1.2.0',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // Main content area showing the selected widget
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _getCurrentWidget(),
        ),
      ),
      // Removed floating action button as requested since we're using the SOSButton component
    );
  }
}