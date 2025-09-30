import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/admin_repository.dart';
import '../data/announcement_type.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final functions = ref.watch(firebaseFunctionsProvider);
  return AdminRepository(functions);
});

final adminAnnouncementControllerProvider =
    AsyncNotifierProvider<AdminAnnouncementController, void>(
  AdminAnnouncementController.new,
);

class AdminAnnouncementController extends AsyncNotifier<void> {
  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  @override
  FutureOr<void> build() {
    return null;
  }

  Future<void> sendAnnouncement({
    required AdminAnnouncementType type,
    required String title,
    required String message,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.sendAnnouncement(
        type: type,
        title: title,
        message: message,
      );
    });
  }
}
