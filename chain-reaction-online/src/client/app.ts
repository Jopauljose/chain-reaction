import 'package:firebase_auth/firebase_auth.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

Future<User?> signIn(String email, String password) async {
  UserCredential userCredential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  return userCredential.user;
}