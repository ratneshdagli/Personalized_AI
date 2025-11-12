import 'package:flutter/material.dart';

// Maps the Tailwind gradient: `bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950`
// and ambient colored blobs used in `App.tsx` and `Onboarding.tsx` as Stack layers.
// Adds a soft pulse loop to ambient orbs for subtle motion fidelity.
class GradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> stops;

  const GradientBackground({super.key, required this.child, this.stops = const [
    Color(0xFF0B1020), // near slate-950
    Color(0xFF0D1224), // via slate-900
    Color(0xFF0B1020), // to slate-950
  ]});

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _pulse = Tween(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.stops,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background orbs similar to HTML divs with blur and pulse
          IgnorePointer(
            ignoring: true,
            child: Stack(children: [
              Positioned(
                top: 0,
                right: MediaQuery.of(context).size.width * 0.25,
                child: _animatedOrb(const Color(0x33A855F7), 192), // purple-500/20
              ),
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.25,
                left: MediaQuery.of(context).size.width * 0.25,
                child: _animatedOrb(const Color(0x333B82F6), 192), // blue-500/20
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.5,
                right: MediaQuery.of(context).size.width * 0.33,
                child: _animatedOrb(const Color(0x33EC4899), 168), // pink-500/20
              ),
            ]),
          ),
          // Foreground content (tight constraints)
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  Widget _animatedOrb(Color color, double size) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Opacity(
          opacity: 0.9,
          child: _blurOrb(color, size),
        ),
      ),
    );
  }

  Widget _blurOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
        boxShadow: [
          BoxShadow(color: color, blurRadius: 64, spreadRadius: 8),
        ],
      ),
    );
  }
}
