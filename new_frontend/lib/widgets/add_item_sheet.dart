import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

// Visual Add sheet used from Home and ToDo
// CSS→Flutter: px-4 py-4 (16), rounded-2xl (20), glass bg, Tailwind chips
class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key});
  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  String kind = 'Hub Item'; // 'Hub Item' | 'ToDo'
  String title = '';
  String description = '';
  String hub = 'Urgent & Priority';
  Priority priority = Priority.medium;
  DateTime? due;
  IconData icon = Icons.auto_awesome;
  List<Color> hubGradient = const [Color(0xFFA855F7), Color(0xFFEC4899)];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hubs = state.hubs;

    return _GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // Kind tabs
          Row(
            children: [
              for (final k in const ['Hub Item', 'ToDo'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(k),
                    selected: kind == k,
                    onSelected: (_) => setState(() => kind = k),
                    selectedColor: const Color(0x33A855F7),
                    backgroundColor: const Color(0x1AFFFFFF),
                    labelStyle: TextStyle(color: kind == k ? Colors.white : AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Title *'),
            onChanged: (v) => title = v,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(hintText: 'Description'),
            onChanged: (v) => description = v,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          // Hub select
          if (kind == 'Hub Item') ...[
            const Text('Hub', style: TextStyle(color: AppColors.slate300, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in hubs)
                  ChoiceChip(
                    label: Text(h.name),
                    selected: hub == h.name,
                    onSelected: (_) => setState(() => hub = h.name),
                    selectedColor: const Color(0x33A855F7),
                    backgroundColor: const Color(0x1AFFFFFF),
                    labelStyle: TextStyle(color: hub == h ? Colors.white : AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Icon', style: TextStyle(color: AppColors.slate300, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final ic in [Icons.error_outline, Icons.forum, Icons.work_outline, Icons.event, Icons.attach_money, Icons.trending_up, Icons.favorite_border, Icons.auto_awesome])
                  ChoiceChip(
                    label: Icon(ic, size: 16, color: Colors.white),
                    selected: icon == ic,
                    onSelected: (_) => setState(() => icon = ic),
                    selectedColor: const Color(0x33FFFFFF),
                    backgroundColor: const Color(0x1AFFFFFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Gradient', style: TextStyle(color: AppColors.slate300, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _gradChip([const Color(0xFFA855F7), const Color(0xFFEC4899)]),
                _gradChip([const Color(0xFF3B82F6), const Color(0xFF2563EB)]),
                _gradChip([const Color(0xFF22C55E), const Color(0xFF16A34A)]),
                _gradChip([const Color(0xFFF59E0B), const Color(0xFFD97706)]),
              ],
            ),
          ],
          if (kind == 'ToDo') ...[
            const Text('Priority', style: TextStyle(color: AppColors.slate300, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _prioChip(Priority.low),
                _prioChip(Priority.medium),
                _prioChip(Priority.high),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Date',
                    value: due == null ? 'Select' : _fmtDate(due!),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: due ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (picked != null) setState(() => due = picked);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Validation
                    if (title.trim().isEmpty) return; // keep UI-only simple
                    final id = DateTime.now().millisecondsSinceEpoch.toString();
                    if (kind == 'Hub Item') {
                      context.read<AppState>().addHubItem(
                            HubItem(id, hub, title.trim(), description.isEmpty ? 'Just now' : description, hubGradient, icon),
                          );
                    } else {
                      context.read<AppState>().addTodo(
                            TodoItemVM(
                              id: id,
                              title: title.trim(),
                              desc: description.isEmpty ? null : description,
                              priority: priority,
                              due: due,
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _prioChip(Priority p) {
    final selected = priority == p;
    final label = p.name[0].toUpperCase() + p.name.substring(1);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => priority = p),
      selectedColor: const Color(0x33A855F7),
      backgroundColor: const Color(0x1AFFFFFF),
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.slate300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _gradChip(List<Color> g) {
    final selected = hubGradient[0].value == g[0].value && hubGradient[1].value == g[1].value;
    return ChoiceChip(
      label: const Text(''),
      selected: selected,
      selectedColor: const Color(0x33FFFFFF),
      backgroundColor: const Color(0x1AFFFFFF),
      onSelected: (_) => setState(() => hubGradient = g),
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

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

// FIX: add missing _DateTile used in ToDo date picker
class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool selected;

  const _DateTile({
    required this.label,
    required this.value,
    this.onTap,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Visual mapping: glass surface + subtle border similar to CommonStyles.glass
    final bg = selected ? AppColors.slate800.withOpacity(0.65) : AppColors.slate900.withOpacity(0.45);
    final border = selected ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left column: label + value
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.slate300,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Right: chevron/calendar icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 16,
                color: selected ? Colors.white : AppColors.slate300,
              ),
            ),
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
