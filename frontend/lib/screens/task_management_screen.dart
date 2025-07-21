import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class TaskManagementScreen extends StatefulWidget {
  final String? projectId;
  final String? subProjectId;

  const TaskManagementScreen({
    Key? key,
    this.projectId,
    this.subProjectId,
  }) : super(key: key);

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;
  TaskType? _typeFilter;
  String? _assigneeFilter;
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';
  String _viewMode = 'list'; // list, board, calendar
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        setState(() {
          _isLoading = true;
          _error = null;
          _currentPage = 1;
        });
      }

      final response = await ApiService.getTasks(
        projectId: widget.projectId,
        subProjectId: widget.subProjectId,
        status: _statusFilter?.value,
        priority: _priorityFilter?.value,
        taskType: _typeFilter?.value,
        mainAssigneeId: _assigneeFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        page: _currentPage,
        limit: _pageSize,
      );

      final tasksData = response['tasks'] as List<dynamic>;
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      final pagination = response['pagination'] as Map<String, dynamic>;

      setState(() {
        if (loadMore) {
          _tasks.addAll(tasks);
        } else {
          _tasks = tasks;
        }
        _hasMoreData = _currentPage < pagination['pages'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTasks() async {
    if (_hasMoreData && !_isLoading) {
      setState(() {
        _currentPage++;
      });
      await _loadTasks(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectId != null ? 'Project Tasks' : 'All Tasks'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'list' ? Icons.view_module : Icons.view_list),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'list' ? 'board' : 'list';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTasks(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateTaskDialog(context),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: _buildTasksList(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFiltersPanel(),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              _buildViewModeSelector(),
              Expanded(child: _buildTasksView()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 350,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFiltersPanel(),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              _buildToolbar(),
              Expanded(child: _buildTasksView()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildQuickFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search tasks...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
        _debounceSearch();
      },
    );
  }

  void _debounceSearch() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadTasks();
      }
    });
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('In Progress'),
          selected: _statusFilter == TaskStatus.inProgress,
          onSelected: (selected) {
            setState(() {
              _statusFilter = selected ? TaskStatus.inProgress : null;
            });
            _loadTasks();
          },
        ),
        FilterChip(
          label: const Text('High Priority'),
          selected: _priorityFilter == TaskPriority.importantUrgent,
          onSelected: (selected) {
            setState(() {
              _priorityFilter = selected ? TaskPriority.importantUrgent : null;
            });
            _loadTasks();
          },
        ),
        FilterChip(
          label: const Text('My Tasks'),
          selected: _assigneeFilter != null,
          onSelected: (selected) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            setState(() {
              _assigneeFilter = selected ? authProvider.user?.id : null;
            });
            _loadTasks();
          },
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filters',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStatusFilter(),
        const SizedBox(height: 16),
        _buildPriorityFilter(),
        const SizedBox(height: 16),
        _buildTypeFilter(),
        const SizedBox(height: 16),
        _buildSortingOptions(),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskStatus?>(
          value: _statusFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Statuses')),
            ...TaskStatus.values.map((status) => DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(status.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status.label),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _statusFilter = value;
            });
            _loadTasks();
          },
        ),
      ],
    );
  }

  Widget _buildPriorityFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Priority', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskPriority?>(
          value: _priorityFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Priorities')),
            ...TaskPriority.values.map((priority) => DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(priority.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      priority.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _priorityFilter = value;
            });
            _loadTasks();
          },
        ),
      ],
    );
  }

  Widget _buildTypeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Type', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskType?>(
          value: _typeFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Types')),
            ...TaskType.values.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type.label),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _typeFilter = value;
            });
            _loadTasks();
          },
        ),
      ],
    );
  }

  Widget _buildSortingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'createdAt', child: Text('Created Date')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                  DropdownMenuItem(value: 'dueDate', child: Text('Due Date')),
                ],
                onChanged: (value) {
                  setState(() {
                    _sortBy = value ?? 'createdAt';
                  });
                  _loadTasks();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                });
                _loadTasks();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewModeSelector() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'list', label: Text('List'), icon: Icon(Icons.view_list)),
              ButtonSegment(value: 'board', label: Text('Board'), icon: Icon(Icons.view_module)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _viewMode = selection.first;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildViewModeSelector(),
          const Spacer(),
          Text('${_tasks.length} tasks'),
        ],
      ),
    );
  }

  Widget _buildTasksView() {
    if (_viewMode == 'board') {
      return _buildTasksBoard();
    } else {
      return _buildTasksList();
    }
  }

  Widget _buildTasksList() {
    if (_isLoading && _tasks.isEmpty) {
      return const LoadingWidget();
    }

    if (_error != null && _tasks.isEmpty) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: () => _loadTasks(),
      );
    }

    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
            _hasMoreData && !_isLoading) {
          _loadMoreTasks();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _tasks.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _tasks.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return TaskCard(
            task: _tasks[index],
            onTap: () => _navigateToTaskDetails(_tasks[index]),
            onEdit: () => _showEditTaskDialog(context, _tasks[index]),
            onDelete: () => _showDeleteTaskDialog(context, _tasks[index]),
            onStatusChanged: (newStatus) => _updateTaskStatus(_tasks[index], newStatus),
          );
        },
      ),
    );
  }

  Widget _buildTasksBoard() {
    final statusGroups = <TaskStatus, List<Task>>{};
    
    for (final status in TaskStatus.values) {
      statusGroups[status] = _tasks.where((task) => task.status == status).toList();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: TaskStatus.values.map((status) {
          final tasks = statusGroups[status] ?? [];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(status.color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(status.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text('${tasks.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return TaskCard(
                        task: tasks[index],
                        onTap: () => _navigateToTaskDetails(tasks[index]),
                        onEdit: () => _showEditTaskDialog(context, tasks[index]),
                        onDelete: () => _showDeleteTaskDialog(context, tasks[index]),
                        onStatusChanged: (newStatus) => _updateTaskStatus(tasks[index], newStatus),
                        isCompact: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        projectId: widget.projectId,
        subProjectId: widget.subProjectId,
        onSave: (taskData) async {
          try {
            await ApiService.createTask(taskData);
            await _loadTasks();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task created successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating task: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        task: task,
        onSave: (taskData) async {
          try {
            await ApiService.updateTask(task.id, taskData);
            await _loadTasks();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating task: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ApiService.deleteTask(task.id);
                await _loadTasks();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting task: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus newStatus) async {
    try {
      await ApiService.updateTask(task.id, {'status': newStatus.value});
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task status updated to ${newStatus.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task status: $e')),
        );
      }
    }
  }

  void _navigateToTaskDetails(Task task) {
    Navigator.pushNamed(
      context,
      '/task-details',
      arguments: task,
    );
  }
}
