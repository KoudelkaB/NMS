import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../auth/data/app_user.dart';
import 'time_slot.dart';

class CalendarRepository {
  CalendarRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _slotsCollection =>
      _firestore.collection('timeSlots');

  Stream<List<TimeSlot>> watchSlots(DateTime from, DateTime to) {
    return _slotsCollection
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('start', isLessThan: Timestamp.fromDate(to))
        .orderBy('start')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TimeSlot.fromDoc).toList());
  }

  Stream<List<TimeSlot>> watchUserAssignments(String uid, {DateTime? from}) {
    // Note: array-contains with orderBy requires a composite index in Firestore
    // To avoid this, we only use array-contains and do filtering + sorting in memory

    // Only load slots that haven't ended yet to minimize Firestore reads
    // Slots end 30 minutes after start, so we filter by 'end' field
    // final now = DateTimeUtils.nowInPrague;

    return _slotsCollection
        .where('participantIds', arrayContains: uid)
        // .where('end', isGreaterThan: Timestamp.fromDate(now)) // needs index on end which we do not have yet

        .snapshots()
        .map((snapshot) {
      var slots = snapshot.docs.map(TimeSlot.fromDoc).toList();

      // Filter by date in memory if needed
      if (from != null) {
        slots = slots
            .where(
              (slot) =>
                  slot.start.isAfter(from) || slot.start.isAtSameMomentAs(from),
            )
            .toList();
      }

      // Sort by start time in memory
      slots.sort((a, b) => a.start.compareTo(b.start));

      return slots;
    });
  }

  Future<void> toggleSlot({
    required AppUser user,
    required DateTime start,
    bool weeklyRecurring = false,
    int recurringWeeks = 12,
  }) async {
    final normalizedStart = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    ); // local time is OK

    // Check if the slot has already ended (30 min after start)
    final slotEnd = normalizedStart.add(const Duration(minutes: 30));
    if (slotEnd.isBefore(DateTimeUtils.nowInPrague)) {
      throw StateError('Nelze upravovat časy, které již proběhly');
    }

    await _firestore.runTransaction((transaction) async {
      final operations = <_TransactionCommand>[];

      final firstRef = _slotsCollection.doc(TimeSlot.buildId(normalizedStart));
      final firstSnapshot = await transaction.get(firstRef);
      final firstResult = _prepareToggleCommand(
        docRef: firstRef,
        snapshot: firstSnapshot,
        user: user,
        slotStart: normalizedStart,
        shouldJoin: null,
      );

      if (firstResult.command != null) {
        operations.add(firstResult.command!);
      }

      if (weeklyRecurring && firstResult.joined) {
        for (var i = 1; i <= max(1, recurringWeeks); i++) {
          final nextStart = normalizedStart.add(Duration(days: 7 * i));
          final nextRef = _slotsCollection.doc(TimeSlot.buildId(nextStart));
          final nextSnapshot = await transaction.get(nextRef);
          final nextResult = _prepareToggleCommand(
            docRef: nextRef,
            snapshot: nextSnapshot,
            user: user,
            slotStart: nextStart,
            shouldJoin: true,
          );

          if (nextResult.command != null) {
            operations.add(nextResult.command!);
          }
        }
      }

      for (final command in operations) {
        command(transaction);
      }
    });
  }

  _ToggleComputation _prepareToggleCommand({
    required DocumentReference<Map<String, dynamic>> docRef,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required AppUser user,
    required DateTime slotStart,
    bool? shouldJoin,
  }) {
    final slot = _snapshotToSlot(
      snapshot: snapshot,
      slotStart: slotStart,
    );

    final alreadyAssigned = slot.containsUser(user.uid);
    final join = shouldJoin ?? !alreadyAssigned;

    if (!join) {
      if (!alreadyAssigned) {
        return const _ToggleComputation(joined: false);
      }

      final updatedParticipants =
          slot.participants.where((p) => p.uid != user.uid).toList();

      return _ToggleComputation(
        joined: false,
        command: (transaction) {
          transaction.set(
            docRef,
            {
              'start': Timestamp.fromDate(slot.start),
              'end': Timestamp.fromDate(slot.end),
              'capacity': slot.capacity,
              'participants':
                  updatedParticipants.map((p) => p.toMap()).toList(),
              'participantIds': updatedParticipants.map((p) => p.uid).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        },
      );
    }

    if (alreadyAssigned) {
      return const _ToggleComputation(joined: false);
    }

    if (slot.isFull) {
      throw StateError('Kapacita tohoto času je již naplněna');
    }

    final updatedParticipants = [
      ...slot.participants,
      ParticipantSummary(
        uid: user.uid,
        firstName: user.firstName,
        lastName: user.lastName,
      ),
    ];

    return _ToggleComputation(
      joined: true,
      command: (transaction) {
        transaction.set(
          docRef,
          {
            'start': Timestamp.fromDate(slot.start),
            'end': Timestamp.fromDate(slot.end),
            'capacity': slot.capacity,
            'participants': updatedParticipants.map((p) => p.toMap()).toList(),
            'participantIds': updatedParticipants.map((p) => p.uid).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      },
    );
  }

  TimeSlot _snapshotToSlot({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required DateTime slotStart,
  }) {
    if (!snapshot.exists) {
      final slotId = TimeSlot.buildId(slotStart);
      return TimeSlot(
        id: slotId,
        start: slotStart,
        end: slotStart.add(const Duration(minutes: 30)),
        capacity: 10,
        participants: const [],
        participantIds: const [],
        updatedAt: DateTime.now(),
      );
    }

    return TimeSlot.fromDoc(snapshot);
  }
}

typedef _TransactionCommand = void Function(Transaction transaction);

class _ToggleComputation {
  const _ToggleComputation({required this.joined, this.command});

  final bool joined;
  final _TransactionCommand? command;
}
