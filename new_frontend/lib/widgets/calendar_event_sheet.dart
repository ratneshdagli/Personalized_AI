import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

// Calendar event sheet matching Figma design with source icons and AI badges
class CalendarEventSheet extends StatefulWidget {
  final String? eventId;
  final TimeOfDay? initialStart;
  const CalendarEventSheet({super.key, this.eventId, this.initialStart});

  @override
  State<CalendarEventSheet> createState() => _CalendarEventSheetState();
}

const Map<EventSource, IconData> _sourceIcons = {
  EventSource.email: Icons.mail_outline,
  EventSource.whatsapp: Icons.chat_bubble_outline,
  EventSource.messages: Icons.message_outlined,
  EventSource.phone: Icons.phone_outlined,
  EventSource.manual: Icons.edit_outlined,
};

const Map<EventSource, String> _sourceLabels = {
  EventSource.email: 'Email',
  EventSource.whatsapp: 'WhatsApp',
  EventSource.messages: 'Messages',
  EventSource.phone: 'Phone',
  EventSource.manual: 'Manual',
};

class _CalendarEventSheetState extends State<CalendarEventSheet> {
  String title = '';
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  Duration duration = const Duration(minutes: 60);
  List<Color> gradient = const [Color(0xFF3B82F6), Color(0xFF2563EB)];
  String? location;
  EventSource source = EventSource.manual;
  bool isAIDetected = false;
  bool hasEndTime = false;
  TimeOfDay? end;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Prefill from existing event if editing
    if (widget.eventId != null) {
      final ev = state.getEvent(widget.eventId!);
      if (ev != null) {
        title = title.isEmpty ? ev.title : title;
        start = widget.initialStart ?? ev.start;
        duration = duration.inMinutes == 60 ? ev.duration : duration;
        gradient = gradient == const [Color(0xFF3B82F6), Color(0xFF2563EB)] ? ev.gradient : gradient;
        location ??= ev.location;
        source = ev.source;
        isAIDetected = ev.isAIDetected;
      }
    } else if (widget.initialStart != null) {
      start = widget.initialStart!;
    }
    return _GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.eventId != null
                        ? const [Color(0xFF3B82F6), Color(0xFF06B6D4)]
                        : const [Color(0xFFA855F7), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x33A855F7), blurRadius: 12)],
                ),
                child: Icon(
                  widget.eventId != null ? Icons.calendar_today : Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.eventId != null ? 'Edit Event' : 'Add Event',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Event Title', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter event title...',
              filled: true,
              fillColor: const Color(0x800F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (v) => setState(() => title = v),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('Source', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<EventSource>(
            value: source,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x800F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF0F172A),
            style: const TextStyle(color: Colors.white),
            items: EventSource.values.map((s) {
              return DropdownMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(_sourceIcons[s], size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(_sourceLabels[s]!),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => source = v!),
          ),
          const SizedBox(height: 12),
          // Custom Start time picker
          _TimePickerInline(
            label: 'Start Time',
            initial: start,
            onChanged: (t) => setState(() => start = t),
          ),
          const SizedBox(height: 12),
          // Add End Time toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add End Time', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
              Switch(
                value: hasEndTime,
                onChanged: (v) => setState(() {
                  hasEndTime = v;
                  end ??= TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
                }),
                activeColor: const Color(0xFFA855F7),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: hasEndTime ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TimePickerInline(
                label: 'End Time',
                initial: end ?? TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
                onChanged: (t) => setState(() => end = t),
              ).animate().fadeIn(duration: 200.ms).moveY(begin: 6, end: 0, curve: Curves.easeOut),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Location (Optional)', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter location...',
              filled: true,
              fillColor: const Color(0x800F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (v) => setState(() => location = v.isEmpty ? null : v),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('Category', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _gradChip([const Color(0xFF3B82F6), const Color(0xFF2563EB)]),
              _gradChip([const Color(0xFFA855F7), const Color(0xFF7C3AED)]),
              _gradChip([const Color(0xFF22C55E), const Color(0xFF16A34A)]),
              _gradChip([const Color(0xFFF59E0B), const Color(0xFFD97706)]),
              _gradChip([const Color(0xFFEC4899), const Color(0xFFE11D48)]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // If end time is enabled, compute duration from start->end
                    if (hasEndTime && end != null) {
                      final startMinutes = start.hour * 60 + start.minute;
                      final endMinutes = end!.hour * 60 + end!.minute;
                      int diff = endMinutes - startMinutes;
                      if (diff <= 0) diff += 24 * 60; // wrap to next day if needed
                      duration = Duration(minutes: diff);
                    }
                    if (widget.eventId != null) {
                      context.read<AppState>().updateEvent(
                            widget.eventId!,
                            title: title.isEmpty ? null : title,
                            start: start,
                            duration: duration,
                            gradient: gradient,
                            location: location,
                          );
                    } else {
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      context.read<AppState>().addEvent(
                            CalendarEventVM(
                              id: id,
                              title: title.isEmpty ? 'New Event' : title,
                              date: state.selectedDay,
                              start: start,
                              duration: duration,
                              gradient: gradient,
                              location: location,
                              source: source,
                              isAIDetected: isAIDetected,
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: Text(widget.eventId != null ? 'Save' : 'Add Event'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              if (widget.eventId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    context.read<AppState>().removeEvent(widget.eventId!);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.white70),
                )
              ]
            ],
          )
        ],
      ),
    );
  }

  String _fmtTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hour:$mm $period';
  }

  Widget _gradChip(List<Color> g) {
    final selected = gradient[0].value == g[0].value && gradient[1].value == g[1].value;
    return ChoiceChip(
      label: const Text(''),
      selected: selected,
      selectedColor: const Color(0x33FFFFFF),
      backgroundColor: const Color(0x1AFFFFFF),
      onSelected: (_) => setState(() => gradient = g),
      avatar: Container(
        width: 20,
        height: 12,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _TimePickerInline extends StatefulWidget {
  final String label;
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;
  const _TimePickerInline({required this.label, required this.initial, required this.onChanged});

  @override
  State<_TimePickerInline> createState() => _TimePickerInlineState();
}

class _TimePickerInlineState extends State<_TimePickerInline> {
  late int _hour12; // 1..12
  late int _minute; // 0..59
  late String _period; // AM/PM

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _hour12 = (h % 12 == 0) ? 12 : (h % 12);
    _minute = widget.initial.minute;
    _period = h >= 12 ? 'PM' : 'AM';
  }

  void _emit() {
    int h24 = _hour12 % 12;
    if (_period == 'PM') h24 += 12;
    widget.onChanged(TimeOfDay(hour: h24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final baseDeco = BoxDecoration(
      color: const Color(0x800F172A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x1AFFFFFF)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            // Hour
            Expanded(
              child: Container(
                decoration: baseDeco,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  value: _hour12,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0F172A),
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: List.generate(12, (i) => i + 1)
                      .map((h) => DropdownMenuItem(value: h, child: Text(h.toString())))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _hour12 = v ?? _hour12;
                    _emit();
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Minute
            Expanded(
              child: Container(
                decoration: baseDeco,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  value: _minute,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0F172A),
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: List.generate(60, (i) => i)
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _minute = v ?? _minute;
                    _emit();
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Period
            Expanded(
              child: Container(
                decoration: baseDeco,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _period,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0F172A),
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: const [DropdownMenuItem(value: 'AM', child: Text('AM')), DropdownMenuItem(value: 'PM', child: Text('PM'))],
                  onChanged: (v) => setState(() {
                    _period = v ?? _period;
                    _emit();
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x800F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: child,
    );
  }
}
