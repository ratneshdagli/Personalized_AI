import 'package:flutter/material.dart';

// Bottom navigation styled to match Tailwind-styled BottomNav.tsx
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x990f172a).withOpacity(0.7), // slate-900/70
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(context, 0, Icons.grid_view_rounded, 'Hubs'),
              _item(context, 1, Icons.checklist_rounded, 'Todo'),
              _item(context, 2, Icons.calendar_month_rounded, 'Calendar'),
              _item(context, 3, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final active = currentIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x33A855F7) : Colors.transparent, // purple-500/20
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: active ? const Color(0xFFc084fc) : const Color(0xFF94a3b8)),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: active ? const Color(0xFFc084fc) : const Color(0xFF94a3b8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
