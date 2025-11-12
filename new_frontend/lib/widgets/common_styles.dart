import 'package:flutter/material.dart';
import '../theme/colors.dart';

// Common style helpers with Tailwind mapping comments.
class CommonStyles {
  // Glass surface: maps to `bg-slate-800/50 border-white/10`
  static BoxDecoration glass({double radius = 16}) => BoxDecoration(
        color: AppColors.slate900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      );

  // Small chip radius mapping: `rounded-lg` ~ 10px
  static BorderRadius chipRadius = BorderRadius.circular(10);

  // Default padding mapping: `p-3`=12, `p-4`=16, `p-6`=24
  static const EdgeInsets p3 = EdgeInsets.all(12);
  static const EdgeInsets p4 = EdgeInsets.all(16);
  static const EdgeInsets p6 = EdgeInsets.all(24);
}
