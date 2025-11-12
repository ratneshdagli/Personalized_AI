import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/colors.dart';
import 'common_styles.dart';

// Visual-only ToDo card mapped from Tailwind glass cards with gradient priority chip.
// CSS→Flutter:
// - container: bg-slate-800/50 + border-white/10 -> CommonStyles.glass
// - padding p-4 = 16px, rounded-2xl = 20px
// - priority chip: from-*/to-* gradient, rounded-lg ~ 10px
class TodoCard extends StatelessWidget {
  final String title;
  final String? desc;
  final List<Color> priorityGradient; // e.g., [purple-500, pink-500]
  final bool checked;
  final String? dueLabel; // e.g., "Today" or date string
  final String? priorityLabel; // 'High' | 'Medium' | 'Low'
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final Key? dismissKey;

  const TodoCard({
    super.key,
    required this.title,
    this.desc,
    required this.priorityGradient,
    this.checked = false,
    this.dueLabel,
    this.priorityLabel,
    this.onToggle,
    this.onDelete,
    this.dismissKey,
  });

  @override
  Widget build(BuildContext context) {
    // Utilities for badges
    Color _withAlpha(Color c, int alpha) => Color.fromARGB(alpha, c.red, c.green, c.blue);
    final primary = priorityGradient.first;

    Widget priorityBadge() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _withAlpha(primary, 0x33), // ~20% opacity
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _withAlpha(primary, 0x4D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 12, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                (priorityLabel ?? 'Priority'),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    Widget? dueBadge() => dueLabel == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x263B82F6), // blue-500/15
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x334B5563)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.calendar, size: 12, color: Colors.white),
                const SizedBox(width: 6),
                Text(dueLabel!, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          );

    final card = Container(
      decoration: CommonStyles.glass(radius: 20),
      padding: const EdgeInsets.all(16), // p-4
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              width: 22,
              height: 22,
              transform: Matrix4.identity()..scale(checked ? 0.96 : 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFC084FC)), // purple-400
                color: checked ? const Color(0x33C084FC) : Colors.transparent,
              ),
              child: checked ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                if (desc != null && desc!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    priorityBadge(),
                    if (dueBadge() != null) dueBadge()!,
                  ],
                ),
              ],
            ),
          ),
          // Delete icon
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 18, color: Color(0xFFF87171)),
              splashRadius: 18,
            ),
        ],
      ),
    );
    if (dismissKey == null) return card;
    return Dismissible(
      key: dismissKey!,
      background: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: const Icon(LucideIcons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          // complete
          if (onToggle != null) onToggle!();
        } else if (dir == DismissDirection.endToStart) {
          if (onDelete != null) onDelete!();
        }
      },
      child: card,
    );
  }
}
