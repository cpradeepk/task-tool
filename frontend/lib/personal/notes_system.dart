import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class NotesSystemScreen extends StatefulWidget {
  const NotesSystemScreen({super.key});

  @override
  State<NotesSystemScreen> createState() => _NotesSystemScreenState();
}

class _NotesSystemScreenState extends State<NotesSystemScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  List<dynamic> _notes = [];
  List<dynamic> _filteredNotes = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _editingNoteId;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Work', 'Personal', 'Ideas', 'Meeting Notes', 'Tasks'];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/notes'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _notes = jsonDecode(response.body));
      } else {
        setState(() => _notes = _generateMockNotes());
      }
    } catch (e) {
      setState(() => _notes = _generateMockNotes());
    } finally {
      setState(() => _isLoading = false);
      _filterNotes();
    }
  }

  List<dynamic> _generateMockNotes() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'title': 'Project Planning Meeting',
        'content': 'Discussed the new task management system requirements:\n- User authentication with PIN\n- Admin dashboard with reporting\n- PERT analysis for project planning\n- Calendar integration\n\nNext steps:\n- Complete wireframes by Friday\n- Setup development environment',
        'category': 'Meeting Notes',
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'tags': ['project', 'planning', 'meeting'],
      },
      {
        'id': 2,
        'title': 'Flutter Development Tips',
        'content': 'Key learnings from Flutter development:\n\n1. State Management:\n- Use setState for simple state\n- Consider Provider or Riverpod for complex state\n- Always dispose controllers\n\n2. Performance:\n- Use const constructors where possible\n- Avoid rebuilding widgets unnecessarily\n- Use ListView.builder for large lists\n\n3. UI Best Practices:\n- Follow Material Design guidelines\n- Ensure proper contrast ratios\n- Test on different screen sizes',
        'category': 'Work',
        'created_at': now.subtract(const Duration(days: 5)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'tags': ['flutter', 'development', 'tips'],
      },
      {
        'id': 3,
        'title': 'Weekend Project Ideas',
        'content': 'Ideas for weekend coding projects:\n\n1. Personal Finance Tracker\n- Track expenses and income\n- Generate monthly reports\n- Set budget goals\n\n2. Recipe Manager\n- Store favorite recipes\n- Plan weekly meals\n- Generate shopping lists\n\n3. Habit Tracker\n- Track daily habits\n- Visualize progress\n- Set reminders',
        'category': 'Ideas',
        'created_at': now.subtract(const Duration(days: 7)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 7)).toIso8601String(),
        'tags': ['projects', 'ideas', 'coding'],
      },
      {
        'id': 4,
        'title': 'Daily Standup Notes',
        'content': 'Today\'s standup:\n\nWhat I did yesterday:\n- Completed user authentication module\n- Fixed routing issues in admin panel\n- Updated documentation\n\nWhat I\'m doing today:\n- Implement PERT analysis feature\n- Add calendar functionality\n- Code review for team members\n\nBlockers:\n- Waiting for API documentation from backend team',
        'category': 'Work',
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'updated_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'tags': ['standup', 'daily', 'work'],
      },
    ];
  }

  void _filterNotes() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        final matchesCategory = _selectedCategory == 'All' || note['category'] == _selectedCategory;
        final matchesSearch = _searchController.text.isEmpty ||
            note['title'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
            note['content'].toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
      
      // Sort by updated_at descending
      _filteredNotes.sort((a, b) => DateTime.parse(b['updated_at']).compareTo(DateTime.parse(a['updated_at'])));
    });
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      _showErrorMessage('Please fill in both title and content');
      return;
    }

    final jwt = await _getJwt();
    if (jwt == null) return;

    final noteData = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _selectedCategory == 'All' ? 'Work' : _selectedCategory,
    };

    try {
      http.Response response;
      if (_editingNoteId != null) {
        response = await http.put(
          Uri.parse('$apiBase/task/api/notes/$_editingNoteId'),
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(noteData),
        );
      } else {
        response = await http.post(
          Uri.parse('$apiBase/task/api/notes'),
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(noteData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessMessage(_editingNoteId != null ? 'Note updated successfully' : 'Note created successfully');
        _clearForm();
        _loadNotes();
      } else {
        // For demo, add/update locally
        final now = DateTime.now().toIso8601String();
        if (_editingNoteId != null) {
          final index = _notes.indexWhere((n) => n['id'] == _editingNoteId);
          if (index != -1) {
            _notes[index] = {
              ..._notes[index],
              ...noteData,
              'updated_at': now,
            };
          }
        } else {
          _notes.insert(0, {
            'id': _notes.length + 1,
            ...noteData,
            'created_at': now,
            'updated_at': now,
            'tags': [],
          });
        }
        _clearForm();
        _filterNotes();
        _showSuccessMessage(_editingNoteId != null ? 'Note updated successfully' : 'Note created successfully');
      }
    } catch (e) {
      // For demo, add/update locally
      final now = DateTime.now().toIso8601String();
      if (_editingNoteId != null) {
        final index = _notes.indexWhere((n) => n['id'] == _editingNoteId);
        if (index != -1) {
          _notes[index] = {
            ..._notes[index],
            ...noteData,
            'updated_at': now,
          };
        }
      } else {
        _notes.insert(0, {
          'id': _notes.length + 1,
          ...noteData,
          'created_at': now,
          'updated_at': now,
          'tags': [],
        });
      }
      _clearForm();
      _filterNotes();
      _showSuccessMessage(_editingNoteId != null ? 'Note updated successfully' : 'Note created successfully');
    }
  }

  Future<void> _deleteNote(int noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      await http.delete(
        Uri.parse('$apiBase/task/api/notes/$noteId'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      _showSuccessMessage('Note deleted successfully');
      _loadNotes();
    } catch (e) {
      // For demo, delete locally
      setState(() {
        _notes.removeWhere((n) => n['id'] == noteId);
      });
      _filterNotes();
      _showSuccessMessage('Note deleted successfully');
    }
  }

  void _editNote(Map<String, dynamic> note) {
    setState(() {
      _editingNoteId = note['id'];
      _titleController.text = note['title'];
      _contentController.text = note['content'];
      _selectedCategory = note['category'];
    });
  }

  void _clearForm() {
    setState(() {
      _editingNoteId = null;
      _titleController.clear();
      _contentController.clear();
      _selectedCategory = 'Work';
    });
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'My Notes',
      child: Row(
        children: [
          // Notes List
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header with search and filters
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.note, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'My Notes',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${_filteredNotes.length} notes',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search notes...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => _filterNotes(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedCategory,
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedCategory = value!);
                                _filterNotes();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Notes List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredNotes.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.note_add, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('No notes found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                                    Text('Create your first note!', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredNotes.length,
                                itemBuilder: (context, index) {
                                  final note = _filteredNotes[index];
                                  return _buildNoteCard(note);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          // Note Editor
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Editor Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _editingNoteId != null ? Icons.edit : Icons.add,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _editingNoteId != null ? 'Edit Note' : 'Create New Note',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_editingNoteId != null)
                          TextButton(
                            onPressed: _clearForm,
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                  ),
                  // Editor Form
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Note Title',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory == 'All' ? 'Work' : _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _categories.where((c) => c != 'All').map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value!),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              decoration: const InputDecoration(
                                labelText: 'Note Content',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveNote,
                              icon: Icon(_editingNoteId != null ? Icons.save : Icons.add),
                              label: Text(_editingNoteId != null ? 'Update Note' : 'Create Note'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final createdAt = DateTime.parse(note['created_at']);
    final updatedAt = DateTime.parse(note['updated_at']);
    final isUpdated = createdAt != updatedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          note['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note['content'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(note['category']),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    note['category'],
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isUpdated ? 'Updated ${_formatDate(updatedAt)}' : 'Created ${_formatDate(createdAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editNote(note),
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit Note',
            ),
            IconButton(
              onPressed: () => _deleteNote(note['id']),
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              tooltip: 'Delete Note',
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blue;
      case 'Personal':
        return Colors.green;
      case 'Ideas':
        return Colors.purple;
      case 'Meeting Notes':
        return Colors.orange;
      case 'Tasks':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
