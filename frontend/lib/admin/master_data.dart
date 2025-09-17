import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../components/breadcrumb.dart';


const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Priority data
  List<Map<String, dynamic>> _priorities = [];
  
  // Status data
  List<Map<String, dynamic>> _statuses = [];
  
  // Project categories
  List<Map<String, dynamic>> _categories = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMasterData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    
    // Load master data from API
    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load priorities, statuses, and task types from API
      final futures = await Future.wait([
        http.get(Uri.parse('$apiBase/task/api/master/priorities'), headers: {'Authorization': 'Bearer $jwt'}),
        http.get(Uri.parse('$apiBase/task/api/master/statuses'), headers: {'Authorization': 'Bearer $jwt'}),
        http.get(Uri.parse('$apiBase/task/api/master/task_types'), headers: {'Authorization': 'Bearer $jwt'}),
      ]);

      final prioritiesResponse = futures[0];
      final statusesResponse = futures[1];
      final taskTypesResponse = futures[2];

      if (prioritiesResponse.statusCode == 200) {
        final prioritiesData = jsonDecode(prioritiesResponse.body) as List;
        _priorities = prioritiesData.map((priority) => {
          'id': priority['id'],
          'name': priority['name'],
          'description': priority['description'] ?? 'Eisenhower Matrix Priority',
          'color': priority['color'] ?? 'Blue',
          'order': priority['order'] ?? priority['id'],
          'matrix_quadrant': priority['matrix_quadrant'] ?? '',
        }).toList();
      }

      if (statusesResponse.statusCode == 200) {
        final statusesData = jsonDecode(statusesResponse.body) as List;
        _statuses = statusesData.map((status) => {
          'id': status['id'],
          'name': status['name'],
          'description': status['description'] ?? 'Task status',
          'color': status['color'] ?? 'Blue',
          'is_active': status['is_active'] ?? true,
        }).toList();
      }

      if (taskTypesResponse.statusCode == 200) {
        final taskTypesData = jsonDecode(taskTypesResponse.body) as List;
        _categories = taskTypesData.map((taskType) => {
          'id': taskType['id'],
          'name': taskType['name'],
          'description': taskType['description'] ?? 'Task type category',
          'color': taskType['color'] ?? 'Blue',
        }).toList();
      }

    } catch (e) {
      print('Error loading master data: $e');
      _showErrorMessage('Error loading master data: $e');
    }

    setState(() => _isLoading = false);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE6920E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Breadcrumb
        Breadcrumb(
          items: getAdminBreadcrumbs('master-data'),
        ),

        // Main content
        Expanded(
          child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFFFFA301), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Master Data Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadMasterData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA301),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.priority_high),
                      SizedBox(width: 8),
                      Text('Priorities'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag),
                      SizedBox(width: 8),
                      Text('Statuses'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category),
                      SizedBox(width: 8),
                      Text('Categories'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPrioritiesTab(),
                      _buildStatusesTab(),
                      _buildCategoriesTab(),
                    ],
                  ),
          ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritiesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Task Priorities (Eisenhower Matrix)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddPriorityDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Priority'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA301),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _priorities.length,
              itemBuilder: (context, index) {
                final priority = _priorities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColorFromName(priority['color']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${priority['order']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    title: Text(priority['name']),
                    subtitle: Text(priority['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editPriority(priority),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deletePriority(priority['id']),
                          icon: const Icon(Icons.delete, color: Color(0xFFE6920E)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Task Statuses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddStatusDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA301),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColorFromName(status['color']),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.flag),
                    ),
                    title: Text(status['name']),
                    subtitle: Text(status['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editStatus(status),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteStatus(status['id']),
                          icon: const Icon(Icons.delete, color: Color(0xFFE6920E)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Project Categories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA301),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.category, color: Color(0xFFFFA301)),
                    title: Text(category['name']),
                    subtitle: Text(category['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editCategory(category),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteCategory(category['id']),
                          icon: const Icon(Icons.delete, color: Color(0xFFE6920E)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'teal':
        return Colors.teal;
      case 'indigo':
        return Colors.indigo;
      case 'pink':
        return Colors.pink;
      case 'brown':
        return Colors.brown;
      case 'grey':
        return Colors.grey;
      case 'white':
      default:
        return Colors.white;
    }
  }

  String _getColorName(Color color) {
    if (color == Colors.orange) return 'Orange';
    if (color == Colors.yellow) return 'Yellow';
    if (color == Colors.green) return 'Green';
    if (color == Colors.red) return 'Red';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.teal) return 'Teal';
    if (color == Colors.indigo) return 'Indigo';
    if (color == Colors.pink) return 'Pink';
    if (color == Colors.brown) return 'Brown';
    if (color == Colors.grey) return 'Grey';
    return 'White';
  }

  List<Color> get _availableColors => [
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.red,
    Colors.blue,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.brown,
    Colors.grey,
    Colors.white,
  ];

  Widget _buildColorPicker(Color selectedColor, Function(Color) onColorSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = color == selectedColor;
            return GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFA301) : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAddPriorityDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Priority'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Priority Name',
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
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildColorPicker(selectedColor, (color) {
                setDialogState(() {
                  selectedColor = color;
                });
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Priority name is required')),
                );
                return;
              }

              Navigator.of(context).pop();
              _addPriority(nameController.text.trim(), descriptionController.text.trim(), selectedColor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA301)),
            child: const Text('Add'),
          ),
        ],
        ),
      ),
    );
  }

  void _addPriority(String name, String description, Color color) {
    // For now, add to local list (API implementation would go here)
    setState(() {
      _priorities.add({
        'id': _priorities.length + 1,
        'name': name,
        'description': description,
        'color': _getColorName(color),
        'order': _priorities.length + 1,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Priority added successfully'), backgroundColor: Color(0xFFFFA301)),
    );
  }

  void _editPriority(Map<String, dynamic> priority) {
    final nameController = TextEditingController(text: priority['name']);
    final descriptionController = TextEditingController(text: priority['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Priority'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Priority Name',
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
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Priority name is required')),
                );
                return;
              }

              Navigator.of(context).pop();
              _updatePriority(priority['id'], nameController.text.trim(), descriptionController.text.trim());
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updatePriority(int id, String name, String description) {
    // Update in local list (API implementation would go here)
    setState(() {
      final index = _priorities.indexWhere((p) => p['id'] == id);
      if (index != -1) {
        _priorities[index] = {
          ..._priorities[index],
          'name': name,
          'description': description,
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Priority updated successfully'), backgroundColor: Color(0xFFFFA301)),
    );
  }

  void _deletePriority(int id) {
    // TODO: Implement delete priority
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Priority functionality - Coming Soon')),
    );
  }

  void _showAddStatusDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Status'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Status Name *',
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
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildColorPicker(selectedColor, (color) {
                  setDialogState(() {
                    selectedColor = color;
                  });
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Status name is required')),
                  );
                  return;
                }

                Navigator.of(context).pop();
                _addStatus(nameController.text.trim(), descriptionController.text.trim(), selectedColor);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA301)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addStatus(String name, String description, Color color) {
    // TODO: Implement API call to add status
    setState(() {
      _statuses.add({
        'id': _statuses.length + 1,
        'name': name,
        'description': description,
        'color': _getColorName(color),
        'is_active': true,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status added successfully'), backgroundColor: Color(0xFFFFA301)),
    );
  }

  void _editStatus(Map<String, dynamic> status) {
    final nameController = TextEditingController(text: status['name']);
    final descriptionController = TextEditingController(text: status['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Status'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Status Name',
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
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Status name is required')),
                );
                return;
              }

              Navigator.of(context).pop();
              _updateStatus(status['id'], nameController.text.trim(), descriptionController.text.trim());
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(int id, String name, String description) {
    // Update in local list (API implementation would go here)
    setState(() {
      final index = _statuses.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _statuses[index] = {
          ..._statuses[index],
          'name': name,
          'description': description,
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status updated successfully'), backgroundColor: Color(0xFFFFA301)),
    );
  }

  void _deleteStatus(int id) {
    // TODO: Implement delete status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Status functionality - Coming Soon')),
    );
  }

  void _showAddCategoryDialog() {
    // TODO: Implement add category dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Category functionality - Coming Soon')),
    );
  }

  void _editCategory(Map<String, dynamic> category) {
    final nameController = TextEditingController(text: category['name']);
    final descriptionController = TextEditingController(text: category['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
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
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name is required')),
                );
                return;
              }

              Navigator.of(context).pop();
              _updateCategory(category['id'], nameController.text.trim(), descriptionController.text.trim());
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updateCategory(int id, String name, String description) {
    // Update in local list (API implementation would go here)
    setState(() {
      final index = _categories.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        _categories[index] = {
          ..._categories[index],
          'name': name,
          'description': description,
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category updated successfully'), backgroundColor: Color(0xFFFFA301)),
    );
  }

  void _deleteCategory(int id) {
    // TODO: Implement delete category
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Category functionality - Coming Soon')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
