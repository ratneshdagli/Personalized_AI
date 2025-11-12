import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/common_styles.dart';

// Visual-only horizontal date strip with selectable chips.
// CSS→Flutter: `gap-2` -> SizedBox(8), `rounded-lg` -> 10px, selected -> gradient border/fill.
class DateStrip extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const DateStrip({super.key, required this.dates, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = dates[i];
          final isSelected = _sameDay(d, selected);
          final day = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.weekday % 7];
          final month = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.month - 1];
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // compact to avoid overflow on desktop
              constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
              decoration: isSelected
                  ? BoxDecoration(
                      borderRadius: CommonStyles.chipRadius,
                      border: Border.all(color: AppColors.purple500.withOpacity(0.5)),
                      color: AppColors.slate900.withOpacity(0.6),
                    )
                  : CommonStyles.glass(radius: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(day, style: TextStyle(color: isSelected ? AppColors.slate200 : AppColors.slate400, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text('${d.day}', style: TextStyle(color: isSelected ? Colors.white : AppColors.slate300, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(month, style: TextStyle(color: isSelected ? AppColors.slate400 : AppColors.slate500, fontSize: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
