import 'package:device_calendar/device_calendar.dart';

class CalendarService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  //Requests calendar permission
  Future<bool> requestPermission() async {
    var permissionsGranted = await _calendarPlugin.requestPermissions();
    if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
      return true;
      // Permission granted, you can now access the calendar
    } else {
      return false;
      // Permission denied, handle accordingly
    }
  }

  //Searches for upcoming events in the next 7 days
  Future<List<CalendarEventModel>> getUpcomingEvents() async {
    var calendarResult = await _calendarPlugin.retrieveCalendars();
    if (calendarResult.isSuccess && calendarResult.data != null) {
      List<Calendar> calendars = calendarResult.data!;
      List<CalendarEventModel> events = [];

      DateTime startDate = DateTime.now();
      DateTime endDate = startDate.add(const Duration(days: 7));

      for (var calendar in calendars) {
        var eventResult = await _calendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(startDate: startDate, endDate: endDate),
        );

        if (eventResult.isSuccess && eventResult.data != null) {
          List<Event> calendarEvents = eventResult.data!;
          for (var event in calendarEvents) {
            if (event.start != null && event.end != null) {
              events.add(
                CalendarEventModel(
                  title: event.title ?? 'No Title',
                  description: event.description,
                  start: event.start!,
                  end: event.end!,
                ),
              );
            }
          }
        }
      }
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    }
    return [];
  }

  //Selects the active or upcoming event
  CalendarEventModel? selectActiveContext(List<CalendarEventModel> events) {
    DateTime now = DateTime.now();
    //Event is happening now
    for (var event in events) {
      if (event.start.isBefore(now) && event.end.isAfter(now)) {
        return event;
      }
    }
    //Upcoming event
    for (var event in events) {
      if (event.start.isAfter(now)) {
        return event;
      }
    }
    //No active or upcoming events
    return null;
  }

  //Builds the payload to send to backend
  Map<String, dynamic> buildCalendarPayload(CalendarEventModel? event) {
    if (event == null) {
      return {
        "type": "calendar_context",
        "data": {
          "title": "General conversation",
          "description": null,
          "start": null,
          "end": null
        }
      };
    }
    return {
      "type": "calendar_context",
      "data": {
        "title": event.title,
        "description": event.description,
        "start": event.start.toIso8601String(),
        "end": event.end.toIso8601String()
      }
    };
  }
}

// Model to represent calendar events in a simplified way for our application
class CalendarEventModel {
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;

  CalendarEventModel({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });
}
