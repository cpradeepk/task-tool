import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _selectedStatus = 'ALL';
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
      context.read<ProjectProvider>().fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateTaskDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                if (taskProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (taskProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${taskProvider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            taskProvider.clearError();
                            taskProvider.fetchTasks();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                List<Task> filteredTasks = taskProvider.tasks;
                if (_selectedStatus != 'ALL') {
                  filteredTasks = filteredTasks.where((task) => task.status == _selectedStatus).toList();
                }
                if (_selectedProjectId != null) {
                  filteredTasks = filteredTasks.where((task) => task.projectId == _selectedProjectId).toList();
                }

                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks found',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return _buildTaskCard(context, task);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ['ALL', 'TODO', 'IN_PROGRESS', 'REVIEW', 'DONE']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Consumer<ProjectProvider>(
              builder: (context, projectProvider, child) {
                return DropdownButtonFormField<String?>(
                  value: _selectedProjectId,
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Projects'),
                    ),
                    ...projectProvider.projects.map((project) => DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedProjectId = value;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildPriorityChip(task.priority),
                const SizedBox(width: 8),
                _buildStatusChip(task.status),
              ],
            ),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (task.project != null) ...[
                  Icon(Icons.folder, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    task.project!.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                ],
                if (task.assignedTo != null) ...[
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    task.assignedTo!.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Spacer(),
                if (task.dueDate != null) ...[
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'HIGH':
        color = Colors.red;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        break;
      case 'LOW':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(priority),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'TODO':
        color = Colors.grey;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      case 'REVIEW':
        color = Colors.orange;
        break;
      case 'DONE':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String priority = 'MEDIUM';
    String? selectedProjectId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Consumer<ProjectProvider>(
                  builder: (context, projectProvider, child) {
                    return DropdownButtonFormField<String?>(
                      value: selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No Project'),
                        ),
                        ...projectProvider.projects.map((project) => DropdownMenuItem(
                              value: project.id,
                              child: Text(project.name),
                            )),
                      ],
                      onChanged: (value) => setState(() => selectedProjectId = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['LOW', 'MEDIUM', 'HIGH']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) => setState(() => priority = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task title is required')),
                  );
                  return;
                }

                final success = await context.read<TaskProvider>().createTask(
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                  projectId: selectedProjectId,
                  priority: priority,
                );

                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task created successfully')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}