// Enhanced loading widget with animations
import 'package:flutter/material.dart';

class LoadingWidget extends StatefulWidget {
  final String? message;
  final double size;
  
  const LoadingWidget({
    super.key,
    this.message,
    this.size = 50.0,
  });

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ],
                    stops: [
                      _animation.value - 0.3,
                      _animation.value,
                      _animation.value + 0.3,
                    ].map((e) => e.clamp(0.0, 1.0)).toList(),
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: widget.size * 0.5,
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 200,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300]?.withOpacity(0.3 + _animation.value * 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
