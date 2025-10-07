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
    required this.capacity,
    required this.participants,
    required this.participantIds,
    required this.updatedAt,
  });

  final String id;
  final DateTime start;
  final int capacity;
  final List<ParticipantSummary> participants;
  final List<String> participantIds;
  final DateTime updatedAt;

  DateTime get end => start.add(const Duration(minutes: 30));

  bool get isFull => participants.length >= capacity;

  bool get isPast => end.isBefore(DateTime.now());

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
      capacity: capacity,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    // Only persist mutable fields; 'start' is the document ID, capacity is constant (10)
    return {
      'participants': participants.map((e) => e.toMap()).toList(),
      'participantIds': participantIds,
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
    };
  }

  factory TimeSlot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Derive start from document ID (ISO8601 UTC string), fallback to 'start' field if present
    DateTime startLocal;
    try {
      final parsed = DateTime.parse(doc.id);
      startLocal = parsed.toLocal();
    } catch (_) {
      final ts = data['start'] as Timestamp?;
      startLocal = (ts?.toDate() ?? DateTime.now()).toLocal();
    }
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
  // Use local time for UI/logic; canonical time is encoded in doc ID as UTC
  start: startLocal,
  capacity: 10,
      participants: participants,
      participantIds: participantIds.isEmpty
          ? participants.map((participant) => participant.uid).toList()
          : participantIds,
      updatedAt:
          ((data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now())
              .toLocal(),
    );
  }

  static String buildId(DateTime start) {
    return start.toUtc().toIso8601String();
  }

  @override
  List<Object?> get props =>
      [id, start, capacity, participants, participantIds, updatedAt];
}
