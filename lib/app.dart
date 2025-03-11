import 'package:flutter/material.dart';
import 'screens/home/components/navigate.dart';
import 'screens/home/home.dart';
import 'screens/home/services/check_in.dart';
import 'screens/settings.dart';

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  int _selectedIndex = 0; // Index of the selected tab

  // List of screens to display based on the selected tab
  final List<Widget> _screens = [
    const HomePage(cameras: [],), // Home screen
    const SafetyCheckInScreen(), // Safety Check-In screen
    const Navigation(), // Navigation & Routes screen
    SettingsScreen(), // Settings screen
  ];

  // Function to handle tab selection
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Display the selected screen
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _selectedIndex = 1; // Set Safety Check-In as the active screen
          });
        },
        backgroundColor: _selectedIndex == 1 ? Colors.red : Colors.blue,
        child: const Icon(Icons.timer, size: 30),
        elevation: 10,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Circular notch for the FAB
        notchMargin: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: _selectedIndex == 0 ? Colors.red : Colors.grey,
              ),
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              icon: Icon(
                Icons.directions,
                color: _selectedIndex == 2 ? Colors.red : Colors.grey,
              ),
              onPressed: () => _onItemTapped(2),
            ),
            IconButton(
              icon: Icon(
                Icons.settings,
                color: _selectedIndex == 3 ? Colors.red : Colors.grey,
              ),
              onPressed: () => _onItemTapped(3),
            ),
          ],
        ),
      ),
    );
  }
}
