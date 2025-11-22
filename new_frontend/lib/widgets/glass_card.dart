import 'dart:ui';
import 'package:flutter/material.dart';

// Simple glassmorphism card to mirror Tailwind classes like
// `bg-slate-800/50 border-white/10 backdrop-blur-xl rounded-2xl`
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final BoxBorder? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius is BorderRadius ? borderRadius as BorderRadius : BorderRadius.circular(16);
    // RepaintBoundary is crucial here to cache the expensive blur effect
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          // Reduced blur slightly (12->10) for performance without losing the look
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? const Color(0x801E293B), // slate-800/50
              borderRadius: borderRadius,
              border: border ?? Border.all(color: const Color(0x1AFFFFFF)), // white/10
            ),
          padding: padding,
          child: child,
        ),
      ),
    ),
  );
}
}
