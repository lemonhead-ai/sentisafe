// usermodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final DateTime soberDate;
  final int streakDays;
  final List<DateTime> relapses;
  final Map<String, dynamic> goals;
  final List<String> supportNetwork;
  final List<String> emergencyContacts;

  UserModel({
    required this.uid,
    DateTime? soberDate,  // Make soberDate optional with default value
    this.streakDays = 0,  // Provide default value for streakDays
    this.relapses = const [],
    this.goals = const {},
    this.supportNetwork = const [],
    this.emergencyContacts = const [],
  }) : this.soberDate = soberDate ?? DateTime.now();  // Set default value if not provided

  // Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      soberDate: data['soberDate'] != null
          ? (data['soberDate'] as Timestamp).toDate()
          : DateTime.now(),
      streakDays: data['streakDays'] ?? 0,
      relapses: (data['relapses'] as List<dynamic>?)?.map((x) =>
          (x as Timestamp).toDate()).toList() ?? [],
      goals: Map<String, dynamic>.from(data['goals'] ?? {}),
      supportNetwork: List<String>.from(data['supportNetwork'] ?? []),
      emergencyContacts: List<String>.from(data['emergencyContacts'] ?? []),
    );
  }

  // Method to convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'soberDate': Timestamp.fromDate(soberDate),
      'streakDays': streakDays,
      'relapses': relapses.map((date) => Timestamp.fromDate(date)).toList(),
      'goals': goals,
      'supportNetwork': supportNetwork,
      'emergencyContacts': emergencyContacts,
    };
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? uid,
    DateTime? soberDate,
    int? streakDays,
    List<DateTime>? relapses,
    Map<String, dynamic>? goals,
    List<String>? supportNetwork,
    List<String>? emergencyContacts,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      soberDate: soberDate ?? this.soberDate,
      streakDays: streakDays ?? this.streakDays,
      relapses: relapses ?? this.relapses,
      goals: goals ?? this.goals,
      supportNetwork: supportNetwork ?? this.supportNetwork,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }
}