import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/gradient_background.dart';

class _AmbientParticle extends StatelessWidget {
  final int seed;
  final Color color;
  const _AmbientParticle({required this.seed, required this.color});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Onboarding layout mapped from `src/components/Onboarding.tsx`:
// - Gradient ambient background orbs -> `GradientBackground`
// - Center icon with gradient container and glow -> Stack + Container
// - Title and description with spacing
// - Progress indicators and Next/Skip buttons
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// Subtle shimmer sweep over a gradient button
class _ShimmerButton extends StatefulWidget {
  final List<Color> colors; // gradient base
  final String label;
  const _ShimmerButton({required this.colors, required this.label});

  @override
  State<_ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<_ShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Sweep position 0..1
        final t = _ctrl.value;
        return ShaderMask(
          shaderCallback: (rect) {
            final width = rect.width;
            final start = (t * (width + 100)) - 100; // move from -100 to width
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x33FFFFFF), // soft shimmer core
                Color(0x00FFFFFF),
              ],
              stops: [
                (start / width).clamp(0.0, 1.0),
                ((start + 60) / width).clamp(0.0, 1.0),
                ((start + 120) / width).clamp(0.0, 1.0),
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int current = 0;
  late final AnimationController _bgCtrl;
  late final AnimationController _ring1;
  late final AnimationController _ring2;
  late final AnimationController _ring3;

  static const _slides = [
    (
      'Your AI Companion',
      'Get intelligent summaries of your messages, emails, and news - all in one place.',
      [Color(0xFF3B82F6), Color(0xFFA855F7)],
      LucideIcons.sparkles,
    ),
    (
      'Smart Automation',
      'AI automatically extracts tasks from your messages and detects calendar events.',
      [Color(0xFFA855F7), Color(0xFFEC4899)],
      LucideIcons.zap,
    ),
    (
      'Privacy First',
      'Your data stays on your device. We never collect or share your personal information.',
      [Color(0xFFEC4899), Color(0xFFF97316)],
      LucideIcons.shield,
    ),
  ];

  void _next() {
    if (current < _slides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      widget.onComplete();
    }
  }

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
    _ring1 = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _ring2 = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
    _ring3 = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bgCtrl.dispose();
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, desc, colors, icon) = _slides[current];

    return Stack(
      children: [
        // Main gradient orb
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              final t = _bgCtrl.value;
              final scale = 1 + 0.06 * math.sin(t * 6.283);
              final rot = t * 0.6;
              return Transform.rotate(
                angle: rot,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.3),
                        radius: 1.0,
                        colors: [colors.first.withOpacity(0.25), Colors.transparent],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Floating ambient particles
        for (int i = 0; i < 12; i++)
          Positioned.fill(child: _AmbientParticle(seed: i, color: colors.first.withOpacity(0.7))),
        // Animated rings
        ...[
          _ringBuilder(_ring1, 220, colors.first.withOpacity(0.10)),
          _ringBuilder(_ring2, 300, colors.last.withOpacity(0.08)),
          _ringBuilder(_ring3, 380, Colors.white.withOpacity(0.06)),
        ],
        // Foreground content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => current = i),
                    itemBuilder: (_, i) {
                      final (t, d, c, ic) = _slides[i];
                      return _OnboardingSlide(
                        title: t,
                        desc: d,
                        colors: c,
                        icon: ic,
                        isActive: i == current,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Progress indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: active ? 32 : 8,
                      decoration: BoxDecoration(
                        color: active ? colors.first : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Primary action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size.fromHeight(56),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ).merge(ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    )),
                    onPressed: _next,
                    child: _ShimmerButton(colors: colors, label: current == _slides.length - 1 ? 'Get Started' : 'Next'),
                  ).animate().fadeIn(duration: 300.ms).moveY(begin: 20, end: 0, curve: Curves.easeOut),
                ),
                const SizedBox(height: 12),
                if (current < _slides.length - 1)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.hovered) ? Colors.white : const Color(0xFF94A3B8)),
                      ),
                      onPressed: widget.onComplete,
                      child: const Text('Skip'),
                    ).animate().fadeIn(duration: 300.ms).moveY(begin: 20, end: 0, curve: Curves.easeOut),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ringBuilder(AnimationController ctrl, double size, Color color) {
    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (context, _) {
            final t = ctrl.value;
            final scale = 0.9 + 0.2 * math.sin(t * 6.283);
            final opacity = 0.6 + 0.3 * math.sin((t + 0.25) * 6.283);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(size),
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final String title;
  final String desc;
  final List<Color> colors;
  final IconData icon;
  final bool isActive;
  const _OnboardingSlide({required this.title, required this.desc, required this.colors, required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Central icon + particles + orbiters
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Particle burst (8 dots)
              for (int i = 0; i < 8; i++)
                _particle(colors, i * 45.0)
                    .animate(onPlay: (c) => c.repeat(period: 1200.ms))
                    .fadeIn(duration: 300.ms)
                    .then(delay: (i * 40).ms)
                    .move(begin: Offset.zero, end: Offset(28 * _cos(i), 28 * _sin(i)), curve: Curves.easeOut)
                    .fadeOut(duration: 300.ms),
              // Glow pulse behind icon
              Animate(
                onPlay: (c) => c.repeat(reverse: true, period: 1600.ms),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [colors.first.withOpacity(0.25), Colors.transparent]),
                  ),
                ),
                effects: [ScaleEffect(begin: const Offset(0.9, 0.9), end: const Offset(1.05, 1.05), duration: 800.ms), FadeEffect(begin: 0.6, end: 1.0, duration: 800.ms)],
              ),
              // Orbiting dots (3)
              _orbiter(colors.first, radius: 44, seconds: 6),
              _orbiter(colors.last, radius: 64, seconds: 8),
              _orbiter(Colors.white70, radius: 84, seconds: 10),
              // Icon container
              Container(
                padding: const EdgeInsets.all(32), // p-8
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24), // rounded-3xl
                  boxShadow: [BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Icon(icon, color: Colors.white, size: 64),
              ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut).rotate(begin: -3.1415, end: 0, duration: 450.ms, curve: Curves.easeOut),
            ],
          ),
        ),
        const SizedBox(height: 32), // mt-8
        // Title letter-by-letter
        _animatedText(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white), perWord: false, gradientMask: true),
        const SizedBox(height: 24), // space-y-6
        // Description word-by-word
        _animatedText(desc, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14), perWord: true),
      ],
    );
  }

  Widget _animatedText(String text, {required TextStyle style, bool perWord = false, bool gradientMask = false}) {
    final parts = perWord ? text.split(' ') : text.split('');
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final w = Text(perWord ? '${parts[i]} ' : parts[i], style: style)
          .animate()
          .fadeIn(duration: 220.ms, delay: (i * 22).ms)
          .moveY(begin: 6, end: 0, curve: Curves.easeOut);
      children.add(gradientMask
          ? ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFE9D5FF), Colors.white], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(r),
              child: w,
            )
          : w);
    }
    return Wrap(alignment: WrapAlignment.center, children: children);
  }

  Widget _particle(List<Color> grad, double angleDeg) {
    return Transform.translate(
      offset: Offset.zero,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _orbiter(Color color, {required double radius, required int seconds}) {
    return Animate(
      onPlay: (c) => c.repeat(period: Duration(seconds: seconds)),
      effects: [RotateEffect(begin: 0, end: 6.283, duration: Duration(seconds: seconds))],
      child: Transform.translate(
        offset: Offset(radius, 0),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(6))),
      ),
    );
  }

  double _sin(int i) => MathHelper.sinDeg(i * 45);
  double _cos(int i) => MathHelper.cosDeg(i * 45);
}

class MathHelper {
  static double sinDeg(double deg) => math.sin(deg * 3.1415926535 / 180);
  static double cosDeg(double deg) => math.cos(deg * 3.1415926535 / 180);
}
