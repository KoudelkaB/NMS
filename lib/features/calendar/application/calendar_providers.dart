import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/data/app_user.dart';
import '../data/calendar_repository.dart';
import '../data/time_slot.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CalendarRepository(firestore);
});

final calendarFocusDayProvider =
    NotifierProvider<CalendarFocusDayNotifier, DateTime>(
  CalendarFocusDayNotifier.new,
);

class CalendarFocusDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
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

final daySlotsProvider = StreamProvider<List<TimeSlot>>((ref) {
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
  return BookingAction(repository: repository, user: user);
});

final userAssignmentsProvider = StreamProvider<List<TimeSlot>>((ref) {
  final user = ref.watch(currentAppUserProvider);
  if (user == null) {
    return const Stream.empty();
  }
  final repository = ref.watch(calendarRepositoryProvider);
  final from = DateTime.now().subtract(const Duration(days: 1));
  return repository.watchUserAssignments(user.uid, from: from);
});

class BookingAction {
  BookingAction({required this.repository, required this.user});

  final CalendarRepository repository;
  final AppUser user;

  Future<void> toggleSlot(DateTime start, {bool weeklyRecurring = false}) {
    return repository.toggleSlot(
      user: user,
      start: start,
      weeklyRecurring: weeklyRecurring,
    );
  }
}
