import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';

class SafetyConstants {
  static const int minAnalysisInterval = 3;
  static const int maxSafetyAlerts = 3;
  static const Duration doubleTapThreshold = Duration(milliseconds: 300);
  static const Duration emergencyTapWindow = Duration(seconds: 2);

  static final GenerativeModel generativeModel = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyCOutG-g_tVZKzbTtH0bzNjWdoaDVA2YCo',
    generationConfig: GenerationConfig(
      temperature: 1.0,
      topK: 64,
      topP: 0.95,
      maxOutputTokens: 8192,
    ),
    safetySettings: [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ],
  );
}

class SafetyState {
  bool hazardDetected;
  bool sosMode;
  int safetyAlertCount;
  String lastAnalysis;
  DateTime? lastTapTime;

  SafetyState({
    this.hazardDetected = false,
    this.sosMode = false,
    this.safetyAlertCount = 0,
    this.lastAnalysis = "",
    this.lastTapTime,
  });
}