import 'package:flutter_test/flutter_test.dart';
import 'package:nms/features/calendar/data/time_slot.dart';

void main() {
  group('TimeSlot', () {
    test('buildId produces stable UTC-based id', () {
      final localDate = DateTime(2025, 9, 29, 15, 30);
      final expectedUtc = localDate.toUtc();
      final id = TimeSlot.buildId(localDate);
      expect(id.contains(expectedUtc.toIso8601String().substring(0, 16)), isTrue);
    });

    test('containsUser identifies assigned participants', () {
      final slot = TimeSlot(
        id: 'slot',
        start: DateTime(2025, 9, 29, 12),
        capacity: 10,
        participants: const [
          ParticipantSummary(uid: '123', firstName: 'Jan', lastName: 'Novák'),
        ],
        participantIds: const ['123'],
        updatedAt: DateTime(2025, 9, 29, 12),
      );
      expect(slot.containsUser('123'), isTrue);
      expect(slot.containsUser('999'), isFalse);
      expect(slot.end, DateTime(2025, 9, 29, 12, 30));
    });
  });
}
