import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme_provider.dart';


class NotificationsProvider extends ChangeNotifier {
  bool _emergencyAlerts = true;
  bool _locationSharing = true;
  bool _safetyTips = true;
  bool _appUpdates = true;

  bool get emergencyAlerts => _emergencyAlerts;
  bool get locationSharing => _locationSharing;
  bool get safetyTips => _safetyTips;
  bool get appUpdates => _appUpdates;

  NotificationsProvider() {
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _emergencyAlerts = prefs.getBool('emergencyAlerts') ?? true;
    _locationSharing = prefs.getBool('locationSharing') ?? true;
    _safetyTips = prefs.getBool('safetyTips') ?? true;
    _appUpdates = prefs.getBool('appUpdates') ?? true;
    notifyListeners();
  }

  Future<void> toggleEmergencyAlerts() async {
    _emergencyAlerts = !_emergencyAlerts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('emergencyAlerts', _emergencyAlerts);
    notifyListeners();
  }

  Future<void> toggleLocationSharing() async {
    _locationSharing = !_locationSharing;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationSharing', _locationSharing);
    notifyListeners();
  }

  Future<void> toggleSafetyTips() async {
    _safetyTips = !_safetyTips;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safetyTips', _safetyTips);
    notifyListeners();
  }

  Future<void> toggleAppUpdates() async {
    _appUpdates = !_appUpdates;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appUpdates', _appUpdates);
    notifyListeners();
  }
}

class PrivacyProvider extends ChangeNotifier {
  bool _shareLocation = true;
  bool _shareContacts = false;
  bool _anonymousReporting = true;
  int _dataRetention = 30; // days

  bool get shareLocation => _shareLocation;
  bool get shareContacts => _shareContacts;
  bool get anonymousReporting => _anonymousReporting;
  int get dataRetention => _dataRetention;

  PrivacyProvider() {
    _loadPrivacyPreferences();
  }

  Future<void> _loadPrivacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _shareLocation = prefs.getBool('shareLocation') ?? true;
    _shareContacts = prefs.getBool('shareContacts') ?? false;
    _anonymousReporting = prefs.getBool('anonymousReporting') ?? true;
    _dataRetention = prefs.getInt('dataRetention') ?? 30;
    notifyListeners();
  }

  Future<void> toggleShareLocation() async {
    _shareLocation = !_shareLocation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shareLocation', _shareLocation);
    notifyListeners();
  }

  Future<void> toggleShareContacts() async {
    _shareContacts = !_shareContacts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shareContacts', _shareContacts);
    notifyListeners();
  }

  Future<void> toggleAnonymousReporting() async {
    _anonymousReporting = !_anonymousReporting;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('anonymousReporting', _anonymousReporting);
    notifyListeners();
  }

  Future<void> setDataRetention(int days) async {
    _dataRetention = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataRetention', _dataRetention);
    notifyListeners();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser = _auth.currentUser;

      if (_currentUser != null) {
        // Fetch user data from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Error loading user data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      _showErrorDialog('Error logging out: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone. All your safety data and emergency contacts will be permanently removed.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(_currentUser!.uid).delete();
      await _firestore.collection('emergency_contacts').doc(_currentUser!.uid).delete();
      await _firestore.collection('safety_records').where('userId', isEqualTo: _currentUser!.uid).get().then((snapshot) {
        for (DocumentSnapshot doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      // Delete user authentication account
      await _currentUser!.delete();

      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      _showErrorDialog('Error deleting account: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final _formKey = GlobalKey<FormState>();
    final _currentPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _obscureCurrentPassword = true;
    bool _obscureNewPassword = true;
    bool _obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureCurrentPassword = !_obscureCurrentPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop();

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      // Reauthenticate user first
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: _currentUser!.email!,
                        password: _currentPasswordController.text,
                      );

                      await _currentUser!.reauthenticateWithCredential(credential);

                      // Change password
                      await _currentUser!.updatePassword(_newPasswordController.text);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      _showErrorDialog('Error changing password: ${e.toString()}');
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: SpinKitDoubleBounce(
          color: Theme.of(context).primaryColor,
          size: 50.0,
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                Colors.grey[900]!,
                Colors.grey[800]!,
              ]
                  : [
                Colors.blue.withOpacity(0.1),
                Colors.purple.withOpacity(0.05),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // User profile card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        child: Text(
                          _userData?['displayName']?.substring(0, 1).toUpperCase() ??
                              _currentUser?.email?.substring(0, 1).toUpperCase() ??
                              '?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userData?['displayName'] ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser?.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_userData?['phoneNumber'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _userData?['phoneNumber'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Settings sections
              Text(
                'Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    // Theme toggle
                    ListTile(
                      leading: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Dark Mode'),
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),

                    // Notifications settings
                    ListTile(
                      leading: Icon(
                        Icons.notifications,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Notifications'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NotificationsSettingsScreen(),
                          ),
                        );
                      },
                    ),

                    // Privacy settings
                    ListTile(
                      leading: Icon(
                        Icons.privacy_tip,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Privacy'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PrivacySettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Account section
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    // Change password
                    ListTile(
                      leading: Icon(
                        Icons.lock,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Change Password'),
                      onTap: _changePassword,
                    ),

                    // Emergency contacts
                    ListTile(
                      leading: Icon(
                        Icons.contact_phone,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Emergency Contacts'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.of(context).pushNamed('/emergency-contacts');
                      },
                    ),

                    // Logout
                    ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Colors.orange,
                      ),
                      title: const Text('Logout'),
                      onTap: _logout,
                    ),

                    // Delete account
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Support section
              Text(
                'Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    // Help center
                    ListTile(
                      leading: Icon(
                        Icons.help,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Safety Resources'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.of(context).pushNamed('/safety-resources');
                      },
                    ),

                    // Report a problem
                    ListTile(
                      leading: Icon(
                        Icons.bug_report,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Report a Problem'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            final reportController = TextEditingController();
                            return AlertDialog(
                              title: const Text('Report a Problem'),
                              content: TextField(
                                controller: reportController,
                                decoration: const InputDecoration(
                                  hintText: 'Describe the issue you encountered',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 5,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Submit report
                                    if (reportController.text.isNotEmpty) {
                                      _firestore.collection('reports').add({
                                        'userId': _currentUser?.uid,
                                        'email': _currentUser?.email,
                                        'report': reportController.text,
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'status': 'pending',
                                      });

                                      Navigator.of(context).pop();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Report submitted successfully'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('SUBMIT'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    // About
                    ListTile(
                      leading: Icon(
                        Icons.info,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('About'),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'SentiSafe',
                          applicationVersion: 'Version 1.0',
                          applicationLegalese: '© 2025 Sentinel Team',
                          children: [
                            const SizedBox(height: 16),
                            const Text(
                              'SentiSafe is a personal safety application developed by the Sentinel Team to help users stay safe and connected during emergencies.',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Features include emergency alerts, location sharing, safety check-ins, and resource connections.',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Notifications Settings Screen
class NotificationsSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notificationsProvider = Provider.of<NotificationsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.purple.withOpacity(0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Emergency Alerts'),
                    subtitle: const Text('Critical safety notifications'),
                    value: notificationsProvider.emergencyAlerts,
                    onChanged: (value) {
                      notificationsProvider.toggleEmergencyAlerts();
                    },
                    secondary: Icon(
                      Icons.warning_amber,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Location Sharing Updates'),
                    subtitle: const Text('When your location is viewed by contacts'),
                    value: notificationsProvider.locationSharing,
                    onChanged: (value) {
                      notificationsProvider.toggleLocationSharing();
                    },
                    secondary: Icon(
                      Icons.location_on,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Safety Tips'),
                    subtitle: const Text('Weekly safety recommendations'),
                    value: notificationsProvider.safetyTips,
                    onChanged: (value) {
                      notificationsProvider.toggleSafetyTips();
                    },
                    secondary: Icon(
                      Icons.tips_and_updates,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('App Updates'),
                    subtitle: const Text('New features and improvements'),
                    value: notificationsProvider.appUpdates,
                    onChanged: (value) {
                      notificationsProvider.toggleAppUpdates();
                    },
                    secondary: Icon(
                      Icons.system_update,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Send a test notification to ensure your device is properly configured.',
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send Test Notification'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Privacy Settings Screen
class PrivacySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.purple.withOpacity(0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text("Enable Two-Factor Authentication"),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text("Allow Profile Visibility"),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text("Enable Activity Status"),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}