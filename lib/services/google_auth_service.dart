import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class GoogleAuthService {
  // للعمل على الويب، يجب إضافة Web Client ID الخاص بك من منصة Google Cloud
  static const String _webClientId = 'YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com';
  static const String _iosClientId = '656705978860-q3d81gb5ib3uavj2bg9mctfv5fps8qmv.apps.googleusercontent.com';

  static Future<User?> signIn() async {
    final googleSignIn = GoogleSignIn(
      clientId: kIsWeb 
          ? _webClientId 
          : (Platform.isIOS ? _iosClientId : null),
    );

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    final user = userCredential.user;
    if (user == null) return null;

    await _saveUser(user);
    await _updateLastActive(user.uid);

    return user;
  }

  static Future<void> _saveUser(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'profileImage': user.photoURL ?? '',
      'authProvider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _updateLastActive(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
