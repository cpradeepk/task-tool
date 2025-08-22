import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../modern_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() => _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState extends State<AvailabilityManagementScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _availabilitySlots = [];
  
  // Form controllers for adding new availability
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(hours: 8));
  String _selectedType = 'Available';
  String _selectedLocation = 'Office';

  final List<String> _availabilityTypes = [
    'Available',
    'Busy',
    'Out of Office',
    'Working from Home',
    'In Meeting',
    'On Leave',
  ];

  final List<String> _locationTypes = [
    'Office',
    'Home',
    'Remote',
    'Client Site',
    'Travel',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        final response = await http.get(
          Uri.parse('$apiBase/task/api/user/availability'),
          headers: {'Authorization': 'Bearer $jwt'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List<dynamic>;
          setState(() {
            _availabilitySlots = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      print('Error loading availability: $e');
      setState(() {
        _availabilitySlots = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorMessage('Please enter a title');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      final availabilityData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'location': _selectedLocation,
        'start_date': _selectedStartDate.toIso8601String(),
        'end_date': _selectedEndDate.toIso8601String(),
      };

      if (jwt != null) {
        final response = await http.post(
          Uri.parse('$apiBase/task/api/user/availability'),
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(availabilityData),
        );

        if (response.statusCode == 201) {
          _showSuccessMessage('Availability added successfully');
          _clearForm();
          _loadAvailability();
        } else {
          _showErrorMessage('Failed to add availability');
        }
      } else {
        _showErrorMessage('Authentication required');
      }
    } catch (e) {
      _showErrorMessage('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedStartDate = DateTime.now();
      _selectedEndDate = DateTime.now().add(const Duration(hours: 8));
      _selectedType = 'Available';
      _selectedLocation = 'Office';
    });
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Available':
        return const Color(0xFFE6920E);
      case 'Busy':
        return const Color(0xFFFFA301);
      case 'Out of Office':
        return const Color(0xFFB37200);
      case 'Working from Home':
        return const Color(0xFFFFCA1A);
      case 'In Meeting':
        return const Color(0xFFCC8200);
      case 'On Leave':
        return const Color(0xFFA0A0A0);
      default:
        return const Color(0xFFA0A0A0);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Available':
        return Icons.check_circle;
      case 'Busy':
        return Icons.schedule;
      case 'Out of Office':
        return Icons.cancel;
      case 'Working from Home':
        return Icons.home;
      case 'In Meeting':
        return Icons.meeting_room;
      case 'On Leave':
        return Icons.beach_access;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
      title: 'Availability Management',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Manage Your Availability',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set your availability for work scheduling and team coordination',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Add New Availability Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Availability',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          // Title and Description
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.title),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description (Optional)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.description),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Type and Location
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Type',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.category),
                                  ),
                                  value: _selectedType,
                                  items: _availabilityTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Row(
                                        children: [
                                          Icon(_getTypeIcon(type), size: 16, color: _getTypeColor(type)),
                                          const SizedBox(width: 8),
                                          Text(type),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedType = value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Location',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.location_on),
                                  ),
                                  value: _selectedLocation,
                                  items: _locationTypes.map((location) {
                                    return DropdownMenuItem(value: location, child: Text(location));
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedLocation = value!);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Date and Time Selection
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedStartDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(_selectedStartDate),
                                      );
                                      if (time != null) {
                                        setState(() {
                                          _selectedStartDate = DateTime(
                                            date.year, date.month, date.day,
                                            time.hour, time.minute,
                                          );
                                        });
                                      }
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date & Time',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(
                                      '${_selectedStartDate.day}/${_selectedStartDate.month}/${_selectedStartDate.year} ${_selectedStartDate.hour.toString().padLeft(2, '0')}:${_selectedStartDate.minute.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedEndDate,
                                      firstDate: _selectedStartDate,
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(_selectedEndDate),
                                      );
                                      if (time != null) {
                                        setState(() {
                                          _selectedEndDate = DateTime(
                                            date.year, date.month, date.day,
                                            time.hour, time.minute,
                                          );
                                        });
                                      }
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date & Time',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time_filled),
                                    ),
                                    child: Text(
                                      '${_selectedEndDate.day}/${_selectedEndDate.month}/${_selectedEndDate.year} ${_selectedEndDate.hour.toString().padLeft(2, '0')}:${_selectedEndDate.minute.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Add Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveAvailability,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Availability'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current Availability List
                  const Text(
                    'Current Availability',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: _availabilitySlots.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No availability slots set',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add your first availability slot above',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _availabilitySlots.length,
                            itemBuilder: (context, index) {
                              final slot = _availabilitySlots[index];
                              final startDate = DateTime.parse(slot['start_date']);
                              final endDate = DateTime.parse(slot['end_date']);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getTypeColor(slot['type']),
                                    child: Icon(
                                      _getTypeIcon(slot['type']),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    slot['title'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (slot['description'] != null && slot['description'].isNotEmpty)
                                        Text(slot['description']),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${startDate.day}/${startDate.month} ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')} - ${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            slot['location'],
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteAvailability(slot['id']);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
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

  Future<void> _deleteAvailability(int id) async {
    try {
      final jwt = await _getJwt();

      if (jwt != null) {
        final response = await http.delete(
          Uri.parse('$apiBase/task/api/user/availability/$id'),
          headers: {'Authorization': 'Bearer $jwt'},
        );

        if (response.statusCode == 200) {
          _showSuccessMessage('Availability deleted successfully');
          _loadAvailability();
        } else {
          _showErrorMessage('Failed to delete availability');
        }
      } else {
        // Demo mode - remove from local list
        setState(() {
          _availabilitySlots.removeWhere((slot) => slot['id'] == id);
        });
        _showSuccessMessage('Availability deleted successfully (Demo Mode)');
      }
    } catch (e) {
      _showErrorMessage('Error: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
