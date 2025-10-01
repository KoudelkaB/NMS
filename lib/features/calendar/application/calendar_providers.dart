import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/app_user.dart';
import '../data/calendar_repository.dart';
import '../data/time_slot.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CalendarRepository(firestore);
});

// Cache invalidation trigger for time slots
final timeSlotsInvalidatorProvider =
    NotifierProvider<TimeSlotsInvalidatorNotifier, int>(
  TimeSlotsInvalidatorNotifier.new,
);

class TimeSlotsInvalidatorNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void invalidate() {
    state++;
  }
}

final calendarFocusDayProvider =
    NotifierProvider<CalendarFocusDayNotifier, DateTime>(
  CalendarFocusDayNotifier.new,
);

class CalendarFocusDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTimeUtils.nowInPrague;
    return DateTime(now.year, now.month, now.day);
  }

  void setFocusDay(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final calendarWeekStartProvider = Provider<DateTime>((ref) {
  final focusDay = ref.watch(calendarFocusDayProvider);
  return focusDay.subtract(Duration(days: focusDay.weekday - 1));
});

final daySlotsProvider = StreamProvider.autoDispose<List<TimeSlot>>((ref) {
  // Keep alive for better caching
  final link = ref.keepAlive();
  // Dispose after 5 minutes of inactivity
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 5), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });

  // Watch invalidator to force refresh when needed
  ref.watch(timeSlotsInvalidatorProvider);

  final focusDay = ref.watch(calendarFocusDayProvider);
  final repository = ref.watch(calendarRepositoryProvider);
  final startOfDay = DateTime(focusDay.year, focusDay.month, focusDay.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  return repository.watchSlots(startOfDay, endOfDay);
});

final currentAppUserProvider = Provider<AppUser?>((ref) {
  final userAsync = ref.watch(appUserProvider);
  return userAsync.value;
});

final bookingActionProvider = Provider<BookingAction>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final user = ref.watch(currentAppUserProvider);
  if (user == null) {
    throw StateError('User must be signed in to interact with calendar.');
  }
  return BookingAction(
    repository: repository,
    user: user,
    onSlotChanged: () {
      // Invalidate cache when slot is changed
      ref.read(timeSlotsInvalidatorProvider.notifier).invalidate();
    },
  );
});

final userAssignmentsProvider =
    StreamProvider.autoDispose.family<List<TimeSlot>, String>((ref, uid) {
  // Keep alive for better caching
  final link = ref.keepAlive();
  // Dispose after 10 minutes of inactivity
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 10), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });

  // Watch invalidator to force refresh when needed
  ref.watch(timeSlotsInvalidatorProvider);

  final repository = ref.watch(calendarRepositoryProvider);
  final from = DateTime.now().subtract(const Duration(days: 1));
  return repository.watchUserAssignments(uid, from: from);
});

class BookingAction {
  BookingAction({
    required this.repository,
    required this.user,
    this.onSlotChanged,
  });

  final CalendarRepository repository;
  final AppUser user;
  final VoidCallback? onSlotChanged;

  Future<void> toggleSlot(
    DateTime start, {
    bool weeklyRecurring = false,
  }) async {
    await repository.toggleSlot(
      user: user,
      start: start,
      weeklyRecurring: weeklyRecurring,
    );
    // Notify that slot has changed
    onSlotChanged?.call();
  }
}
