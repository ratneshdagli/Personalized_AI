import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../widgets/gradient_background.dart';
import '../widgets/date_strip.dart';
import '../widgets/event_chip.dart';
import '../widgets/common_styles.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/dashed_separator.dart';
import '../widgets/calendar_event_sheet.dart';

// Visual-only Calendar port mapped from the TSX reference
// - Time-of-day header gradient
// - Date strip
// - Smart Timeline Day view (events + empty gaps)
// - Week view (compact per-day list)
// - Month view (expandable simple grid)
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

// Non-interactive modal/dialog shell to mirror Figma dialog visuals
class _CalendarModalShell extends StatelessWidget {
  final double width;
  const _CalendarModalShell({required this.width});

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 390;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x800F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24)],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add event (visual shell)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _shortTime(TimeOfDay t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final p = t.hour >= 12 ? 'PM' : 'AM';
  return '$h:$mm $p';
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected = DateTime(2025, 10, 18);
  String view = 'day';

  List<DateTime> _generateDates() {
    final base = DateTime(2025, 10, 17);
    return List.generate(14, (i) => base.add(Duration(days: i)));
  }

  LinearGradient _timeOfDayGradient(BuildContext context) {
    final hour = TimeOfDay.now().hour;
    if (hour < 6) return AppGradients.night(context);
    if (hour < 12) return AppGradients.morning(context);
    if (hour < 17) return AppGradients.afternoon(context);
    if (hour < 20) return AppGradients.evening(context);
    return AppGradients.night(context);
  }

  @override
  Widget build(BuildContext context) {
    final dates = _generateDates();
    final state = context.watch<AppState>();
    selected = state.selectedDay;
    view = state.calendarView;

    return GradientBackground(
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final headerPad = EdgeInsets.fromLTRB(16, 16, 16, w < 390 ? 6 : 8);
          final bodyPad = const EdgeInsets.fromLTRB(16, 0, 16, 96);
          return Column(
            children: [
                  // Header
                  Container(
                    margin: headerPad,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: _timeOfDayGradient(context),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20)],
                    ),
                    child: LayoutBuilder(builder: (context, c) {
                      final compact = c.maxWidth < 380;
                      return Row(
                        children: [
                          const Icon(LucideIcons.calendar, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              compact ? 'Calendar' : 'Your Calendar',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          _viewChip('Day'),
                          const SizedBox(width: 6),
                          _viewChip('Week'),
                          const SizedBox(width: 6),
                          _viewChip('Month'),
                          if (!compact) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _openAddEvent(context),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),

                  // Date strip
                  DateStrip(
                    dates: dates,
                    selected: selected,
                    onSelect: (d) => context.read<AppState>().selectDay(d),
                  ),
                  const SizedBox(height: 12),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: bodyPad,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: view == 'day'
                            ? _DayView(key: const ValueKey('day'))
                            : view == 'week'
                                ? _WeekView(key: const ValueKey('week'))
                                : _MonthView(key: const ValueKey('month')),
                      ),
                    ),
                  ),
            ],
          );
        }),
      ),
    );
  }

  Widget _viewChip(String label) {
    final active = label.toLowerCase() == view;
    return GestureDetector(
      onTap: () => context.read<AppState>().setCalendarView(label.toLowerCase()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x33A855F7) : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(active ? 0.5 : 0.25)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _openAddEvent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CalendarEventSheet(),
    );
  }
}

// Timeline model
abstract class _TimeBlock {}
class _EventBlock extends _TimeBlock {
  final CalendarEventVM event;
  _EventBlock(this.event);
}
class _EmptyBlock extends _TimeBlock {
  final TimeOfDay start;
  final TimeOfDay end;
  _EmptyBlock(this.start, this.end);
}

List<_TimeBlock> _generateSmartTimeBlocks(List<CalendarEventVM> events, {int startHour = 6, int endHour = 23}) {
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

class _DayView extends StatelessWidget {
  const _DayView({super.key});

  @override
  Widget build(BuildContext context) {
    // Timeline day view 6:00 → 23:00
    final state = context.watch<AppState>();
    final events = state.eventsForDay(state.selectedDay);
    const startHour = 6;
    const endHour = 23;
    const hourHeight = 64.0;
    final blocks = _generateSmartTimeBlocks(events, startHour: startHour, endHour: endHour);

    Widget hourHeader(TimeOfDay t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(_shortTime(t), style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
        );

    return Column(
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
    );
  }

  Widget _timeLabel(String label) => Text(
        label,
        style: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.w600),
      );

  String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$display $period';
  }

  String _formatTimeRange(TimeOfDay start, Duration dur) {
    String fmt(TimeOfDay t) {
      final period = t.hour >= 12 ? 'PM' : 'AM';
      final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hour:${mm} $period';
    }

    int m = start.hour * 60 + start.minute + dur.inMinutes;
    final end = TimeOfDay(hour: (m ~/ 60), minute: (m % 60));
    return '${fmt(start)} - ${fmt(end)}';
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedDay;
    final int weekday = selected.weekday; // 1..7
    final start = selected.subtract(Duration(days: weekday - 1));
    final days = List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));

    List<Widget> dayColumn(DateTime d) {
      final events = state.eventsForDay(d);
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text('${d.day}', style: TextStyle(color: _sameDay(d, selected) ? Colors.white : AppColors.slate300, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(height: 4, width: 4, decoration: BoxDecoration(color: events.isNotEmpty ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(2)))
            ],
          ),
        ),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EventChip(
              key: ValueKey(e.id),
              gradient: e.gradient,
              icon: Icons.event,
              title: e.title,
              time: _shortTime(e.start),
              location: null,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CalendarEventSheet(eventId: e.id),
              ),
            ),
          ),
      ];
    }

    return Container(
      decoration: CommonStyles.glass(radius: 16),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: dayColumn(d)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthView extends StatefulWidget {
  const _MonthView({super.key});
  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> with TickerProviderStateMixin {
  late int year;
  late int month; // 1-12
  bool expanded = true;
  bool showPicker = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    year = now.year;
    month = now.month;
  }

  List<DateTime?> _generateMonthDays(int year, int month) {
    // Sunday-start grid (7 cols), include leading nulls
    final first = DateTime(year, month, 1);
    final firstWeekday = first.weekday % 7; // Sun=0
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final list = <DateTime?>[];
    for (int i = 0; i < firstWeekday; i++) list.add(null);
    for (int d = 1; d <= daysInMonth; d++) list.add(DateTime(year, month, d));
    while (list.length % 7 != 0) list.add(null);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedDay;
    final days = _generateMonthDays(year, month);
    final today = DateTime.now();

    Widget header() {
      const monthNames = [
        'January','February','March','April','May','June','July','August','September','October','November','December'
      ];
      return InkWell(
        onTap: () => setState(() => showPicker = !showPicker),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text('${monthNames[month-1]} $year', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            Row(children: [
              Text(expanded ? 'Collapse' : 'Expand', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 6),
              Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: Colors.white70, size: 16),
            ])
          ],
        ),
      );
    }

    Widget picker() {
      final today = DateTime.now();
      return AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
                  child: DropdownButton<int>(
                    value: month,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    underline: const SizedBox.shrink(),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][i]))),
                    onChanged: (v) => setState(() => month = v!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
                  child: DropdownButton<int>(
                    value: year,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    underline: const SizedBox.shrink(),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(7, (i) => DropdownMenuItem(value: today.year - 3 + i, child: Text('${today.year - 3 + i}'))),
                    onChanged: (v) => setState(() => year = v!),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget grid() {
      return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: expanded
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final hasEvents = d != null && context.read<AppState>().eventsForDay(d).isNotEmpty;
                  final isSelected = d != null && _sameDay(d, selected);
                  final isToday = d != null && _sameDay(d, today);
                  return GestureDetector(
                    onTap: d == null ? null : () => context.read<AppState>().selectDay(d),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)]) : null,
                        color: isSelected ? null : AppColors.slate900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isToday ? Colors.white.withOpacity(0.5) : const Color(0x1AFFFFFF)),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Stack(
                        children: [
                          if (d != null)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Text('${d.day}', style: TextStyle(color: isSelected ? Colors.white : AppColors.slate300, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          if (hasEvents)
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(radius: 3, backgroundColor: AppColors.purple500),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : const SizedBox.shrink(),
      );
    }

    return Container(
      decoration: CommonStyles.glass(radius: 16),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          picker(),
          const SizedBox(height: 8),
          grid(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: Colors.white70),
              label: Text(expanded ? 'Collapse' : 'Expand', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              style: ButtonStyle(foregroundColor: MaterialStateProperty.all(Colors.white70)),
            ),
          )
        ],
      ),
    );
  }
}

class _EventTimelineCard extends StatelessWidget {
  final String title;
  final String time;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _EventTimelineCard({super.key, required this.title, required this.time, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(top: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)))),
                const Positioned(top: 8, bottom: 0, child: SizedBox(width: 2, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x33FFFFFF), Color(0x66FFFFFF)]))))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: CommonStyles.glass(radius: 12),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.calendar, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ]),
                  ),
                  const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
