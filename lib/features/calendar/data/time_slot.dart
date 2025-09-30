import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ParticipantSummary extends Equatable {
  const ParticipantSummary({
    required this.uid,
    required this.firstName,
    required this.lastName,
  });

  final String uid;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  factory ParticipantSummary.fromMap(Map<String, dynamic> map) {
    return ParticipantSummary(
      uid: map['uid'] as String,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [uid, firstName, lastName];
}

class TimeSlot extends Equatable {
  const TimeSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.capacity,
    required this.participants,
    required this.participantIds,
    required this.updatedAt,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final List<ParticipantSummary> participants;
  final List<String> participantIds;
  final DateTime updatedAt;

  bool get isFull => participants.length >= capacity;

  bool containsUser(String uid) =>
      participants.any((participant) => participant.uid == uid);

  TimeSlot copyWith({
    List<ParticipantSummary>? participants,
    List<String>? participantIds,
    DateTime? updatedAt,
  }) {
    return TimeSlot(
      id: id,
      start: start,
      end: end,
      capacity: capacity,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'capacity': capacity,
      'participants': participants.map((e) => e.toMap()).toList(),
      'participantIds': participantIds,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TimeSlot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final timestamp = data['start'] as Timestamp?;
    final endTimestamp = data['end'] as Timestamp?;
    final participants =
        (data['participants'] as List<dynamic>? ?? []).map((participant) {
      return ParticipantSummary.fromMap(
        Map<String, dynamic>.from(participant as Map),
      );
    }).toList();
    final participantIds = (data['participantIds'] as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList();

    return TimeSlot(
      id: doc.id,
      start: timestamp?.toDate() ?? DateTime.now(),
      end: endTimestamp?.toDate() ??
          (timestamp?.toDate() ?? DateTime.now()).add(const Duration(minutes: 30)),
      capacity: (data['capacity'] as num?)?.toInt() ?? 10,
      participants: participants,
      participantIds: participantIds.isEmpty
          ? participants.map((participant) => participant.uid).toList()
          : participantIds,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static String buildId(DateTime start) {
    return start.toUtc().toIso8601String();
  }

  static Map<String, dynamic> initialData(DateTime start, int capacity) {
    final end = start.add(const Duration(minutes: 30));
    return {
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'capacity': capacity,
      'participants': <Map<String, dynamic>>[],
      'participantIds': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props =>
      [id, start, end, capacity, participants, participantIds, updatedAt];
}
