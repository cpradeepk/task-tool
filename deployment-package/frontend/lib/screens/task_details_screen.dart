import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/task_dependency_graph.dart';
import '../widgets/time_tracking_widget.dart';
import '../widgets/task_comments_widget.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailsScreen({
    Key? key,
    required this.taskId,
  }) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> with TickerProviderStateMixin {
  Task? _task;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  
  Map<String, dynamic>? _dependencyChain;
  List<Map<String, dynamic>> _criticalPath = [];
  bool _loadingDependencies = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTaskDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final taskData = await ApiService.getTask(widget.taskId);
      final task = Task.fromJson(taskData);

      setState(() {
        _task = task;
        _isLoading = false;
      });

      // Load dependency information
      _loadDependencyInfo();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDependencyInfo() async {
    if (_task?.projectId == null) return;

    try {
      setState(() {
        _loadingDependencies = true;
      });

      final [dependencyChain, criticalPath] = await Future.wait([
        ApiService.get('/tasks/${widget.taskId}/dependency-chain'),
        ApiService.get('/tasks/projects/${_task!.projectId}/critical-path'),
      ]);

      setState(() {
        _dependencyChain = dependencyChain;
        _criticalPath = List<Map<String, dynamic>>.from(criticalPath['criticalPath'] ?? []);
        _loadingDependencies = false;
      });
    } catch (e) {
      setState(() {
        _loadingDependencies = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_task?.title ?? 'Task Details'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          if (_task != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditTaskDialog(),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'duplicate':
                    _duplicateTask();
                    break;
                  case 'delete':
                    _showDeleteDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy),
                      SizedBox(width: 8),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: _task != null ? TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Overview'),
            Tab(icon: Icon(Icons.account_tree), text: 'Dependencies'),
            Tab(icon: Icon(Icons.schedule), text: 'Time Tracking'),
            Tab(icon: Icon(Icons.comment), text: 'Comments'),
            Tab(icon: Icon(Icons.attach_file), text: 'Attachments'),
          ],
        ) : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: _loadTaskDetails,
      );
    }

    if (_task == null) {
      return const Center(
        child: Text('Task not found'),
      );
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildDependenciesTab(),
        _buildTimeTrackingTab(),
        _buildCommentsTab(),
        _buildAttachmentsTab(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildOverviewTab(),
        ),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(child: _buildTimeTrackingTab()),
              Expanded(child: _buildCommentsTab()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildOverviewTab()),
              Expanded(child: _buildDependenciesTab()),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildTimeTrackingTab()),
              Expanded(child: _buildCommentsTab()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskHeader(),
          const SizedBox(height: 24),
          _buildTaskDetails(),
          const SizedBox(height: 24),
          _buildTaskProgress(),
          const SizedBox(height: 24),
          _buildTaskMetrics(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _task!.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            if (_task!.description != null) ...[
              const SizedBox(height: 12),
              Text(
                _task!.description!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPriorityChip(),
                _buildTypeChip(),
                if (_task!.isOverdue) _buildOverdueChip(),
                if (_criticalPath.any((cp) => cp['id'] == _task!.id)) _buildCriticalPathChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(_task!.statusColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _task!.statusLabel,
        style: TextStyle(
          color: _task!.status == TaskStatus.open ? Colors.black : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(_task!.priorityColor).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(_task!.priorityColor)),
      ),
      child: Text(
        _task!.priorityLabel,
        style: TextStyle(
          fontSize: 12,
          color: Color(_task!.priorityColor),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTypeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Text(
        _task!.typeLabel,
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOverdueChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 14, color: Colors.red[700]),
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
    );
  }

  Widget _buildCriticalPathChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Text(
            'Critical Path',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Project', _task!.project?['name'] ?? 'No Project'),
            if (_task!.subProject != null)
              _buildDetailRow('Sub Project', _task!.subProject!['name']),
            if (_task!.mainAssignee != null)
              _buildDetailRow('Main Assignee', _task!.mainAssignee!['name']),
            if (_task!.assignments.isNotEmpty)
              _buildDetailRow('Support Team', '${_task!.assignments.length} members'),
            if (_task!.dueDate != null)
              _buildDetailRow('Due Date', _formatDate(_task!.dueDate!)),
            if (_task!.plannedEndDate != null)
              _buildDetailRow('Planned End', _formatDate(_task!.plannedEndDate!)),
            _buildDetailRow('Created', _formatDate(_task!.createdAt)),
            if (_task!.startDate != null)
              _buildDetailRow('Started', _formatDate(_task!.startDate!)),
            if (_task!.endDate != null)
              _buildDetailRow('Completed', _formatDate(_task!.endDate!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress & Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_task!.estimatedHours != null || _task!.actualHours != null) ...[
              _buildTimeComparison(),
              const SizedBox(height: 16),
            ],
            if (_task!.optimisticHours != null || _task!.pessimisticHours != null || _task!.mostLikelyHours != null) ...[
              _buildPERTEstimates(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeComparison() {
    final estimated = _task!.estimatedHours ?? 0;
    final actual = _task!.actualHours ?? 0;
    final progress = estimated > 0 ? (actual / estimated).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Estimated: ${estimated.toStringAsFixed(1)}h'),
            Text('Actual: ${actual.toStringAsFixed(1)}h'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress > 1.0 ? Colors.red : Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% of estimated time',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPERTEstimates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PERT Estimates',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_task!.optimisticHours != null)
              Expanded(
                child: _buildEstimateCard('Optimistic', _task!.optimisticHours!, Colors.green),
              ),
            if (_task!.mostLikelyHours != null)
              Expanded(
                child: _buildEstimateCard('Most Likely', _task!.mostLikelyHours!, Colors.blue),
              ),
            if (_task!.pessimisticHours != null)
              Expanded(
                child: _buildEstimateCard('Pessimistic', _task!.pessimisticHours!, Colors.orange),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEstimateCard(String label, double hours, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Comments',
                    '${_task!.count?['comments'] ?? 0}',
                    Icons.comment,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricCard(
                    'Attachments',
                    '${_task!.count?['attachments'] ?? 0}',
                    Icons.attach_file,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricCard(
                    'Subtasks',
                    '${_task!.count?['subtasks'] ?? 0}',
                    Icons.subdirectory_arrow_right,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDependenciesTab() {
    if (_task?.projectId == null) {
      return const Center(
        child: Text('No project associated with this task'),
      );
    }

    return TaskDependencyGraph(
      projectId: _task!.projectId!,
      onTaskTap: (taskId) {
        if (taskId != widget.taskId) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsScreen(taskId: taskId),
            ),
          );
        }
      },
    );
  }

  Widget _buildTimeTrackingTab() {
    return TimeTrackingWidget(
      taskId: widget.taskId,
      task: _task!,
    );
  }

  Widget _buildCommentsTab() {
    return TaskCommentsWidget(
      taskId: widget.taskId,
    );
  }

  Widget _buildAttachmentsTab() {
    return const Center(
      child: Text('Attachments feature coming soon'),
    );
  }

  void _showEditTaskDialog() {
    // Implementation for edit task dialog
  }

  void _duplicateTask() {
    // Implementation for duplicate task
  }

  void _showDeleteDialog() {
    // Implementation for delete task dialog
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
