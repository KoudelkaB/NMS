import 'package:cloud_functions/cloud_functions.dart';

import 'announcement_type.dart';

class AdminRepository {
  AdminRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<void> sendAnnouncement({
    required AdminAnnouncementType type,
    required String title,
    required String message,
  }) async {
    final callable = _functions.httpsCallable('sendAdminAnnouncement');
    await callable.call({
      'type': type.value,
      'title': title,
      'message': message,
    });
  }
}
