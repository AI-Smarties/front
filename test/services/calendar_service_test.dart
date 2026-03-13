import 'package:flutter_test/flutter_test.dart';
import 'package:front/services/calendar_service.dart';

void main() {
  group('CalendarService.selectActiveContext', () {
    final service = CalendarService();

    test('returns null when event list is empty', () {
      final result = service.selectActiveContext([]);

      expect(result, isNull);
    });
    test('return active event when one is happening now', () {
      final now = DateTime.now();
      final events = [
        CalendarEventModel(
            title: 'Business meeting',
            description: 'Discussing quarterly results',
            start: now.subtract(const Duration(minutes: 30)),
            end: now.add(const Duration(minutes: 30))),
      ];
      final result = service.selectActiveContext(events);

      expect(result, isNotNull);
      expect(result!.title, 'Business meeting');
    });
    test('return upcoming event when no event is active', () {
      final now = DateTime.now();
      final events = [
        CalendarEventModel(
            title: 'Project deadline',
            description: 'Submit final report',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 2))),
        CalendarEventModel(
            title: 'Later meeting',
            description: 'Retrospective',
            start: now.add(const Duration(hours: 3)),
            end: now.add(const Duration(hours: 4))),
      ];
      final result = service.selectActiveContext(events);

      expect(result, isNotNull);
      expect(result!.title, 'Project deadline');
    });
  });

  group('CalendarService.buildCalendarPayload', () {
    final service = CalendarService();

    test('Build payload from active event', () {
      final event = CalendarEventModel(
          title: 'Business meeting',
          description: 'Discussing quarterly results',
          start: DateTime.parse('2025-06-01T10:00:00Z'),
          end: DateTime.parse('2025-06-01T11:00:00Z'));
      final payload = service.buildCalendarPayload(event);

      expect(payload['type'], 'calendar_context');
      expect(payload['data']['title'], 'Business meeting');
      expect(payload['data']['description'], 'Discussing quarterly results');
      expect(payload['data']['start'], event.start.toIso8601String());
      expect(payload['data']['end'], event.end.toIso8601String());
    });
    test('Build payload with null description', () {
      final event = CalendarEventModel(
          title: 'Quick meeting',
          description: null,
          start: DateTime.parse('2025-06-01T12:00:00Z'),
          end: DateTime.parse('2025-06-01T12:30:00Z'));
      final payload = service.buildCalendarPayload(event);

      expect(payload['data']['title'], 'Quick meeting');
      expect(payload['data']['description'], isNull);
    });
  });
}
