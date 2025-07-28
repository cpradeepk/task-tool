import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(TaskStatus)? onStatusChanged;
  final bool isCompact;

  const TaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onStatusChanged,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final canEdit = user?.id == task.createdById || 
                   user?.id == task.mainAssigneeId ||
                   task.assignments.any((a) => a.userId == user?.id);

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description != null && !isCompact) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit && !isCompact) ...[
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(),
                  const SizedBox(width: 8),
                  _buildPriorityChip(),
                  if (!isCompact) ...[
                    const SizedBox(width: 8),
                    _buildTypeChip(),
                  ],
                ],
              ),
              if (!isCompact) ...[
                const SizedBox(height: 12),
                _buildTaskInfo(),
              ],
              if (task.isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return GestureDetector(
      onTap: onStatusChanged != null ? () => _showStatusMenu() : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(task.statusColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          task.statusLabel,
          style: TextStyle(
            fontSize: 12,
            color: task.status == TaskStatus.open ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(task.priorityColor).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(task.priorityColor),
          width: 1,
        ),
      ),
      child: Text(
        task.priorityLabel,
        style: TextStyle(
          fontSize: 12,
          color: Color(task.priorityColor),
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTypeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[300]!,
          width: 1,
        ),
      ),
      child: Text(
        task.typeLabel,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      children: [
        Row(
          children: [
            if (task.mainAssignee != null) ...[
              Icon(Icons.person, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                task.mainAssignee!['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (task.estimatedHours != null) ...[
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${task.estimatedHours!.toStringAsFixed(1)}h',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (task.count != null && task.count!['subtasks'] > 0) ...[
              Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${task.count!['subtasks']} subtasks',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (task.dueDate != null) ...[
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDate(task.dueDate!),
                style: TextStyle(
                  fontSize: 12,
                  color: task.isOverdue ? Colors.red[600] : Colors.grey[600],
                  fontWeight: task.isOverdue ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const Spacer(),
            ],
            Text(
              _formatDate(task.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showStatusMenu() {
    // This would typically show a popup menu or bottom sheet
    // For now, we'll cycle through statuses
    final currentIndex = TaskStatus.values.indexOf(task.status);
    final nextIndex = (currentIndex + 1) % TaskStatus.values.length;
    onStatusChanged?.call(TaskStatus.values[nextIndex]);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }
}
}
