import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {

  final String? uid;
  DatabaseService({ this.uid });
  
  // collection reference:
  final CollectionReference userCollection = FirebaseFirestore.instance.collection('users');

  Future updateUserData(String? displayName, String? email, String type) async {
    return await userCollection.doc(uid).set({
      'displayName': displayName,
      'email': email,
      'type': type,   // P-Patient or T-Therapist
      'sober_days': null,
      'last_checked_in': null,
    });
  }

  // get users stream
  Stream<QuerySnapshot> get users {
    return userCollection.snapshots();
  }

}