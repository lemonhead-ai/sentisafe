import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'safety_plan_model.dart';

class SafetyPlanProvider with ChangeNotifier {
  SafetyPlan? _safetyPlan;
  final SharedPreferences _prefs;

  SafetyPlanProvider(this._prefs) {
    loadSafetyPlan();
  }

  SafetyPlan? get safetyPlan => _safetyPlan;

  Future<void> loadSafetyPlan() async {
    final json = _prefs.getString('safetyPlan');
    if (json != null) {
      _safetyPlan = SafetyPlan.fromJson(jsonDecode(json));
      notifyListeners();
    }
  }

  Future<void> saveSafetyPlan(SafetyPlan plan) async {
    _safetyPlan = plan;
    await _prefs.setString('safetyPlan', jsonEncode(plan.toJson()));
    notifyListeners();
  }
}