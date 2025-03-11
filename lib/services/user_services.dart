// user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';


class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get current user data
  Future<UserModel> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      // Create new user data if it doesn't exist
      final newUser = UserModel(
        uid: user.uid,
        soberDate: DateTime.now(),
        streakDays: 0,
      );
      await _db.collection('users').doc(user.uid).set(newUser.toFirestore());
      return newUser;
    }

    return UserModel.fromFirestore(doc);
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? email,
    String? photoURL,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final updates = <String, dynamic>{};

    if (displayName != null) updates['displayName'] = displayName;
    if (email != null) updates['email'] = email;
    if (photoURL != null) updates['photoURL'] = photoURL;

    await userRef.update(updates);
  }

  // Record relapse and reset streak
  Future<void> recordRelapse(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'soberDate': Timestamp.now(),
      'streakDays': 0,
      'relapses': FieldValue.arrayUnion([Timestamp.now()]),
    });
  }

  // Update streak days
  Future<void> updateStreakDays(String uid, int streakDays) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'streakDays': streakDays,
    });
  }

  // Add support contact
  Future<void> addSupportContact(String uid, String contactInfo) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'supportNetwork': FieldValue.arrayUnion([contactInfo]),
    });
  }

  // Remove support contact
  Future<void> removeSupportContact(String uid, String contactInfo) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'supportNetwork': FieldValue.arrayRemove([contactInfo]),
    });
  }

  // Add emergency contact
  Future<void> addEmergencyContact(String uid, String contactInfo) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'emergencyContacts': FieldValue.arrayUnion([contactInfo]),
    });
  }

  // Remove emergency contact
  Future<void> removeEmergencyContact(String uid, String contactInfo) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'emergencyContacts': FieldValue.arrayRemove([contactInfo]),
    });
  }

  // Set or update goal
  Future<void> setGoal(String uid, String goalId, Map<String, dynamic> goalData) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'goals.$goalId': goalData,
    });
  }

  // Remove goal
  Future<void> removeGoal(String uid, String goalId) async {
    final userRef = _db.collection('users').doc(uid);

    await userRef.update({
      'goals.$goalId': FieldValue.delete(),
    });
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    final querySnapshot = await _db.collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return UserModel.fromFirestore(querySnapshot.docs.first);
  }

  // Calculate current streak
  Future<void> calculateAndUpdateStreak(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = UserModel.fromFirestore(userDoc);

    final now = DateTime.now();
    final soberDate = userData.soberDate;
    final difference = now.difference(soberDate).inDays;

    if (difference != userData.streakDays) {
      await updateStreakDays(uid, difference);
    }
  }

  // Stream user data for real-time updates
  Stream<UserModel> streamUserData(String uid) {
    return _db.collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => UserModel.fromFirestore(doc));
  }
}