import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class TaggingSystemScreen extends StatefulWidget {
  const TaggingSystemScreen({super.key});

  @override
  State<TaggingSystemScreen> createState() => _TaggingSystemScreenState();
}

class _TaggingSystemScreenState extends State<TaggingSystemScreen> {
  List<dynamic> _tags = [];
  List<dynamic> _filteredTags = [];
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String _selectedCategory = 'All';
  Color _selectedColor = Colors.blue;
  int? _editingTagId;

  final List<String> _categories = [
    'All', 'Project', 'Module', 'Task', 'Subtask', 'Note', 'Priority', 'Status', 'General'
  ];

  final List<Color> _tagColors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple,
    Colors.teal, Colors.indigo, Colors.pink, Colors.amber, Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_filterTags);
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        final response = await http.get(
          Uri.parse('$apiBase/task/api/admin/tags'),
          headers: {'Authorization': 'Bearer $jwt'},
        );

        if (response.statusCode == 200) {
          setState(() => _tags = jsonDecode(response.body));
        }
      }
    } catch (e) {
      // Use mock tags for development
      setState(() => _tags = _generateMockTags());
    } finally {
      setState(() => _isLoading = false);
      _filterTags();
    }
  }

  List<dynamic> _generateMockTags() {
    return [
      {
        'id': 1,
        'name': 'urgent',
        'description': 'High priority tasks requiring immediate attention',
        'category': 'Priority',
        'color': Colors.red.value,
        'usage_count': 25,
        'created_at': '2025-01-10',
      },
      {
        'id': 2,
        'name': 'frontend',
        'description': 'Frontend development related tasks',
        'category': 'Project',
        'color': Colors.blue.value,
        'usage_count': 18,
        'created_at': '2025-01-12',
      },
      {
        'id': 3,
        'name': 'backend',
        'description': 'Backend development and API tasks',
        'category': 'Project',
        'color': Colors.green.value,
        'usage_count': 22,
        'created_at': '2025-01-12',
      },
      {
        'id': 4,
        'name': 'bug-fix',
        'description': 'Bug fixes and issue resolution',
        'category': 'Task',
        'color': Colors.orange.value,
        'usage_count': 15,
        'created_at': '2025-01-14',
      },
      {
        'id': 5,
        'name': 'enhancement',
        'description': 'Feature enhancements and improvements',
        'category': 'Task',
        'color': Colors.purple.value,
        'usage_count': 12,
        'created_at': '2025-01-15',
      },
      {
        'id': 6,
        'name': 'documentation',
        'description': 'Documentation and knowledge base',
        'category': 'General',
        'color': Colors.teal.value,
        'usage_count': 8,
        'created_at': '2025-01-16',
      },
      {
        'id': 7,
        'name': 'testing',
        'description': 'Testing and quality assurance',
        'category': 'Task',
        'color': Colors.indigo.value,
        'usage_count': 10,
        'created_at': '2025-01-16',
      },
      {
        'id': 8,
        'name': 'meeting-notes',
        'description': 'Notes from meetings and discussions',
        'category': 'Note',
        'color': Colors.pink.value,
        'usage_count': 6,
        'created_at': '2025-01-17',
      },
    ];
  }

  void _filterTags() {
    setState(() {
      _filteredTags = _tags.where((tag) {
        final matchesCategory = _selectedCategory == 'All' || tag['category'] == _selectedCategory;
        final matchesSearch = _searchController.text.isEmpty ||
            tag['name'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
            tag['description'].toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _showCreateTagDialog() {
    _editingTagId = null;
    _nameController.clear();
    _descriptionController.clear();
    _selectedColor = Colors.blue;
    _showTagDialog('Create Tag');
  }

  void _showEditTagDialog(Map<String, dynamic> tag) {
    _editingTagId = tag['id'];
    _nameController.text = tag['name'];
    _descriptionController.text = tag['description'] ?? '';
    _selectedColor = Color(tag['color']);
    _showTagDialog('Edit Tag');
  }

  void _showTagDialog(String title) {
    String selectedCategory = _editingTagId == null ? 'General' : 
        _tags.firstWhere((t) => t['id'] == _editingTagId)['category'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tag Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.skip(1).map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tagColors.map((color) {
                    final isSelected = _selectedColor.value == color.value;
                    return GestureDetector(
                      onTap: () => setDialogState(() => _selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
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
                if (_nameController.text.trim().isNotEmpty) {
                  _saveTag(selectedCategory);
                  Navigator.of(context).pop();
                }
              },
              child: Text(_editingTagId == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTag(String category) {
    final tagData = {
      'id': _editingTagId ?? (_tags.length + 1),
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': category,
      'color': _selectedColor.value,
      'usage_count': _editingTagId == null ? 0 : 
          _tags.firstWhere((t) => t['id'] == _editingTagId)['usage_count'],
      'created_at': _editingTagId == null ? DateTime.now().toIso8601String().substring(0, 10) :
          _tags.firstWhere((t) => t['id'] == _editingTagId)['created_at'],
    };

    setState(() {
      if (_editingTagId == null) {
        _tags.add(tagData);
      } else {
        final index = _tags.indexWhere((t) => t['id'] == _editingTagId);
        if (index != -1) {
          _tags[index] = tagData;
        }
      }
    });

    _filterTags();
    _showSuccessMessage(_editingTagId == null ? 'Tag created successfully' : 'Tag updated successfully');
  }

  void _deleteTag(Map<String, dynamic> tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Are you sure you want to delete the tag "${tag['name']}"?\n\nThis tag is used in ${tag['usage_count']} items.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _tags.removeWhere((t) => t['id'] == tag['id']));
              _filterTags();
              Navigator.of(context).pop();
              _showSuccessMessage('Tag deleted successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Tag Management',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.label, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Tag Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showCreateTagDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Tag'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Row(
              children: [
                // Search
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search tags...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterTags();
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Category filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    value: _selectedCategory,
                    items: _categories.map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                      _filterTags();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tags List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTags.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.label_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No tags found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              Text('Create a new tag or adjust your filters', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredTags.length,
                          itemBuilder: (context, index) {
                            final tag = _filteredTags[index];
                            final color = Color(tag['color']);

                            return Card(
                              elevation: 2,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tag['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              _showEditTagDialog(tag);
                                            } else if (action == 'delete') {
                                              _deleteTag(tag);
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
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, size: 16, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tag['description'] ?? 'No description',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(
                                            tag['category'],
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor: color.withValues(alpha: 0.2),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${tag['usage_count']} uses',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
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
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
