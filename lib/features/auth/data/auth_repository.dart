import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/utils/validators.dart';
import 'app_user.dart';

class AuthRepository {
  AuthRepository(
    this._auth,
    this._firestore, {
    this.onUserUpdated,
  });

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final VoidCallback? onUserUpdated;

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInitFuture;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<AppUser?> appUserStream(String uid) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Workaround for Windows threading issue with Firestore snapshots
      return Stream.fromFuture(fetchUser(uid)).asBroadcastStream();
    }
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<AppUser?> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String location,
    required String community,
  }) async {
    _validateBasicProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      location: location,
      community: community,
      password: password,
    );

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _persistProfile(
      user: credential.user!,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      location: location,
      community: community,
    );

    await credential.user!.updateDisplayName('$firstName $lastName');
    await credential.user!.reload();

    if (!credential.user!.emailVerified) {
      await credential.user!.sendEmailVerification();
    }

    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    late GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (error) {
      throw Exception(
        'Google sign-in failed: ${error.description ?? error.code.name}',
      );
    }

    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw StateError('Chybí Google ID token');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(result.user);
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(result.user);
    return result;
  }

  Future<void> signOut() async {
    if (_googleSignInInitFuture != null) {
      await _googleSignInInitFuture;
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  Future<void> updateProfile(AppUser profile) async {
    final updateAt = DateTime.now();
    await _firestore.collection('users').doc(profile.uid).set(
          profile.copyWith(updatedAt: updateAt).toMap(),
          SetOptions(merge: true),
        );
    await _auth.currentUser
        ?.updateDisplayName('${profile.firstName} ${profile.lastName}'.trim());
    // Notify that user data has been updated
    onUserUpdated?.call();
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> syncEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      return;
    }
    await _firestore.collection('users').doc(user.uid).set(
      {
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // Notify that user data has been updated
    onUserUpdated?.call();
  }

  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'firstName': user.displayName?.split(' ').first ?? '',
        'lastName': user.displayName?.split(' ').skip(1).join(' ') ?? '',
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'location': '',
        'community': '',
        'isAdmin': false,
        'emailVerified': user.emailVerified,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'emailVerified': user.emailVerified,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _persistProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String location,
    required String community,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': user.email ?? '',
      'phoneNumber': phoneNumber.trim(),
      'location': location.trim(),
      'community': community.trim(),
      'isAdmin': false,
      'emailVerified': user.emailVerified,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _validateBasicProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String location,
    required String community,
    required String password,
  }) {
    final validations = [
      AppValidators.validateFirstName(firstName),
      AppValidators.validateLastName(lastName),
      AppValidators.validateEmail(email),
      AppValidators.validatePhone(phoneNumber),
      AppValidators.validateRequired(location),
      AppValidators.validateRequired(community),
      AppValidators.validatePassword(password),
    ];

    final failing = validations.whereType<String>().toList();
    if (failing.isNotEmpty) {
      throw StateError(failing.first);
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    _googleSignInInitFuture ??= _googleSignIn.initialize();
    await _googleSignInInitFuture;
  }
}
