import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required User user,
    required String username,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'username': username.trim(),
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
