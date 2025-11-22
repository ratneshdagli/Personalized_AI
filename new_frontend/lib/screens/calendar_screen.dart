import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/lavish_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/calendar_event_sheet.dart';
import '../widgets/event_chip.dart';
import '../widgets/dashed_separator.dart';
import '../widgets/common_styles.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _view = 'month'; // 'day', 'week', 'month'

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _setView(String view) {
    setState(() {
      _view = view;
      // Auto-collapse calendar for Day/Week views
      if (view == 'month') {
        _calendarFormat = CalendarFormat.month;
      } else {
        _calendarFormat = CalendarFormat.week;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final events = state.eventsForDay(_selectedDay ?? _focusedDay);


    return LavishBackground(
      dark: true,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTableCalendar(state),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildBody(state, events),
                ),
              ],
            ),
          ),
          // Floating Action Button
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CalendarEventSheet(),
                );
              },
              backgroundColor: const Color(0xFFA855F7),
              child: const Icon(LucideIcons.plus, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppState state, List<dynamic> events) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _view == 'day'
          ? _DayTimeline(
              key: const ValueKey('day'),
              events: events,
              selectedDay: _selectedDay ?? _focusedDay,
            )
          : _view == 'week'
              ? _WeekGrid(
                  key: const ValueKey('week'),
                  selectedDay: _selectedDay ?? _focusedDay,
                )
              : _buildEventList(events), // Month view uses standard list
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay on top of your tasks & events',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay = _focusedDay;
                  });
                },
                child: GlassCard(
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white.withOpacity(0.1),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // View Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0x801E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewChip('Day'),
                _viewChip('Week'),
                _viewChip('Month'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewChip(String label) {
    final key = label.toLowerCase();
    final active = _view == key;
    return GestureDetector(
      onTap: () => _setView(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCalendar(AppState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0x801E293B), // slate-800/50
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  // Update global state if necessary
                  context.read<AppState>().selectDay(selectedDay);
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: (day) {
                return state.eventsForDay(day);
              },
              
              // Styling
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                weekendStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: const Icon(LucideIcons.chevronLeft, color: Colors.white70, size: 20),
                rightChevronIcon: const Icon(LucideIcons.chevronRight, color: Colors.white70, size: 20),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                
                // Selected Day
                selectedDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFA855F7), Color(0xFFEC4899)], // Purple to Pink
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                
                // Today
                todayDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                
                // Markers (Dots)
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF60A5FA), // Blue-400
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventList(List<dynamic> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.calendarX,
                size: 48,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No events for this day',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _EventCard(event: event),
        );
      },
    );
  }
}

// --- Restored Components ---

// Timeline model
abstract class _TimeBlock {}
class _EventBlock extends _TimeBlock {
  final dynamic event;
  _EventBlock(this.event);
}
class _EmptyBlock extends _TimeBlock {
  final TimeOfDay start;
  final TimeOfDay end;
  _EmptyBlock(this.start, this.end);
}

List<_TimeBlock> _generateSmartTimeBlocks(List<dynamic> events, {int startHour = 6, int endHour = 23}) {
  final sorted = [...events]
    ..sort((a, b) => (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));
  final blocks = <_TimeBlock>[];
  int cursor = startHour * 60;
  for (final e in sorted) {
    final estart = e.start.hour * 60 + e.start.minute;
    if (estart > cursor) {
      blocks.add(_EmptyBlock(TimeOfDay(hour: cursor ~/ 60, minute: cursor % 60), TimeOfDay(hour: estart ~/ 60, minute: estart % 60)));
    }
    blocks.add(_EventBlock(e));
    cursor = estart + e.duration.inMinutes;
  }
  final dayEnd = (endHour + 1) * 60;
  if (cursor < dayEnd) {
    blocks.add(_EmptyBlock(TimeOfDay(hour: cursor ~/ 60, minute: cursor % 60), TimeOfDay(hour: dayEnd ~/ 60, minute: dayEnd % 60)));
  }
  return blocks;
}

String _shortTime(TimeOfDay t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final p = t.hour >= 12 ? 'PM' : 'AM';
  return '$h:$mm $p';
}

String _formatTimeRange(TimeOfDay start, Duration dur) {
  String fmt(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hour:$mm $period';
  }
  int m = start.hour * 60 + start.minute + dur.inMinutes;
  final end = TimeOfDay(hour: (m ~/ 60), minute: (m % 60));
  return '${fmt(start)} - ${fmt(end)}';
}

class _DayTimeline extends StatelessWidget {
  final List<dynamic> events;
  final DateTime selectedDay;
  
  const _DayTimeline({super.key, required this.events, required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    const startHour = 6;
    const endHour = 23;
    final blocks = _generateSmartTimeBlocks(events, startHour: startHour, endHour: endHour);

    Widget hourHeader(TimeOfDay t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(_shortTime(t), style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in blocks)
            if (b is _EmptyBlock)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CalendarEventSheet(initialStart: b.start),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: CommonStyles.glass(radius: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          hourHeader(b.start),
                          const SizedBox(width: 8),
                          const Expanded(child: DashedSeparator(color: Color(0x22FFFFFF), dashWidth: 6, dashGap: 6, thickness: 1)),
                          const SizedBox(width: 8),
                          Text(_shortTime(b.end), style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else if (b is _EventBlock)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EventChip(
                  gradient: b.event.gradient,
                  icon: LucideIcons.calendar,
                  title: b.event.title,
                  time: _formatTimeRange(b.event.start, b.event.duration),
                  location: b.event.location,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CalendarEventSheet(eventId: b.event.id),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final DateTime selectedDay;
  
  const _WeekGrid({super.key, required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Calculate start of week (Monday)
    final int weekday = selectedDay.weekday; // 1..7
    final start = selectedDay.subtract(Duration(days: weekday - 1));
    final days = List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));

    List<Widget> dayColumn(DateTime d) {
      final events = state.eventsForDay(d);
      final isSelected = isSameDay(d, selectedDay);
      
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                DateFormat('E').format(d), // Mon, Tue...
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.slate400,
                  fontSize: 11,
                  fontWeight: FontWeight.w600
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: isSelected ? const BoxDecoration(
                  color: Color(0xFFA855F7),
                  shape: BoxShape.circle,
                ) : null,
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.slate300,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: '${e.title} (${_shortTime(e.start)})',
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CalendarEventSheet(eventId: e.id),
                ),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: e.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.calendar, // Or specific icon
                      color: Colors.white.withOpacity(0.9),
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: dayColumn(d),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final dynamic event; 

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final String title = event.title;
    final TimeOfDay start = event.start;
    final Duration duration = event.duration;
    final List<Color> gradient = event.gradient;
    final String? location = event.location;

    return GestureDetector(
      onTap: () {
         showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CalendarEventSheet(eventId: event.id),
        );
      },
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 12, color: Colors.white.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeRange(start, duration),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (location != null) ...[
                        const SizedBox(width: 12),
                        Icon(LucideIcons.mapPin, size: 12, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

