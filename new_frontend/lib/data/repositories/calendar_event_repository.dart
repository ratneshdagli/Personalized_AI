import 'package:isar/isar.dart';
import '../schema/calendar_event.dart';

class CalendarEventRepository {
  final Isar isar;

  CalendarEventRepository(this.isar);

  Future<List<CalendarEvent>> getEvents() async {
    return await isar.calendarEvents
        .where()
        .sortByStart()
        .findAll();
  }
  
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await isar.calendarEvents
        .filter()
        .startGreaterThan(startOfDay, include: true)
        .and()
        .startLessThan(endOfDay)
        .sortByStart()
        .findAll();
  }

  Future<int> addEvent(CalendarEvent event) async {
    return await isar.writeTxn(() async {
      return await isar.calendarEvents.put(event);
    });
  }

  Future<void> deleteEvent(int id) async {
    await isar.writeTxn(() async {
      await isar.calendarEvents.delete(id);
    });
  }
}
