import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/api_service.dart';

class ModuleManager extends StatefulWidget {
  final Project project;
  final VoidCallback? onModuleChanged;

  const ModuleManager({
    Key? key,
    required this.project,
    this.onModuleChanged,
  }) : super(key: key);

  @override
  State<ModuleManager> createState() => _ModuleManagerState();
}

class _ModuleManagerState extends State<ModuleManager> {
  List<Map<String, dynamic>> _modules = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final modules = await ApiService.getProjectModules(widget.project.id);
      
      setState(() {
        _modules = List<Map<String, dynamic>>.from(modules);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load modules: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createModule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ModuleFormDialog(
        title: 'Create Module',
        projectId: widget.project.id,
      ),
    );

    if (result != null) {
      await _loadModules();
      if (widget.onModuleChanged != null) {
        widget.onModuleChanged!();
      }
    }
  }

  Future<void> _editModule(Map<String, dynamic> module) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ModuleFormDialog(
        title: 'Edit Module',
        projectId: widget.project.id,
        module: module,
      ),
    );

    if (result != null) {
      await _loadModules();
      if (widget.onModuleChanged != null) {
        widget.onModuleChanged!();
      }
    }
  }

  Future<void> _deleteModule(Map<String, dynamic> module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete "${module['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteModule(module['id']);
        await _loadModules();
        if (widget.onModuleChanged != null) {
          widget.onModuleChanged!();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Module deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete module: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.view_module, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Project Modules',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _createModule,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Module'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[600]))),
                  ],
                ),
              ),

            // Content
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_modules.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.view_module_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No modules created yet'),
                    Text('Create your first module to organize tasks'),
                  ],
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _modules.length,
                  onReorder: _reorderModules,
                  itemBuilder: (context, index) {
                    final module = _modules[index];
                    return _buildModuleCard(module, index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module, int index) {
    final statistics = module['statistics'] ?? {};
    final completionPercentage = statistics['taskCompletionPercentage'] ?? 0;
    
    return Card(
      key: ValueKey(module['id']),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(module['status']),
          child: Text('${index + 1}'),
        ),
        title: Text(module['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (module['description'] != null)
              Text(
                module['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(module['status']),
                const SizedBox(width: 8),
                _buildPriorityChip(module['priority']),
                const Spacer(),
                Text('${statistics['totalTasks'] ?? 0} tasks'),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$completionPercentage%'),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
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
              onSelected: (value) {
                if (value == 'edit') {
                  _editModule(module);
                } else if (value == 'delete') {
                  _deleteModule(module);
                }
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                
                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tasks',
                        '${statistics['completedTasks'] ?? 0}/${statistics['totalTasks'] ?? 0}',
                        Icons.task,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Hours',
                        '${statistics['totalActualHours']?.toStringAsFixed(1) ?? '0.0'}h',
                        Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Variance',
                        '${statistics['hoursVariance']?.toStringAsFixed(1) ?? '0.0'}h',
                        Icons.trending_up,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.split('_').last,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'COMPLETED':
        return Colors.blue;
      case 'ON_HOLD':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'IMPORTANT_URGENT':
        return Colors.red;
      case 'IMPORTANT_NOT_URGENT':
        return Colors.orange;
      case 'NOT_IMPORTANT_URGENT':
        return Colors.yellow[700]!;
      case 'NOT_IMPORTANT_NOT_URGENT':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _reorderModules(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final module = _modules.removeAt(oldIndex);
      _modules.insert(newIndex, module);
    });

    // Update order on server
    _updateModuleOrder();
  }

  Future<void> _updateModuleOrder() async {
    try {
      final moduleOrders = _modules.asMap().entries.map((entry) => {
        'id': entry.value['id'],
        'orderIndex': entry.key,
      }).toList();

      await ApiService.reorderModules(widget.project.id, moduleOrders);
    } catch (e) {
      // Revert on error
      await _loadModules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update module order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ModuleFormDialog extends StatefulWidget {
  final String title;
  final String projectId;
  final Map<String, dynamic>? module;

  const _ModuleFormDialog({
    required this.title,
    required this.projectId,
    this.module,
  });

  @override
  State<_ModuleFormDialog> createState() => _ModuleFormDialogState();
}

class _ModuleFormDialogState extends State<_ModuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'NOT_IMPORTANT_NOT_URGENT';
  int _priorityNumber = 1;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _estimatedHours;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _nameController.text = widget.module!['name'] ?? '';
      _descriptionController.text = widget.module!['description'] ?? '';
      _priority = widget.module!['priority'] ?? 'NOT_IMPORTANT_NOT_URGENT';
      _priorityNumber = widget.module!['priorityNumber'] ?? 1;
      if (widget.module!['startDate'] != null) {
        _startDate = DateTime.parse(widget.module!['startDate']);
      }
      if (widget.module!['endDate'] != null) {
        _endDate = DateTime.parse(widget.module!['endDate']);
      }
      _estimatedHours = widget.module!['estimatedHours']?.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Module Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a module name';
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
                
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IMPORTANT_URGENT', child: Text('Important & Urgent')),
                    DropdownMenuItem(value: 'IMPORTANT_NOT_URGENT', child: Text('Important & Not Urgent')),
                    DropdownMenuItem(value: 'NOT_IMPORTANT_URGENT', child: Text('Not Important & Urgent')),
                    DropdownMenuItem(value: 'NOT_IMPORTANT_NOT_URGENT', child: Text('Not Important & Not Urgent')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _priority = value!;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.module == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': _priority,
        'priorityNumber': _priorityNumber,
        if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
        if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
        if (_estimatedHours != null) 'estimatedHours': _estimatedHours,
      };

      if (widget.module == null) {
        await ApiService.createModule(widget.projectId, data);
      } else {
        await ApiService.updateModule(widget.module!['id'], data);
      }

      Navigator.of(context).pop(data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save module: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
