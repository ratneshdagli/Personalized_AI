import 'package:flutter/material.dart';
import '../theme/colors.dart';

// Visual event chip mapped from Tailwind gradient badges used across Calendar/Home.
// CSS→Flutter: gradient = from-*/to-*; rounded-lg ~ 10px; p-2 = 8px.
class EventChip extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String time;
  final String? location;
  final VoidCallback? onTap; // UI-only interaction

  const EventChip({
    super.key,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.time,
    this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(10), // p-2.5 ~ 10px
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
            borderRadius: BorderRadius.circular(12), // rounded-xl
            boxShadow: [
              BoxShadow(color: gradient.last.withOpacity(0.25), blurRadius: 14, spreadRadius: 1),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIX: overflow resolved - clamp title to single line
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate200, fontSize: 12)),
                    if (location != null) ...[
                      const SizedBox(height: 2),
                      Text(location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate200, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
