import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

// Cache invalidation trigger for user data
final appUserInvalidatorProvider =
    NotifierProvider<AppUserInvalidatorNotifier, int>(
  AppUserInvalidatorNotifier.new,
);

class AppUserInvalidatorNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void invalidate() {
    state++;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AuthRepository(
    auth,
    firestore,
    onUserUpdated: () {
      // Invalidate user cache when profile is updated
      ref.read(appUserInvalidatorProvider.notifier).invalidate();
    },
  );
});

final authStateProvider = StreamProvider.autoDispose<User?>((ref) {
  // Keep alive for better caching
  final link = ref.keepAlive();
  // Dispose after 30 minutes of inactivity
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 30), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });

  return ref.watch(authRepositoryProvider).authStateChanges();
});

final appUserProvider = StreamProvider.autoDispose<NullableAppUser>((ref) {
  // Keep alive for better caching
  final link = ref.keepAlive();
  // Dispose after 30 minutes of inactivity
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 30), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });

  // Watch invalidator to force refresh when needed
  ref.watch(appUserInvalidatorProvider);

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
