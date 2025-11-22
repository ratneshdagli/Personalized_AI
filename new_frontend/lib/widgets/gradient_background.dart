import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Revolutionary ultra-modern background with aurora waves, holographic shimmer,
/// floating geometric fragments, and liquid mesh deformation.
/// A truly unique aesthetic that pushes the boundaries of mobile UI design.
class GradientBackground extends StatefulWidget {
  final Widget child;
  final bool enableAuroraWaves;
  final bool enableHolographicShimmer;
  final bool enableFloatingFragments;
  final bool enableLiquidMesh;

  const GradientBackground({
    super.key,
    required this.child,
    this.enableAuroraWaves = true,
    this.enableHolographicShimmer = true,
    this.enableFloatingFragments = true,
    this.enableLiquidMesh = true,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _auroraController;
  late final AnimationController _holographicController;
  late final AnimationController _fragmentsController;
  late final AnimationController _liquidController;
  
  late final List<_GeometricFragment> _fragments;

  @override
  void initState() {
    super.initState();
    
    // Aurora wave animation (slow, organic)
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    
    // Holographic shimmer (medium, iridescent)
    _holographicController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    
    // Floating fragments (slow, geometric)
    _fragmentsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    
    // Liquid mesh deformation (very slow, smooth)
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat(reverse: true);

    // Generate geometric fragments
    _fragments = List.generate(
      8,
      (index) => _GeometricFragment(
        index: index,
        seed: math.Random().nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _holographicController.dispose();
    _fragmentsController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: _buildBaseGradient(isDark),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Aurora waves layer (flowing gradient waves)
          if (widget.enableAuroraWaves)
            AnimatedBuilder(
              animation: _auroraController,
              builder: (context, child) => CustomPaint(
                painter: _AuroraWavesPainter(
                  progress: _auroraController.value,
                  isDark: isDark,
                ),
              ),
            ),
          
          // Liquid mesh deformation (organic blob morphing)
          if (widget.enableLiquidMesh)
            AnimatedBuilder(
              animation: _liquidController,
              builder: (context, child) => CustomPaint(
                painter: _LiquidMeshPainter(
                  progress: _liquidController.value,
                  isDark: isDark,
                ),
              ),
            ),
          
          // Holographic shimmer overlay (iridescent color shift)
          if (widget.enableHolographicShimmer)
            AnimatedBuilder(
              animation: _holographicController,
              builder: (context, child) => _buildHolographicShimmer(
                isDark,
                _holographicController.value,
              ),
            ),
          
          // Floating geometric fragments
          if (widget.enableFloatingFragments)
            AnimatedBuilder(
              animation: _fragmentsController,
              builder: (context, child) => _buildFloatingFragments(
                isDark,
                _fragmentsController.value,
              ),
            ),
          
          // Subtle depth grid (cyberpunk-inspired)
          _buildDepthGrid(isDark),
          
          // Edge glow effect
          _buildEdgeGlow(isDark),
          
          // Content
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  /// Base gradient foundation - deep, rich colors
  LinearGradient _buildBaseGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.3, 0.6, 1.0],
      colors: isDark
          ? [
              const Color(0xFF0A0A1F), // Deep space blue
              const Color(0xFF0F0820), // Deep purple-black
              const Color(0xFF120816), // Rich dark purple
              const Color(0xFF08070F), // Almost black
            ]
          : [
              const Color(0xFFFCFCFD), // Pure white
              const Color(0xFFF5F7FA), // Soft blue-white
              const Color(0xFFF0F4F8), // Cool white
              const Color(0xFFE8EDF5), // Light steel blue
            ],
    );
  }

  /// Holographic shimmer overlay with rainbow iridescence
  Widget _buildHolographicShimmer(bool isDark, double progress) {
    final screenWidth = MediaQuery.of(context).size.width;
    final angle = progress * 2 * math.pi;
    
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(math.cos(angle), math.sin(angle)),
            end: Alignment(-math.cos(angle), -math.sin(angle)),
            colors: isDark
                ? [
                    Colors.transparent,
                    const Color(0x0AA855F7), // Purple
                    const Color(0x0A3B82F6), // Blue
                    const Color(0x0AEC4899), // Pink
                    const Color(0x0AF59E0B), // Amber
                    const Color(0x0A10B981), // Green
                    Colors.transparent,
                  ]
                : [
                    Colors.transparent,
                    const Color(0x088B5CF6), // Light purple
                    const Color(0x0860A5FA), // Light blue
                    const Color(0x08F472B6), // Light pink
                    const Color(0x08FCD34D), // Light amber
                    Colors.transparent,
                  ],
            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0],
          ),
        ),
      ),
    );
  }

  /// Floating geometric fragments with 3D depth
  Widget _buildFloatingFragments(bool isDark, double progress) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return IgnorePointer(
      child: Stack(
        children: _fragments.map((fragment) {
          final pos = fragment.calculatePosition(
            progress,
            screenWidth,
            screenHeight,
          );
          final rotation = fragment.calculateRotation(progress);
          final opacity = fragment.calculateOpacity(progress);
          final scale = fragment.calculateScale(progress);

          return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: CustomPaint(
                    size: Size(fragment.size, fragment.size),
                    painter: _GeometricFragmentPainter(
                      color: isDark
                          ? fragment.color.withOpacity(0.15)
                          : fragment.color.withOpacity(0.08),
                      shape: fragment.shape,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Subtle depth grid for layering
  Widget _buildDepthGrid(bool isDark) {
    return Opacity(
      opacity: isDark ? 0.03 : 0.02,
      child: CustomPaint(
        painter: _DepthGridPainter(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  /// Edge glow for premium feel
  Widget _buildEdgeGlow(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0x15A855F7), // Purple glow top
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0x153B82F6), // Blue glow bottom
                ]
              : [
                  const Color(0x088B5CF6),
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0x0860A5FA),
                ],
          stops: const [0.0, 0.1, 0.9, 1.0],
        ),
      ),
    );
  }
}

/// Aurora waves painter - flowing, organic gradient waves
class _AuroraWavesPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AuroraWavesPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    // Draw 3 flowing wave layers
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final waveHeight = size.height * 0.3;
      final offset = progress * 2 * math.pi + i * 2;
      
      path.moveTo(0, size.height * 0.5);
      
      for (var x = 0.0; x <= size.width; x += 5) {
        final y = size.height * (0.3 + i * 0.15) +
            math.sin(x / 100 + offset) * waveHeight * 0.3 +
            math.cos(x / 150 + offset * 0.7) * waveHeight * 0.2;
        path.lineTo(x, y);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final colors = isDark
          ? [
              const Color(0x20A855F7), // Purple
              const Color(0x203B82F6), // Blue
              const Color(0x20EC4899), // Pink
            ]
          : [
              const Color(0x108B5CF6),
              const Color(0x1060A5FA),
              const Color(0x10F472B6),
            ];

      paint.shader = ui.Gradient.linear(
        Offset(0, size.height * 0.3),
        Offset(0, size.height),
        [colors[i].withOpacity(0.3), Colors.transparent],
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraWavesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Liquid mesh painter - organic blob morphing
class _LiquidMeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _LiquidMeshPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Create 4 morphing blobs
    final blobs = [
      _createBlob(size, progress, 0, 0.2, 0.15),
      _createBlob(size, progress, 1, 0.75, 0.25),
      _createBlob(size, progress, 2, 0.3, 0.7),
      _createBlob(size, progress, 3, 0.85, 0.85),
    ];

    final colors = isDark
        ? [
            const Color(0x30A855F7),
            const Color(0x303B82F6),
            const Color(0x30EC4899),
            const Color(0x30F59E0B),
          ]
        : [
            const Color(0x158B5CF6),
            const Color(0x1560A5FA),
            const Color(0x15F472B6),
            const Color(0x15FCD34D),
          ];

    for (var i = 0; i < blobs.length; i++) {
      paint.color = colors[i];
      canvas.drawPath(blobs[i], paint);
    }
  }

  Path _createBlob(Size size, double progress, int index, double xRatio, double yRatio) {
    final centerX = size.width * xRatio;
    final centerY = size.height * yRatio;
    final radius = size.width * 0.25;
    final offset = progress * 2 * math.pi + index;

    final path = Path();
    const segments = 8;
    
    for (var i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      final distortion = 1 + 0.3 * math.sin(angle * 3 + offset);
      final r = radius * distortion;
      
      final x = centerX + r * math.cos(angle);
      final y = centerY + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LiquidMeshPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Depth grid painter
class _DepthGridPainter extends CustomPainter {
  final Color color;

  _DepthGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;

    // Vertical lines
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Geometric fragment data class
class _GeometricFragment {
  final int index;
  final double seed;
  final double size;
  final double speed;
  final Color color;
  final FragmentShape shape;

  _GeometricFragment({
    required this.index,
    required this.seed,
  })  : size = 40 + math.Random(index).nextDouble() * 80,
        speed = 0.2 + math.Random(index * 2).nextDouble() * 0.3,
        color = _randomColor(index),
        shape = FragmentShape.values[index % FragmentShape.values.length];

  static Color _randomColor(int seed) {
    final colors = [
      const Color(0xFFA855F7), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFF06B6D4), // Cyan
    ];
    return colors[seed % colors.length];
  }

  Offset calculatePosition(double progress, double width, double height) {
    final phase = (progress * speed + seed) * 2 * math.pi;
    final baseX = (index / 8) * width;
    final baseY = (seed * 0.8) * height;

    final amplitude = 120.0;
    final x = baseX + amplitude * math.cos(phase * 0.5);
    final y = baseY + amplitude * math.sin(phase * 0.3) * 0.7;

    return Offset(x % width, y % height);
  }

  double calculateRotation(double progress) {
    return (progress * speed + seed) * 2 * math.pi * 0.5;
  }

  double calculateOpacity(double progress) {
    final phase = (progress * speed + seed) * 2 * math.pi;
    return 0.3 + 0.4 * (math.sin(phase) * 0.5 + 0.5);
  }

  double calculateScale(double progress) {
    final phase = (progress * speed + seed) * 2 * math.pi;
    return 0.7 + 0.3 * (math.cos(phase * 0.7) * 0.5 + 0.5);
  }
}

enum FragmentShape { triangle, square, hexagon, pentagon, star, diamond }

/// Geometric fragment painter
class _GeometricFragmentPainter extends CustomPainter {
  final Color color;
  final FragmentShape shape;

  _GeometricFragmentPainter({required this.color, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    Path path;
    switch (shape) {
      case FragmentShape.triangle:
        path = _createPolygon(center, radius, 3);
        break;
      case FragmentShape.square:
        path = _createPolygon(center, radius, 4);
        break;
      case FragmentShape.pentagon:
        path = _createPolygon(center, radius, 5);
        break;
      case FragmentShape.hexagon:
        path = _createPolygon(center, radius, 6);
        break;
      case FragmentShape.star:
        path = _createStar(center, radius);
        break;
      case FragmentShape.diamond:
        path = _createDiamond(center, radius);
        break;
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  Path _createPolygon(Offset center, double radius, int sides) {
    final path = Path();
    for (var i = 0; i <= sides; i++) {
      final angle = (i / sides) * 2 * math.pi - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _createStar(Offset center, double radius) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
      final r = (i % 2 == 0) ? radius : radius * 0.5;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _createDiamond(Offset center, double radius) {
    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.lineTo(center.dx + radius * 0.6, center.dy);
    path.lineTo(center.dx, center.dy + radius);
    path.lineTo(center.dx - radius * 0.6, center.dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
