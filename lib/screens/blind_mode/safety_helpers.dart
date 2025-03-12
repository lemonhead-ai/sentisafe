import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class SafetyHelpers {
  // Safety keywords for hazard detection
  static final List<String> _safetyKeywords = [
    // Movement hazards
    "trip", "fall", "slip", "stumble", "uneven",

    // Surface conditions
    "wet", "slippery", "ice", "puddle", "steep",

    // Obstacles
    "obstacle", "barrier", "block", "pole", "post",
    "wall", "fence", "gate", "door", "step",

    // Height-related
    "stairs", "steps", "drop", "edge", "ledge",
    "height", "elevation", "platform", "gap",

    // Traffic-related
    "traffic", "vehicle", "car", "truck", "bus",
    "bicycle", "bike", "motorcycle", "crossing",

    // Construction
    "construction", "work", "scaffold", "equipment",
    "machinery", "tools", "debris",

    // Warning terms
    "caution", "warning", "danger", "hazard", "unsafe",
    "careful", "attention", "alert", "emergency",

    // Movement descriptors
    "approaching", "moving", "coming", "rapidly",
    "quickly", "fast", "incoming",

    // Physical hazards
    "sharp", "pointed", "broken", "damaged", "hole",
    "crack", "bump", "rough",

    // Environmental
    "dark", "dim", "shadow", "blind spot", "corner",
    "intersection", "weather", "wind", "rain",

    // Immediate action terms
    "stop", "wait", "watch out", "move away",
    "stand back", "hold on", "grab",
  ];

  // Priority levels for different types of hazards
  static const Map<String, int> _hazardPriority = {
    "traffic": 5,
    "vehicle": 5,
    "edge": 4,
    "drop": 4,
    "stairs": 4,
    "construction": 3,
    "obstacle": 3,
    "wet": 2,
    "uneven": 2,
  };

  /// Checks if text contains safety-related keywords and returns true if hazards are detected
  static bool containsSafetyKeywords(String text) {
    text = text.toLowerCase();
    return _safetyKeywords.any((word) => text.contains(word));
  }

  /// Gets the priority level of detected hazards
  static int getHazardPriority(String text) {
    text = text.toLowerCase();
    int highestPriority = 0;

    for (var entry in _hazardPriority.entries) {
      if (text.contains(entry.key) && entry.value > highestPriority) {
        highestPriority = entry.value;
      }
    }

    return highestPriority;
  }

  /// Formats current timestamp for logging
  static String getTimestamp() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  }

  /// Keeps the screen on when needed
  static Future<void> keepScreenOn(bool on) async {
    if (on) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) {
        if (!systemOverlaysAreVisible) {
          Future.delayed(const Duration(seconds: 2), () {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          });
        }
        return Future.value();
      });
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Requests all necessary permissions for the app
  static Future<bool> requestPermissions() async {
    try {
      final permissions = await [
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.locationWhenInUse,
        Permission.locationAlways,
        Permission.storage,
      ].request();

      // Check if all critical permissions are granted
      bool criticalPermissionsGranted = permissions[Permission.camera]!.isGranted &&
          permissions[Permission.location]!.isGranted;

      // Log permission status
      _logPermissionStatus(permissions);

      return criticalPermissionsGranted;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  /// Logs permission status for debugging
  static void _logPermissionStatus(Map<Permission, PermissionStatus> permissions) {
    final timestamp = getTimestamp();
    debugPrint('[$timestamp] Permission Status:');
    permissions.forEach((permission, status) {
      debugPrint('[$timestamp] ${permission.toString()}: ${status.toString()}');
    });
  }

  /// Checks if location services are enabled
  static Future<bool> checkLocationService() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Location service check error: $e');
      return false;
    }
  }

  /// Constructs emergency message with location
  static String constructEmergencyMessage(Position? position) {
    final timestamp = getTimestamp();

    if (position == null) {
      return "EMERGENCY ALERT [$timestamp]: I need immediate assistance! "
          "Location services unavailable.";
    }

    String locationUrl =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';

    return "EMERGENCY ALERT [$timestamp]: I need immediate assistance!\n"
        "Location: $locationUrl\n"
        "Accuracy: ${position.accuracy.toStringAsFixed(2)} meters\n"
        "Speed: ${position.speed.toStringAsFixed(2)} m/s\n"
        "Heading: ${position.heading.toStringAsFixed(2)}°";
  }

  /// Validates emergency contact information
  static bool isValidEmergencyContact(String contact) {
    // Phone number regex (international format)
    final phoneRegex = RegExp(r'^\+?[\d\s-]{8,}$');

    // Email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );

    return phoneRegex.hasMatch(contact) || emailRegex.hasMatch(contact);
  }

  /// Formats emergency contact for display
  static String formatEmergencyContact(String contact) {
    if (contact.isEmpty) return "";

    // If it's an email, return as is
    if (contact.contains('@')) return contact;

    // Format phone number
    return contact.replaceAllMapped(
        RegExp(r'(\d{3})(\d{3})(\d{4})'),
            (Match m) => "(${m[1]}) ${m[2]}-${m[3]}"
    );
  }

  /// Checks if the current time is during low-light hours
  static bool isLowLightCondition() {
    final now = DateTime.now();
    final hour = now.hour;

    // Consider low light conditions between 6 PM and 6 AM
    return hour < 6 || hour >= 18;
  }

  /// Determines if immediate alert is needed based on hazard type
  static bool needsImmediateAlert(String description, int hazardPriority) {
    // Check for immediate danger keywords
    final immediateKeywords = [
      "immediately",
      "urgent",
      "emergency",
      "danger",
      "coming",
      "approaching",
    ];

    description = description.toLowerCase();
    bool containsImmediate = immediateKeywords.any(
            (word) => description.contains(word)
    );

    // Alert immediately if high priority or contains immediate danger keywords
    return hazardPriority >= 4 || containsImmediate;
  }

  /// Debugs information about system and app state
  static void debugSystemState() {
    final timestamp = getTimestamp();
    debugPrint('[$timestamp] System State:');
    debugPrint('[$timestamp] Platform: ${Platform.operatingSystem}');
    debugPrint('[$timestamp] SDK: ${Platform.version}');
    debugPrint('[$timestamp] Locale: ${Platform.localeName}');
    debugPrint('[$timestamp] Low Light: ${isLowLightCondition()}');
  }
}

// Extension method for debug printing with timestamps
extension SafetyDebugPrint on String {
  void debugLogWithTimestamp() {
    final timestamp = SafetyHelpers.getTimestamp();
    debugPrint('[$timestamp] $this');
  }
}