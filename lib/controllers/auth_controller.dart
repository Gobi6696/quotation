import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/drive_helper.dart';

class AuthController with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.appdata'],
  );
  GoogleSignIn get googleSignIn => _googleSignIn;

  User? _user;
  Map<String, dynamic>? _localUserData;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get localUserData => _localUserData;
  bool get isLoading => _isLoading;

  AuthController() {
    _checkLocalAuth();
  }

  Future<void> _checkLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      _localUserData = json.decode(userDataString);
      notifyListeners();
    }

    // Also sync with Firebase state
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _saveUserLocally(user);
      }
      notifyListeners();
    });
  }

  Future<void> loginWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      _user = userCredential.user;

      if (_user != null) {
        await _saveUserLocally(_user!);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      _user = userCredential.user;

      if (_user != null) {
        await _saveUserLocally(_user!);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _saveUserLocally(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
    };
    await prefs.setString('user_data', json.encode(userData));
    return userData;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _user = null;
    notifyListeners();
  }
}
