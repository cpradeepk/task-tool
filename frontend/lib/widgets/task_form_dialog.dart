import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? task;
  final String? projectId;
  final String? subProjectId;
  final Function(Map<String, dynamic>) onSave;

  const TaskFormDialog({
    Key? key,
    this.task,
    this.projectId,
    this.subProjectId,
    required this.onSave,
  }) : super(key: key);

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _optimisticHoursController = TextEditingController();
  final _pessimisticHoursController = TextEditingController();
  final _mostLikelyHoursController = TextEditingController();
  
  TaskStatus _status = TaskStatus.open;
  TaskPriority _priority = TaskPriority.notImportantNotUrgent;
  TaskType _taskType = TaskType.requirement;
  DateTime? _dueDate;
  DateTime? _plannedEndDate;
  String? _mainAssigneeId;
  List<String> _supportAssignees = [];
  List<String> _tags = [];
  List<String> _milestones = [];
  List<String> _customLabels = [];
  
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description ?? '';
      _status = widget.task!.status;
      _priority = widget.task!.priority;
      _taskType = widget.task!.taskType;
      _dueDate = widget.task!.dueDate;
      _plannedEndDate = widget.task!.plannedEndDate;
      _mainAssigneeId = widget.task!.mainAssigneeId;
      _tags = List.from(widget.task!.tags);
      _milestones = List.from(widget.task!.milestones);
      _customLabels = List.from(widget.task!.customLabels);
      _supportAssignees = widget.task!.assignments
          .where((a) => a.role == TaskAssignmentRole.support)
          .map((a) => a.userId)
          .toList();
      
      if (widget.task!.optimisticHours != null) {
        _optimisticHoursController.text = widget.task!.optimisticHours.toString();
      }
      if (widget.task!.pessimisticHours != null) {
        _pessimisticHoursController.text = widget.task!.pessimisticHours.toString();
      }
      if (widget.task!.mostLikelyHours != null) {
        _mostLikelyHoursController.text = widget.task!.mostLikelyHours.toString();
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
    });
    
    try {
      final users = await ApiService.getAllUsers();
      setState(() {
        _availableUsers = List<Map<String, dynamic>>.from(users);
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _optimisticHoursController.dispose();
    _pessimisticHoursController.dispose();
    _mostLikelyHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Task' : 'Create New Task',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildBasicFields(),
                        const SizedBox(height: 24),
                        _buildStatusAndPriority(),
                        const SizedBox(height: 24),
                        _buildDates(),
                        const SizedBox(height: 24),
                        _buildTimeEstimates(),
                        const SizedBox(height: 24),
                        _buildAssignments(),
                        const SizedBox(height: 24),
                        _buildTagsAndLabels(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Task Title *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Task title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TaskType>(
          value: _taskType,
          decoration: const InputDecoration(
            labelText: 'Task Type',
            border: OutlineInputBorder(),
          ),
          items: TaskType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.label),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _taskType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusAndPriority() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<TaskStatus>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: TaskStatus.values.map((status) {
              return DropdownMenuItem(
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
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _status = value!;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<TaskPriority>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: TaskPriority.values.map((priority) {
              return DropdownMenuItem(
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
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _priority = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDates() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _dueDate != null
                    ? _formatDate(_dueDate!)
                    : 'Select due date',
                style: TextStyle(
                  color: _dueDate != null
                      ? Colors.black
                      : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Planned End Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _plannedEndDate != null
                    ? _formatDate(_plannedEndDate!)
                    : 'Select planned end date',
                style: TextStyle(
                  color: _plannedEndDate != null
                      ? Colors.black
                      : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeEstimates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PERT Time Estimates (hours)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _optimisticHoursController,
                decoration: const InputDecoration(
                  labelText: 'Optimistic',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _mostLikelyHoursController,
                decoration: const InputDecoration(
                  labelText: 'Most Likely',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _pessimisticHoursController,
                decoration: const InputDecoration(
                  labelText: 'Pessimistic',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assignments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_loadingUsers)
          const CircularProgressIndicator()
        else ...[
          DropdownButtonFormField<String?>(
            value: _mainAssigneeId,
            decoration: const InputDecoration(
              labelText: 'Main Assignee',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('No assignee')),
              ..._availableUsers.map((user) => DropdownMenuItem(
                value: user['id'],
                child: Text(user['name'] ?? user['email']),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _mainAssigneeId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text('Support Assignees'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _availableUsers.map((user) {
              final isSelected = _supportAssignees.contains(user['id']);
              return FilterChip(
                label: Text(user['name'] ?? user['email']),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _supportAssignees.add(user['id']);
                    } else {
                      _supportAssignees.remove(user['id']);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTagsAndLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags & Labels',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Tags (comma separated)',
            border: OutlineInputBorder(),
          ),
          initialValue: _tags.join(', '),
          onChanged: (value) {
            _tags = value.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Custom Labels (comma separated)',
            border: OutlineInputBorder(),
          ),
          initialValue: _customLabels.join(', '),
          onChanged: (value) {
            _customLabels = value.split(',').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.task != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDueDate
          ? (_dueDate ?? DateTime.now())
          : (_plannedEndDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _plannedEndDate = picked;
        }
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'status': _status.value,
        'priority': _priority.value,
        'taskType': _taskType.value,
        'dueDate': _dueDate?.toIso8601String(),
        'plannedEndDate': _plannedEndDate?.toIso8601String(),
        'optimisticHours': _optimisticHoursController.text.isEmpty
            ? null
            : double.tryParse(_optimisticHoursController.text),
        'pessimisticHours': _pessimisticHoursController.text.isEmpty
            ? null
            : double.tryParse(_pessimisticHoursController.text),
        'mostLikelyHours': _mostLikelyHoursController.text.isEmpty
            ? null
            : double.tryParse(_mostLikelyHoursController.text),
        'mainAssigneeId': _mainAssigneeId,
        'supportAssignees': _supportAssignees,
        'tags': _tags,
        'customLabels': _customLabels,
        'milestones': _milestones,
      };

      if (widget.projectId != null) {
        taskData['projectId'] = widget.projectId;
      }
      if (widget.subProjectId != null) {
        taskData['subProjectId'] = widget.subProjectId;
      }

      widget.onSave(taskData);
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
