import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Ultra-modern, minimal, premium background widget.
/// 
/// Apple-level precision with soft gradient blobs and subtle depth.
/// Designed for glassmorphism and clean UIs.
class LavishBackground extends StatefulWidget {
  /// Content to display on top of the background
  final Widget child;
  
  /// Use dark aesthetic (true) or light aesthetic (false)
  final bool dark;

  const LavishBackground({
    super.key,
    required this.child,
    this.dark = true,
  });

  @override
  State<LavishBackground> createState() => _LavishBackgroundState();
}

class _LavishBackgroundState extends State<LavishBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Extremely subtle, slow breathing effect (45 seconds per cycle)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.dark ? const Color(0xFF0B0B11) : const Color(0xFFFBFBFD),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Composite Layer - Cached to separate from scrolling content
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Subtle gradient overlay for depth
                _BaseGradient(dark: widget.dark),
                
                // Layer 2: Animated glow blobs
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _GlowBlobs(
                    dark: widget.dark,
                    animationValue: _controller.value,
                  ),
                ),
                
                // Layer 3: Atmospheric fog/smoke effect
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _FogEffect(
                    dark: widget.dark,
                    animationValue: _controller.value,
                  ),
                ),
                
                // Layer 4: Subtle vignette
                _Vignette(dark: widget.dark),
              ],
            ),
          ),
          
          // Layer 5: Content
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}

/// Subtle gradient overlay for depth perception
class _BaseGradient extends StatelessWidget {
  final bool dark;

  const _BaseGradient({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF0F0F18),
                  const Color(0xFF0B0B11),
                  const Color(0xFF13131D),
                ]
              : [
                  const Color(0xFFFCFCFE),
                  const Color(0xFFF8F8FC),
                  const Color(0xFFF4F4F9),
                ],
        ),
      ),
    );
  }
}

/// 2-3 positioned radial gradient glow blobs
class _GlowBlobs extends StatelessWidget {
  final bool dark;
  final double animationValue;

  const _GlowBlobs({required this.dark, required this.animationValue});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final breathOffset = animationValue * 0.04; // 4% movement range

    return Stack(
      children: [
        // Blob 1: Purple - top left
        Positioned(
          top: size.height * (-0.12 + breathOffset * math.sin(animationValue * math.pi)),
          left: size.width * (-0.18 + breathOffset * math.cos(animationValue * math.pi)),
          child: _Blob(
            size: size.width * 0.75,
            colors: dark
                ? [const Color(0x28A855F7), const Color(0x00A855F7)]
                : [const Color(0x18A855F7), const Color(0x00A855F7)],
          ),
        ),
        
        // Blob 2: Blue - bottom right
        Positioned(
          bottom: size.height * (-0.18 + breathOffset * math.cos(animationValue * math.pi * 1.3)),
          right: size.width * (-0.14 + breathOffset * math.sin(animationValue * math.pi * 1.3)),
          child: _Blob(
            size: size.width * 0.7,
            colors: dark
                ? [const Color(0x283B82F6), const Color(0x003B82F6)]
                : [const Color(0x183B82F6), const Color(0x003B82F6)],
          ),
        ),
        
        // Blob 3: Pink - center
        Positioned(
          top: size.height * (0.35 - breathOffset * math.sin(animationValue * math.pi * 0.7)),
          right: size.width * (0.15 + breathOffset * math.cos(animationValue * math.pi * 0.7)),
          child: _Blob(
            size: size.width * 0.55,
            colors: dark
                ? [const Color(0x20EC4899), const Color(0x00EC4899)]
                : [const Color(0x12EC4899), const Color(0x00EC4899)],
          ),
        ),
      ],
    );
  }
}

/// Individual radial gradient blob
class _Blob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _Blob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Subtle vignette around edges
class _Vignette extends StatelessWidget {
  final bool dark;

  const _Vignette({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: dark
              ? [
                  Colors.transparent,
                  const Color(0x12000000),
                ]
              : [
                  Colors.transparent,
                  const Color(0x08000000),
                ],
        ),
      ),
    );
  }
}

/// Atmospheric fog/smoke effect
class _FogEffect extends StatelessWidget {
  final bool dark;
  final double animationValue;

  const _FogEffect({required this.dark, required this.animationValue});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Calculate drift offsets for fog movement
    final drift1 = animationValue * 0.15; // 15% drift
    final drift2 = (1 - animationValue) * 0.12; // Opposite direction
    final drift3 = math.sin(animationValue * math.pi * 2) * 0.08;

    return Stack(
      children: [
        // Fog layer 1 - Top horizontal drift
        Positioned(
          top: size.height * (0.1 + drift1 * 0.5),
          left: size.width * (-0.3 + drift1),
          child: _FogCloud(
            width: size.width * 1.5,
            height: size.height * 0.4,
            opacity: dark ? 0.03 : 0.02,
            blur: 80,
          ),
        ),
        
        // Fog layer 2 - Middle diagonal drift
        Positioned(
          top: size.height * (0.3 - drift2 * 0.3),
          right: size.width * (-0.2 + drift2),
          child: _FogCloud(
            width: size.width * 1.3,
            height: size.height * 0.5,
            opacity: dark ? 0.04 : 0.025,
            blur: 100,
          ),
        ),
        
        // Fog layer 3 - Bottom wave
        Positioned(
          bottom: size.height * (0.0 + drift3 * 0.2),
          left: size.width * (-0.25 - drift3),
          child: _FogCloud(
            width: size.width * 1.4,
            height: size.height * 0.35,
            opacity: dark ? 0.035 : 0.02,
            blur: 90,
          ),
        ),
      ],
    );
  }
}

/// Individual fog cloud
class _FogCloud extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final double blur;

  const _FogCloud({
    required this.width,
    required this.height,
    required this.opacity,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(opacity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
