import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthController with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.appdata'],
  );
  GoogleSignIn get googleSignIn => _googleSignIn;

  User? _user;
  Map<String, dynamic>? _localUserData;
  String? _role;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get localUserData => _localUserData;
  String? get role => _role;
  bool get isLoading => _isLoading;

  AuthController() {
    _checkLocalAuth();
  }

  Future<void> _checkLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      _localUserData = json.decode(userDataString);
      _role = _localUserData?['role'];
      notifyListeners();
    }

    // Also sync with Firebase state
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        try {
          final hasAccess = await _checkAndSyncUserRole(user);
          if (hasAccess) {
            await _saveUserLocally(user);
          } else {
            await signOut();
          }
        } catch (e) {
          debugPrint('Error in auth state change verification: $e');
          await signOut();
        }
      }
      notifyListeners();
    });
  }

  Future<bool> _checkAndSyncUserRole(User user) async {
    final email = user.email;
    if (email == null) return false;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(email.toLowerCase());
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final role = data?['role'] as String?;
        if (role == 'Admin' || role == 'Member') {
          _role = role;
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error verifying user role from firestore: $e');
      // If we are offline, fall back to cached role if it matches the current user
      if (_localUserData != null &&
          _localUserData?['email']?.toString().toLowerCase() ==
              email.toLowerCase()) {
        final cachedRole = _localUserData?['role'] as String?;
        if (cachedRole == 'Admin' || cachedRole == 'Member') {
          _role = cachedRole;
          return true;
        }
      }
    }
    return false;
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
        final hasAccess = await _checkAndSyncUserRole(_user!);
        if (!hasAccess) {
          await signOut();
          throw FirebaseAuthException(
            code: 'access-denied',
            message:
                'Access Denied: You are not authorized to use this application.',
          );
        }
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
        final hasAccess = await _checkAndSyncUserRole(_user!);
        if (!hasAccess) {
          await signOut();
          throw FirebaseAuthException(
            code: 'access-denied',
            message:
                'Access Denied: You are not authorized to use this application.',
          );
        }
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
      'role': _role,
    };
    await prefs.setString('user_data', json.encode(userData));
    _localUserData = userData;
    return userData;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _user = null;
    _localUserData = null;
    _role = null;
    notifyListeners();
  }
}
