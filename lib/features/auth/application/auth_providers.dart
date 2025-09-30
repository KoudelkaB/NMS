import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';

typedef NullableAppUser = AppUser?;

typedef AuthState = AsyncValue<User?>;

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AuthRepository(auth, firestore);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final appUserProvider = StreamProvider<NullableAppUser>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final repository = ref.watch(authRepositoryProvider);
  final user = auth.currentUser;
  if (user == null) {
    return const Stream.empty();
  }
  return repository.appUserStream(user.uid);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value != null;
});

final emailVerificationSyncProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (previous, next) {
    final previousVerified = previous?.value?.emailVerified ?? false;
    final currentUser = next.value;
    if (currentUser?.emailVerified == true && !previousVerified) {
      ref.read(authRepositoryProvider).syncEmailVerification();
    }
  });
});
