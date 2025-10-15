import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../models/feed_item.dart';

class FeedCard extends StatefulWidget {
  final FeedItem feedItem;
  final VoidCallback? onTap;
  final bool showPriority;
  final bool showRelevance;

  const FeedCard({
    Key? key, 
    required this.feedItem, 
    this.onTap,
    this.showPriority = false,
    this.showRelevance = false,
  }) : super(key: key);

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  // Helper to get a color based on priority
  Color _getPriorityColor(int priority) {
    if (priority >= 3) {
      return Colors.red.shade400;
    } else if (priority >= 2) {
      return Colors.amber.shade600;
    } else {
      return Colors.green.shade400;
    }
  }

  // Helper to get an icon based on the source
  IconData _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'gmail':
        return PhosphorIconsBold.envelopeSimple;
      case 'reddit':
        return PhosphorIconsBold.redditLogo;
      case 'instagram':
        return PhosphorIconsBold.instagramLogo;
      case 'news':
        return PhosphorIconsBold.newspaper;
      case 'whatsapp':
        return PhosphorIconsBold.whatsappLogo;
      default:
        return PhosphorIconsBold.squaresFour;
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'gmail':
        return Colors.red.shade500;
      case 'reddit':
        return Colors.orange.shade500;
      case 'instagram':
        return Colors.purple.shade500;
      case 'news':
        return Colors.blue.shade500;
      case 'whatsapp':
        return Colors.green.shade500;
      default:
        return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = DateFormat.yMMMd().add_jm().format(widget.feedItem.date);
    final priorityColor = _getPriorityColor(widget.feedItem.priority);
    final sourceColor = _getSourceColor(widget.feedItem.source);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: GlassmorphicContainer(
            width: double.infinity,
            height: 180, // ensure visible height so content renders
            borderRadius: 20,
            blur: 18,
            alignment: Alignment.center,
            border: 1,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
              stops: const [0.1, 1],
            ),
            borderGradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            child: InkWell(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                  children: [
                    // Priority indicator
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with source and time
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: sourceColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getSourceIcon(widget.feedItem.source),
                                  size: 18,
                                  color: sourceColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.feedItem.source.toUpperCase(),
                                style: TextStyle(
                                  color: sourceColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Title
                          Text(
                            widget.feedItem.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          // Summary
                          Text(
                            widget.feedItem.summary,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          // Footer with priority and relevance indicators
                          if (widget.showPriority || widget.showRelevance)
                            Row(
                              children: [
                                if (widget.showPriority) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsBold.warning,
                                          size: 14,
                                          color: priorityColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(widget.feedItem.priority * 25).round()}%',
                                          style: TextStyle(
                                            color: priorityColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.showRelevance) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsBold.trendUp,
                                          size: 14,
                                          color: Colors.blue.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(widget.feedItem.relevance * 100).round()}%',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
        );
      },
    );
  }
}