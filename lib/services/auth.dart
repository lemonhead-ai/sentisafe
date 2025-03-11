import 'package:firebase_auth/firebase_auth.dart';

import '../models/the_user.dart';
import 'database.dart';


class AuthService {
  // Create instance of our FirebaseAuth, providing us with methods from the FirebaseAuth class
  // final means wont change in the future
  // underscore means private, only can use in this file
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // create TheUser object based on Firebase user
  TheUser? _userFromFirebaseUser(User? user) {
    // return uid from user object if user is not null
    return user != null ? TheUser(uid: user.uid) : null;
  }

  // auth change user stream
  Stream<TheUser?> get user {
    return _auth.authStateChanges()
    // .map((User? user) => _userFromFirebaseUser(user));
    .map(_userFromFirebaseUser);  // simplified method
  }

  // method to login anonymously (asynchronous task)
  Future signInAnon() async {
    try {
      // await means will wait till this is complete
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      return _userFromFirebaseUser(user!);
    } catch(e) {
      print(e.toString());
      return null;
    }
  }

  // method to login with email and password
  Future signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      return _userFromFirebaseUser(user);
    }
    catch(e) {
      print(e.toString());
      return null;
    }
  }

  // method to register with email and password
  Future registerWithEmailAndPassword(String displayName, String email, String password, String type) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password).then((user){
        user.user!.updateDisplayName(displayName);
        return user;
      });
      User? user = result.user;

      // create a new document for the user with the uid
      await DatabaseService(uid: user!.uid).updateUserData(displayName, user.email, type);
      print('print #2:');
      print(user);
      return _userFromFirebaseUser(user);
    }
    catch(e) {
      print(e.toString());
      return null;
    }
  }

  // method to logout
  // future for async tasks which takes some time to complete
  Future signOut() async {
    try {
      return await _auth.signOut();
    }
    catch(e) {
      print(e.toString());
      return null;
    }
  }

}