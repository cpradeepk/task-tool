import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';
import 'professional_card.dart';
import 'professional_buttons.dart';

/// Professional task card with ownership indicators and support team features
class ProfessionalTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSupport;
  final bool showActions;
  final bool isClickable;

  const ProfessionalTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddSupport,
    this.showActions = true,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      onTap: isClickable ? onTap : null,
      showHoverEffect: isClickable,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with task ID and status
          Row(
            children: [
              // Task ID badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing8,
                  vertical: DesignTokens.spacing4,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.colors['gray100'],
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Text(
                  task['task_id_formatted'] ?? 'JSR-${task['id']}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.colors['gray700'],
                  ),
                ),
              ),
              const Spacer(),
              // Status badge
              _buildStatusBadge(),
              if (showActions) ...[
                const SizedBox(width: DesignTokens.spacing8),
                _buildActionMenu(context),
              ],
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Task title
          Text(
            task['title'] ?? 'Untitled Task',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DesignTokens.colors['black'],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (task['description'] != null && task['description'].isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              task['description'],
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.colors['gray600'],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          const SizedBox(height: DesignTokens.spacing16),
          
          // Task metadata
          _buildTaskMetadata(),
          
          const SizedBox(height: DesignTokens.spacing12),
          
          // Ownership indicators and support team
          _buildOwnershipSection(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = task['status'] ?? 'Open';
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing8,
        vertical: DesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: DesignTokens.colors['gray600'],
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          case 'add_support':
            onAddSupport?.call();
            break;
        }
      },
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
          value: 'add_support',
          child: Row(
            children: [
              Icon(Icons.people, size: 16),
              SizedBox(width: 8),
              Text('Add Support'),
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
    );
  }

  Widget _buildTaskMetadata() {
    return Row(
      children: [
        // Project/Module info
        if (task['project_name'] != null) ...[
          Icon(
            Icons.folder,
            size: 14,
            color: DesignTokens.colors['gray500'],
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Expanded(
            child: Text(
              '${task['project_name']}${task['module_name'] != null ? ' / ${task['module_name']}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: DesignTokens.colors['gray600'],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        
        // Due date
        if (task['due_date'] != null) ...[
          const SizedBox(width: DesignTokens.spacing8),
          Icon(
            Icons.schedule,
            size: 14,
            color: _getDueDateColor(),
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            _formatDueDate(),
            style: TextStyle(
              fontSize: 12,
              color: _getDueDateColor(),
              fontWeight: _isOverdue() ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOwnershipSection() {
    return Row(
      children: [
        // Owner badge
        _buildOwnerBadge(),
        
        // Support team indicators
        if (task['support_team'] != null) ...[
          const SizedBox(width: DesignTokens.spacing8),
          _buildSupportTeamIndicators(),
        ],
        
        const Spacer(),
        
        // Priority indicator
        if (task['priority'] != null)
          _buildPriorityIndicator(),
      ],
    );
  }

  Widget _buildOwnerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing6,
        vertical: DesignTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: DesignTokens.primaryOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: 12,
            color: DesignTokens.primaryOrange,
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            'Owner',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: DesignTokens.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTeamIndicators() {
    final supportTeam = task['support_team'] as List<dynamic>? ?? [];
    if (supportTeam.isEmpty) return const SizedBox.shrink();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing6,
            vertical: DesignTokens.spacing2,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.support_agent,
                size: 12,
                color: Colors.blue,
              ),
              const SizedBox(width: DesignTokens.spacing4),
              Text(
                'Support (${supportTeam.length})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityIndicator() {
    final priority = task['priority'] ?? 'Medium';
    final color = _getPriorityColor(priority);
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
        return DesignTokens.primaryOrange;
      case 'delayed':
        return Colors.red;
      case 'on hold':
      case 'hold':
        return Colors.amber;
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return const Color(0xFFB37200);
      case 'medium':
        return DesignTokens.primaryOrange;
      case 'low':
        return const Color(0xFFE6920E);
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  Color _getDueDateColor() {
    if (_isOverdue()) return const Color(0xFFB37200);
    if (_isDueToday()) return DesignTokens.primaryOrange;
    return DesignTokens.colors['gray600']!;
  }

  bool _isOverdue() {
    if (task['due_date'] == null) return false;
    final dueDate = DateTime.parse(task['due_date']);
    return dueDate.isBefore(DateTime.now());
  }

  bool _isDueToday() {
    if (task['due_date'] == null) return false;
    final dueDate = DateTime.parse(task['due_date']);
    final today = DateTime.now();
    return dueDate.year == today.year &&
           dueDate.month == today.month &&
           dueDate.day == today.day;
  }

  String _formatDueDate() {
    if (task['due_date'] == null) return '';
    final dueDate = DateTime.parse(task['due_date']);
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference == 0) return 'Due today';
    if (difference == 1) return 'Due tomorrow';
    if (difference == -1) return '1 day overdue';
    if (difference < 0) return '${-difference} days overdue';
    return 'Due in $difference days';
  }
}

/// Advanced task filtering component
class TaskFilterPanel extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onFiltersChanged;
  final VoidCallback? onClearFilters;
  final VoidCallback? onSaveFilter;

  const TaskFilterPanel({
    super.key,
    required this.currentFilters,
    required this.onFiltersChanged,
    this.onClearFilters,
    this.onSaveFilter,
  });

  @override
  State<TaskFilterPanel> createState() => _TaskFilterPanelState();
}

class _TaskFilterPanelState extends State<TaskFilterPanel> {
  late Map<String, dynamic> _filters;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = Map.from(widget.currentFilters);
    _searchController.text = _filters['search'] ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: DesignTokens.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                'Advanced Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.colors['black'],
                ),
              ),
              const Spacer(),
              if (widget.onSaveFilter != null)
                ProfessionalButton(
                  text: 'Save',
                  size: ButtonSize.small,
                  variant: ButtonVariant.outline,
                  onPressed: widget.onSaveFilter,
                ),
              const SizedBox(width: DesignTokens.spacing8),
              ProfessionalButton(
                text: 'Clear',
                size: ButtonSize.small,
                variant: ButtonVariant.ghost,
                onPressed: _clearFilters,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing16),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _updateFilter('search', null);
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              _updateFilter('search', value.isEmpty ? null : value);
            },
          ),
          const SizedBox(height: DesignTokens.spacing16),

          // Filter chips
          Wrap(
            spacing: DesignTokens.spacing8,
            runSpacing: DesignTokens.spacing8,
            children: [
              _buildStatusFilter(),
              _buildPriorityFilter(),
              _buildAssigneeFilter(),
              _buildDueDateFilter(),
              _buildSupportFilter(),
            ],
          ),

          const SizedBox(height: DesignTokens.spacing16),

          // Active filters summary
          if (_hasActiveFilters()) _buildActiveFiltersSummary(),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = ['Yet to Start', 'In Progress', 'Completed', 'Delayed', 'On Hold'];
    final selectedStatus = _filters['status'];

    return PopupMenuButton<String>(
      child: Chip(
        label: Text(selectedStatus ?? 'All Status'),
        avatar: Icon(
          Icons.circle,
          size: 16,
          color: selectedStatus != null
              ? _getStatusColor(selectedStatus)
              : DesignTokens.colors['gray500'],
        ),
        deleteIcon: selectedStatus != null ? const Icon(Icons.close, size: 16) : null,
        onDeleted: selectedStatus != null ? () => _updateFilter('status', null) : null,
      ),
      onSelected: (status) => _updateFilter('status', status),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Status')),
        ...statuses.map((status) => PopupMenuItem(
          value: status,
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 16,
                color: _getStatusColor(status),
              ),
              const SizedBox(width: 8),
              Text(status),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildPriorityFilter() {
    final priorities = ['High', 'Medium', 'Low'];
    final selectedPriority = _filters['priority'];

    return PopupMenuButton<String>(
      child: Chip(
        label: Text(selectedPriority ?? 'All Priority'),
        avatar: Icon(
          Icons.flag,
          size: 16,
          color: selectedPriority != null
              ? _getPriorityColor(selectedPriority)
              : DesignTokens.colors['gray500'],
        ),
        deleteIcon: selectedPriority != null ? const Icon(Icons.close, size: 16) : null,
        onDeleted: selectedPriority != null ? () => _updateFilter('priority', null) : null,
      ),
      onSelected: (priority) => _updateFilter('priority', priority),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Priority')),
        ...priorities.map((priority) => PopupMenuItem(
          value: priority,
          child: Row(
            children: [
              Icon(
                Icons.flag,
                size: 16,
                color: _getPriorityColor(priority),
              ),
              const SizedBox(width: 8),
              Text(priority),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAssigneeFilter() {
    final selectedAssignee = _filters['assigned_to'];

    return Chip(
      label: Text(selectedAssignee ?? 'All Assignees'),
      avatar: const Icon(Icons.person, size: 16),
      deleteIcon: selectedAssignee != null ? const Icon(Icons.close, size: 16) : null,
      onDeleted: selectedAssignee != null ? () => _updateFilter('assigned_to', null) : null,
    );
  }

  Widget _buildDueDateFilter() {
    final dueDateFilter = _filters['due_date_filter'];
    final options = {
      'overdue': 'Overdue',
      'today': 'Due Today',
      'this_week': 'This Week',
      'next_week': 'Next Week',
      'no_due_date': 'No Due Date',
    };

    return PopupMenuButton<String>(
      child: Chip(
        label: Text(options[dueDateFilter] ?? 'All Due Dates'),
        avatar: const Icon(Icons.schedule, size: 16),
        deleteIcon: dueDateFilter != null ? const Icon(Icons.close, size: 16) : null,
        onDeleted: dueDateFilter != null ? () => _updateFilter('due_date_filter', null) : null,
      ),
      onSelected: (filter) => _updateFilter('due_date_filter', filter),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Due Dates')),
        ...options.entries.map((entry) => PopupMenuItem(
          value: entry.key,
          child: Text(entry.value),
        )),
      ],
    );
  }

  Widget _buildSupportFilter() {
    final supportFilter = _filters['support_filter'];

    return PopupMenuButton<String>(
      child: Chip(
        label: Text(supportFilter == 'my_support' ? 'My Support Tasks' : 'All Tasks'),
        avatar: const Icon(Icons.support_agent, size: 16),
        deleteIcon: supportFilter != null ? const Icon(Icons.close, size: 16) : null,
        onDeleted: supportFilter != null ? () => _updateFilter('support_filter', null) : null,
      ),
      onSelected: (filter) => _updateFilter('support_filter', filter),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Tasks')),
        const PopupMenuItem(value: 'my_support', child: Text('My Support Tasks')),
        const PopupMenuItem(value: 'has_support', child: Text('Tasks with Support')),
        const PopupMenuItem(value: 'no_support', child: Text('Tasks without Support')),
      ],
    );
  }

  Widget _buildActiveFiltersSummary() {
    final activeFilters = _filters.entries
        .where((entry) => entry.value != null && entry.value != '')
        .length;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: DesignTokens.colors['primary50'],
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: DesignTokens.primaryOrange,
          ),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            '$activeFilters filter${activeFilters != 1 ? 's' : ''} active',
            style: TextStyle(
              fontSize: 12,
              color: DesignTokens.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _updateFilter(String key, dynamic value) {
    setState(() {
      if (value == null) {
        _filters.remove(key);
      } else {
        _filters[key] = value;
      }
    });
    widget.onFiltersChanged(_filters);
  }

  void _clearFilters() {
    setState(() {
      _filters.clear();
      _searchController.clear();
    });
    widget.onFiltersChanged(_filters);
    widget.onClearFilters?.call();
  }

  bool _hasActiveFilters() {
    return _filters.isNotEmpty &&
           _filters.values.any((value) => value != null && value != '');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return DesignTokens.colors['primary600']!; // Dark orange for completed
      case 'in progress':
        return DesignTokens.primaryOrange;
      case 'delayed':
        return DesignTokens.colors['primary800']!; // Darker orange for delayed
      case 'on hold':
      case 'hold':
        return DesignTokens.colors['primary400']!; // Light orange for hold
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return DesignTokens.colors['primary800']!; // Dark orange for high priority
      case 'medium':
        return DesignTokens.primaryOrange;
      case 'low':
        return DesignTokens.colors['primary300']!; // Light orange for low priority
      default:
        return DesignTokens.colors['gray500']!;
    }
  }
}
