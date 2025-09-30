import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/admin/presentation/admin_announcements_page.dart';
import '../widgets/app_splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(appUserProvider);

  return GoRouter(
    initialLocation: '/calendar',
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      final bool isLoading = authState.isLoading;
      final bool isLoggedIn = authState.value != null;
      final bool isRegistering = state.uri.path == '/register';
      final bool isSigningIn = state.uri.path == '/sign-in';
      final bool isAuthRoute = isRegistering || isSigningIn;

      if (isLoading) {
        return state.uri.path == '/splash' ? null : '/splash';
      }

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/sign-in';
      }

  if (currentUser.value == null) {
        return state.uri.path == '/profile' ? null : '/profile';
      }

      if (isAuthRoute) {
        return '/calendar';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const AppSplashPage(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminAnnouncementsPage(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
