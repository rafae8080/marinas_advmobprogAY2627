import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/user.dart';

ValueNotifier<UserService> userService = ValueNotifier(UserService());

class UserService {
  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$host/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'expiresInMins': 60,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Act5 Enhancement 2: /auth/login leaves out age and phone, so the full
      // record is read from /auth/me with the new token. The login still
      // succeeds if that second call fails.
      data.addAll(await _fetchDummyProfile(data['accessToken'] ?? ''));
      data['loginType'] = LoginType.dummyJson.name;
      await saveUserData(data);
      return data;
    } else {
      throw Exception(response.body);
    }
  }

  Future<Map<String, dynamic>> _fetchDummyProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$host/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return {};
      final me = jsonDecode(response.body) as Map<String, dynamic>;
      return {'age': me['age'], 'phone': me['phone']};
    } catch (_) {
      return {};
    }
  }

  /// **Save User Data to SharedPreferences**
  /// Builds a User from the raw API response, then persists each field
  /// individually so getUserData()/getUser() can rebuild it on relaunch.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(userData);

    await prefs.setInt('id', user.id);
    await prefs.setString('uid', user.uid);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    await prefs.setString('firstName', user.firstName);
    await prefs.setString('lastName', user.lastName);
    await prefs.setString('gender', user.gender);
    await prefs.setString('image', user.image);
    await prefs.setInt('age', user.age);
    await prefs.setString('phone', user.phone);
    await prefs.setString('loginType', user.loginType.name);
    await prefs.setString('accessToken', user.accessToken);
    await prefs.setString('refreshToken', user.refreshToken);

    // dummyjson's /auth/login returns "accessToken"; some flows may only
    // send a generic "token" — keep both in sync either way.
    if (userData.containsKey('token')) {
      await prefs.setString('token', userData['token'] ?? '');
    } else if (user.accessToken.isNotEmpty) {
      await prefs.setString('token', user.accessToken);
    }
  }

  /// Retrieve raw user data from SharedPreferences as a Map
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'id': prefs.getInt('id') ?? 0,
      'uid': prefs.getString('uid') ?? '',
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'gender': prefs.getString('gender') ?? '',
      'image': prefs.getString('image') ?? '',
      'age': prefs.getInt('age') ?? 0,
      'phone': prefs.getString('phone') ?? '',
      'loginType': prefs.getString('loginType') ?? LoginType.dummyJson.name,
      'accessToken': prefs.getString('accessToken') ?? '',
      'refreshToken': prefs.getString('refreshToken') ?? '',
      'token': prefs.getString('token') ?? prefs.getString('accessToken') ?? '',
    };
  }

  /// Retrieve a User model built from SharedPreferences
  /// (used by profile_screen.dart to render the profile)
  Future<User> getUser() async {
    final userData = await getUserData();
    return User.fromJson(userData);
  }

  /// **Check if User is Logged In**
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  /// **Logout and Clear User Data**
  Future<void> logout() async {
    try {
      // Act5 Enhancement 1: a Firebase session lives in the SDK as well as in
      // SharedPreferences, so both have to be cleared.
      if (Firebase.apps.isNotEmpty && currentUser != null) await signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to log out: $e');
    }
  }

  // Act5 Enhancement 2: token refresh, run by the splash screen on every
  // start. Returns false when the session can no longer be renewed.
  Future<bool> refreshSession() async {
    final user = await getUser();
    final prefs = await SharedPreferences.getInstance();

    if (user.isFirebase) {
      final firebaseUser = currentUser;
      if (firebaseUser == null || firebaseUser.uid != user.uid) return false;
      try {
        final idToken = await firebaseUser.getIdToken(true);
        if (idToken != null) {
          await prefs.setString('accessToken', idToken);
          await prefs.setString('token', idToken);
        }
      } on fb.FirebaseAuthException catch (e) {
        // Offline is not a reason to sign someone out; a revoked or deleted
        // account is.
        return e.code == 'network-request-failed';
      }
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$host/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': user.refreshToken,
          'expiresInMins': 60,
        }),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await prefs.setString('accessToken', data['accessToken'] ?? '');
      await prefs.setString('token', data['accessToken'] ?? '');
      await prefs.setString('refreshToken', data['refreshToken'] ?? '');
      return true;
    } catch (_) {
      return true;
    }
  }

  // Act5 Enhancement 1: Firebase Authentication.

  // late, so building a UserService never touches Firebase until it is used.
  late final fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;

  fb.User? get currentUser => firebaseAuth.currentUser;

  Stream<fb.User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<fb.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _saveFirebaseSession(credential.user!);
    return credential;
  }

  Future<fb.UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> updateUsername({required String username}) async {
    final user = await getUser();
    if (user.isFirebase) {
      await currentUser!.updateDisplayName(username);
      await _writeProfile(currentUser!.uid, {'username': username});
    } else {
      // Act5 Enhancement 3: DummyJSON answers PUT /users/{id} with the updated
      // user but never stores it, so the change is kept locally only.
      final response = await http.put(
        Uri.parse('$host/users/${user.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      if (response.statusCode != 200) throw Exception(response.body);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    fb.AuthCredential credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await currentUser!.reauthenticateWithCredential(credential);
    // The security rules only let a signed-in owner delete their document, so
    // it has to go before the account does.
    await _deleteProfile(currentUser!.uid);
    await currentUser!.delete();
    await logout();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    fb.AuthCredential credential = fb.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  // Act5 Enhancement 2: signup. Firebase Auth only keeps the email, password
  // and display name, so the remaining fields go to Firestore under users/{uid}.
  Future<void> registerUser({
    required String firstName,
    required String lastName,
    required int age,
    required String phone,
    required String username,
    required String email,
    required String password,
  }) async {
    final credential = await createAccount(email: email, password: password);
    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(username);

    final profile = User(
      id: 0,
      uid: firebaseUser.uid,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      gender: '',
      image: '',
      age: age,
      phone: phone,
      loginType: LoginType.firebase,
      accessToken: '',
      refreshToken: '',
    );
    await _writeProfile(firebaseUser.uid, profile.toProfileJson());
    await _saveFirebaseSession(firebaseUser, profile: profile.toProfileJson());
  }

  static const _firestoreTimeout = Duration(seconds: 8);

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  // Firestore trouble (no database yet, offline) must not block signing in,
  // so these fall back to what Firebase Auth alone knows.
  Future<void> _writeProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _profileDoc(
        uid,
      ).set(data, SetOptions(merge: true)).timeout(_firestoreTimeout);
    } catch (_) {}
  }

  Future<void> _deleteProfile(String uid) async {
    try {
      await _profileDoc(uid).delete().timeout(_firestoreTimeout);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _readProfile(String uid) async {
    try {
      final snapshot = await _profileDoc(uid).get().timeout(_firestoreTimeout);
      return snapshot.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveFirebaseSession(
    fb.User firebaseUser, {
    Map<String, dynamic>? profile,
  }) async {
    final data = {...(profile ?? await _readProfile(firebaseUser.uid))};
    final idToken = await firebaseUser.getIdToken();

    data['uid'] = firebaseUser.uid;
    data['email'] = firebaseUser.email ?? '';
    data['image'] = firebaseUser.photoURL ?? '';
    data['loginType'] = LoginType.firebase.name;
    data['accessToken'] = idToken ?? '';
    data['refreshToken'] = firebaseUser.refreshToken ?? '';
    if ((data['username'] ?? '').isEmpty) {
      data['username'] = firebaseUser.displayName ?? '';
    }
    await saveUserData(data);
  }
}
