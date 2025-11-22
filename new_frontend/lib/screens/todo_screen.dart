import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/lavish_background.dart';
import '../widgets/todo_card.dart';
import '../theme/colors.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/add_item_sheet.dart';

// Todo screen mapped from `src/components/Todo.tsx`:
// - Title/subtitle with gradient accent icon
// - List of todo cards showing task data extracted from feed
// - Task can be expanded to show details (tapping opens a sheet)
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final todos = state.todos;

    return LavishBackground(
      dark: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.all(16), // p-4
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header title
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22, // text-2xl
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your AI extracted todos', style: TextStyle(color: AppColors.slate400)),
                  const SizedBox(height: 16),
                  // Tabs-style filter bar with Add button
                  _FilterTabs(),
                  const SizedBox(height: 12),

                  // Sections: Today, Upcoming, Backlog
                  Expanded(
                    child: Consumer<AppState>(builder: (context, state, _) {
                      final today = state.today;
                      final upcoming = state.upcoming;
                      final backlog = state.backlog;
                      final completed = state.completed;
                      final showCompleted = state.todoFilter == null && completed.isNotEmpty;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader('Today & Urgent', today.length, accent: const [Color(0xFFF87171), Color(0xFFF59E0B)]),
                            const SizedBox(height: 8),
                            _Collapsible(
                              initiallyExpanded: true,
                              content: _TodoList(items: today),
                            ),
                            const SizedBox(height: 16),
                            _SectionHeader('Upcoming', upcoming.length, accent: const [Color(0xFF93C5FD), Color(0xFFA855F7)]),
                            const SizedBox(height: 8),
                            _Collapsible(
                              initiallyExpanded: true,
                              content: _TodoList(items: upcoming),
                            ),
                            const SizedBox(height: 16),
                            _SectionHeader('Backlog', backlog.length, accent: const [Color(0xFF22C55E), Color(0xFF16A34A)]),
                            const SizedBox(height: 8),
                            _Collapsible(
                              initiallyExpanded: false,
                              content: _TodoList(items: backlog),
                            ),
                            if (showCompleted) ...[
                              const SizedBox(height: 16),
                              _SectionHeader('Completed', completed.length, accent: const [Color(0xFF64748B), Color(0xFF94A3B8)]),
                              const SizedBox(height: 8),
                              _Collapsible(
                                initiallyExpanded: false,
                                content: _TodoList(items: completed),
                              ),
                            ]
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openAddTodo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(),
    );
  }
}

class _TodoItemVM {
  final String title;
  final String? desc;
  final List<Color> gradient;
  final bool checked;
  _TodoItemVM(this.title, this.desc, this.gradient, this.checked);
}

// Mock visual data with Tailwind-like gradients
final _mock = <_TodoItemVM>[
  _TodoItemVM('Prepare Q4 Review deck', 'Outline key metrics and insights', [Color(0xFFA855F7), Color(0xFFEC4899)], false),
  _TodoItemVM('Book flights for conference', 'Check morning slots', [Color(0xFF3B82F6), Color(0xFF2563EB)], false),
  _TodoItemVM('Team weekly sync', 'Share agenda draft', [Color(0xFF22C55E), Color(0xFF16A34A)], true),
  _TodoItemVM('Follow-up with Alex', 'Dinner plans and gift', [Color(0xFFF59E0B), Color(0xFFD97706)], false),
  _TodoItemVM('Update project roadmap', null, [Color(0xFF06B6D4), Color(0xFF0D9488)], false),
];

class _FilterTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sel = state.todoFilter; // null => All
    Widget tab(String label, Priority? p) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: sel == p ? const Color(0x33A855F7) : const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.read<AppState>().setTodoFilter(p),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: sel == p ? Colors.white : AppColors.slate300,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
            child: Row(children: [tab('All', null), tab('High', Priority.high), tab('Medium', Priority.medium), tab('Low', Priority.low)]),
          ),
        ),
        const SizedBox(width: 8),
        // Add button
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
          child: InkWell(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddItemSheet(),
            ),
            borderRadius: BorderRadius.circular(10),
            child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<TodoItemVM> items;
  const _TodoList({required this.items});

  List<Color> _gradFor(Priority p) {
    switch (p) {
      case Priority.high:
        return const [Color(0xFFA855F7), Color(0xFFEC4899)];
      case Priority.medium:
        return const [Color(0xFF3B82F6), Color(0xFF2563EB)];
      case Priority.low:
        return const [Color(0xFF22C55E), Color(0xFF16A34A)];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No items', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final t = items[i];
        String _prioLabel() {
          switch (t.priority) {
            case Priority.high:
              return 'High';
            case Priority.medium:
              return 'Medium';
            case Priority.low:
              return 'Low';
            default:
              return 'Medium';
          }
        }
        String? _dueLabel() => t.dueLabel;
        return TodoCard(
          dismissKey: ValueKey(t.id),
          title: t.title,
          desc: t.desc,
          checked: t.completed,
          priorityGradient: _gradFor(t.priority),
          priorityLabel: _prioLabel(),
          dueLabel: _dueLabel(),
          onToggle: () => context.read<AppState>().toggleTodo(t.id),
          onDelete: () => context.read<AppState>().removeTodo(t.id),
        ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideX(begin: 0.05, end: 0);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final List<Color> accent;
  const _SectionHeader(this.title, this.count, {this.accent = const [Color(0xFFA855F7), Color(0xFFEC4899)]});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(gradient: LinearGradient(colors: accent), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: const TextStyle(color: AppColors.slate300, fontSize: 12)),
        )
      ],
    );
  }
}

class _Collapsible extends StatefulWidget {
  final bool initiallyExpanded;
  final Widget content;
  const _Collapsible({required this.initiallyExpanded, required this.content});
  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  late bool _open;
  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: widget.content,
      duration: const Duration(milliseconds: 250),
      crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
    );
  }
}
