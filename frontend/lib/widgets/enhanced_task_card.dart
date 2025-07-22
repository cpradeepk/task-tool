import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/time_tracking_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class EnhancedTaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final Function(Task)? onStatusChanged;
  final Function(Task)? onPriorityChanged;
  final bool showTimeTracking;
  final bool showQuickActions;

  const EnhancedTaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.onStatusChanged,
    this.onPriorityChanged,
    this.showTimeTracking = true,
    this.showQuickActions = true,
  }) : super(key: key);

  @override
  State<EnhancedTaskCard> createState() => _EnhancedTaskCardState();
}

class _EnhancedTaskCardState extends State<EnhancedTaskCard> {
  final TimeTrackingService _timeTrackingService = TimeTrackingService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  
  ActiveTimer? _activeTimer;
  StreamSubscription? _timerSubscription;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _setupTimerListener();
    _checkActiveTimer();
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }

  void _setupTimerListener() {
    _timerSubscription = _timeTrackingService.activeTimerStream.listen((timer) {
      setState(() {
        _activeTimer = timer;
        _isTimerRunning = timer?.taskId == widget.task.id;
      });
    });
  }

  void _checkActiveTimer() {
    final activeTimer = _timeTrackingService.activeTimer;
    if (activeTimer?.taskId == widget.task.id) {
      setState(() {
        _activeTimer = activeTimer;
        _isTimerRunning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildTitle(),
              if (widget.task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                _buildDescription(),
              ],
              const SizedBox(height: 12),
              _buildMetadata(),
              if (widget.showTimeTracking) ...[
                const SizedBox(height: 8),
                _buildTimeTracking(),
              ],
              if (widget.showQuickActions) ...[
                const SizedBox(height: 8),
                _buildQuickActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildStatusChip(),
        const SizedBox(width: 8),
        _buildPriorityChip(),
        const Spacer(),
        if (widget.task.isOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 12, color: Colors.red[700]),
                const SizedBox(width: 4),
                Text(
                  'Overdue',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (_isTimerRunning) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 12, color: Colors.green[700]),
                const SizedBox(width: 4),
                StreamBuilder<ActiveTimer?>(
                  stream: _timeTrackingService.activeTimerStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data?.taskId == widget.task.id) {
                      return Text(
                        snapshot.data!.formattedElapsed,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip() {
    return GestureDetector(
      onTap: () => _showStatusPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getStatusColor().withOpacity(0.3)),
        ),
        child: Text(
          widget.task.status.displayName,
          style: TextStyle(
            fontSize: 10,
            color: _getStatusColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return GestureDetector(
      onTap: () => _showPriorityPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getPriorityColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getPriorityColor().withOpacity(0.3)),
        ),
        child: Text(
          _getPriorityLabel(),
          style: TextStyle(
            fontSize: 10,
            color: _getPriorityColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.task.title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.task.description!,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadata() {
    return Row(
      children: [
        if (widget.task.dueDate != null) ...[
          Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            _formatDueDate(),
            style: TextStyle(
              fontSize: 12,
              color: widget.task.isOverdue ? Colors.red : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (widget.task.assigneeName.isNotEmpty) ...[
          Icon(Icons.person, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            widget.task.assigneeName,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
        ],
        if (widget.task.hasComments) ...[
          Icon(Icons.comment, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${widget.task.counts.comments}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
        ],
        if (widget.task.hasAttachments) ...[
          Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${widget.task.counts.attachments}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeTracking() {
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '${widget.task.actualHours?.toStringAsFixed(1) ?? '0.0'}h logged',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        if (widget.task.estimatedHours != null) ...[
          Text(
            ' / ${widget.task.estimatedHours!.toStringAsFixed(1)}h estimated',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildTimerButton(),
        const SizedBox(width: 8),
        _buildChatButton(),
        const SizedBox(width: 8),
        _buildMoreActionsButton(),
      ],
    );
  }

  Widget _buildTimerButton() {
    return InkWell(
      onTap: _toggleTimer,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isTimerRunning ? Colors.red[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isTimerRunning ? Colors.red[200]! : Colors.green[200]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isTimerRunning ? Icons.stop : Icons.play_arrow,
              size: 14,
              color: _isTimerRunning ? Colors.red[700] : Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              _isTimerRunning ? 'Stop' : 'Start',
              style: TextStyle(
                fontSize: 12,
                color: _isTimerRunning ? Colors.red[700] : Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return InkWell(
      onTap: () => _openTaskChat(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, size: 14, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              'Chat',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreActionsButton() {
    return PopupMenuButton<String>(
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              'More',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor() {
    switch (widget.task.status) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.inReview:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getPriorityColor() {
    switch (widget.task.priority) {
      case Priority.importantUrgent:
        return Colors.red;
      case Priority.importantNotUrgent:
        return Colors.orange;
      case Priority.notImportantUrgent:
        return Colors.yellow[700]!;
      case Priority.notImportantNotUrgent:
        return Colors.grey;
    }
  }

  String _getPriorityLabel() {
    switch (widget.task.priority) {
      case Priority.importantUrgent:
        return 'High';
      case Priority.importantNotUrgent:
        return 'Medium';
      case Priority.notImportantUrgent:
        return 'Low';
      case Priority.notImportantNotUrgent:
        return 'Lowest';
    }
  }

  String _formatDueDate() {
    if (widget.task.dueDate == null) return '';
    
    final now = DateTime.now();
    final dueDate = widget.task.dueDate!;
    final difference = dueDate.difference(now);
    
    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays == 0) {
      return 'Due today';
    } else if (difference.inDays == 1) {
      return 'Due tomorrow';
    } else if (difference.inDays < 7) {
      return 'Due in ${difference.inDays} days';
    } else {
      return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }

  // Action handlers
  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskStatus.values.map((status) {
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColorForStatus(status),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(status.displayName),
              onTap: () {
                Navigator.pop(context);
                widget.onStatusChanged?.call(widget.task.copyWith(status: status));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: Priority.values.map((priority) {
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getPriorityColorForPriority(priority),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(priority.displayName),
              onTap: () {
                Navigator.pop(context);
                widget.onPriorityChanged?.call(widget.task.copyWith(priority: priority));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleTimer() async {
    try {
      if (_isTimerRunning) {
        await _timeTrackingService.stopTimer(widget.task.id);
      } else {
        await _timeTrackingService.startTimer(widget.task.id, widget.task.title);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling timer: $e')),
      );
    }
  }

  void _openTaskChat() {
    // Navigate to task-specific chat
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'taskId': widget.task.id,
        'taskTitle': widget.task.title,
      },
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        // Navigate to edit task
        Navigator.pushNamed(
          context,
          '/task-edit',
          arguments: widget.task,
        );
        break;
      case 'duplicate':
        // Duplicate task logic
        break;
      case 'delete':
        // Delete task logic
        break;
    }
  }

  Color _getStatusColorForStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.inReview:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getPriorityColorForPriority(Priority priority) {
    switch (priority) {
      case Priority.importantUrgent:
        return Colors.red;
      case Priority.importantNotUrgent:
        return Colors.orange;
      case Priority.notImportantUrgent:
        return Colors.yellow[700]!;
      case Priority.notImportantNotUrgent:
        return Colors.grey;
    }
  }
}
