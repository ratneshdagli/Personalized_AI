// Enhanced task card with animations and better visual design
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onSyncToCalendar;
  final bool showPriority;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.onSyncToCalendar,
    this.showPriority = false,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
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

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return Colors.red.shade400;
      case 2:
        return Colors.amber.shade600;
      case 1:
        return Colors.green.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _getPriorityIcon(int priority) {
    switch (priority) {
      case 3:
        return Icons.keyboard_arrow_up;
      case 2:
        return Icons.remove;
      case 1:
        return Icons.keyboard_arrow_down;
      default:
        return Icons.circle;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 3:
        return 'HIGH';
      case 2:
        return 'MEDIUM';
      case 1:
        return 'LOW';
      default:
        return 'NORMAL';
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0) {
      return 'In $difference days';
    } else {
      return '${difference.abs()} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(widget.task.priority);
    final isCompleted = widget.task.isCompleted;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            elevation: _elevationAnimation.value,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      priorityColor.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
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
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Completion checkbox
                          GestureDetector(
                            onTap: widget.onToggle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted 
                                    ? Colors.green.shade500 
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted 
                                      ? Colors.green.shade500 
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Task content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Task title
                                Text(
                                  widget.task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: isCompleted 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                    color: isCompleted 
                                        ? Colors.grey.shade500 
                                        : null,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Task description
                                if (widget.task.text.isNotEmpty)
                                  Text(
                                    widget.task.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isCompleted 
                                          ? Colors.grey.shade400 
                                          : Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                // Task metadata
                                Row(
                                  children: [
                                    // Priority indicator
                                    if (widget.showPriority)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getPriorityIcon(widget.task.priority),
                                              size: 14,
                                              color: priorityColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getPriorityText(widget.task.priority),
                                              style: TextStyle(
                                                color: priorityColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const Spacer(),
                                    // Due date
                                    if (widget.task.dueDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatDueDate(widget.task.dueDate!),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sync to calendar button
                              if (widget.onSyncToCalendar != null)
                                IconButton(
                                  onPressed: widget.onSyncToCalendar,
                                  icon: Icon(
                                    Icons.event,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                  tooltip: 'Sync to Calendar',
                                ),
                              // Delete button
                              if (widget.onDelete != null)
                                IconButton(
                                  onPressed: widget.onDelete,
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete Task',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
