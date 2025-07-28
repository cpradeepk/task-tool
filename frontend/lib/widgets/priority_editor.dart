import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PriorityEditor extends StatefulWidget {
  final String entityType; // 'PROJECT', 'TASK', 'MODULE'
  final String entityId;
  final String entityName;
  final String currentPriority;
  final int? currentPriorityNumber;
  final VoidCallback? onPriorityChanged;

  const PriorityEditor({
    Key? key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.currentPriority,
    this.currentPriorityNumber,
    this.onPriorityChanged,
  }) : super(key: key);

  @override
  State<PriorityEditor> createState() => _PriorityEditorState();
}

class _PriorityEditorState extends State<PriorityEditor> {
  String _selectedPriority = 'NOT_IMPORTANT_NOT_URGENT';
  int _priorityNumber = 1;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  final Map<String, String> _priorityLabels = {
    'IMPORTANT_URGENT': 'Important & Urgent',
    'IMPORTANT_NOT_URGENT': 'Important & Not Urgent',
    'NOT_IMPORTANT_URGENT': 'Not Important & Urgent',
    'NOT_IMPORTANT_NOT_URGENT': 'Not Important & Not Urgent',
  };

  final Map<String, Color> _priorityColors = {
    'IMPORTANT_URGENT': Colors.red,
    'IMPORTANT_NOT_URGENT': Colors.orange,
    'NOT_IMPORTANT_URGENT': Colors.yellow,
    'NOT_IMPORTANT_NOT_URGENT': Colors.grey,
  };

  final Map<String, String> _priorityDescriptions = {
    'IMPORTANT_URGENT': 'Critical tasks requiring immediate attention',
    'IMPORTANT_NOT_URGENT': 'Strategic tasks for long-term success',
    'NOT_IMPORTANT_URGENT': 'Interruptions and distractions to minimize',
    'NOT_IMPORTANT_NOT_URGENT': 'Activities to eliminate or delegate',
  };

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.currentPriority;
    _priorityNumber = widget.currentPriorityNumber ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.priority_high, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Priority',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${widget.entityType}: ${widget.entityName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

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

            // Current Priority Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('Current Priority: '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _priorityColors[widget.currentPriority],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _priorityLabels[widget.currentPriority] ?? widget.currentPriority,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('(#${widget.currentPriorityNumber ?? 1})'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Priority Matrix Selection
            Text(
              'Select New Priority',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Priority Matrix Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: _priorityLabels.entries.map((entry) {
                final priority = entry.key;
                final label = entry.value;
                final isSelected = _selectedPriority == priority;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPriority = priority;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? _priorityColors[priority] : Colors.white,
                      border: Border.all(
                        color: _priorityColors[priority]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : _priorityColors[priority],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _priorityDescriptions[priority]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white70 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Priority Number Selection
            Row(
              children: [
                const Text('Priority Number: '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<int>(
                    value: _priorityNumber,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    items: List.generate(10, (index) => index + 1)
                        .map((number) => DropdownMenuItem(
                              value: number,
                              child: Text('#$number'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _priorityNumber = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '(1 = highest priority within category)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason for Change
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Priority Change (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Explain why this priority change is needed...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPriorityChange,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Priority'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPriorityChange() async {
    // Check if there's actually a change
    if (_selectedPriority == widget.currentPriority && 
        _priorityNumber == (widget.currentPriorityNumber ?? 1)) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await ApiService.updatePriority(
        widget.entityType.toLowerCase(),
        widget.entityId,
        _selectedPriority,
        _priorityNumber,
        _reasonController.text.trim(),
      );

      Navigator.of(context).pop();

      if (widget.onPriorityChanged != null) {
        widget.onPriorityChanged!();
      }

      // Show success message
      final needsApproval = response['needsApproval'] ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsApproval
                ? 'Priority change submitted for approval'
                : 'Priority updated successfully',
          ),
          backgroundColor: needsApproval ? Colors.orange : Colors.green,
          action: needsApproval
              ? SnackBarAction(
                  label: 'View Requests',
                  onPressed: () {
                    // Navigate to priority change requests
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to update priority: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}

// Priority Change Requests Screen
class PriorityChangeRequestsScreen extends StatefulWidget {
  const PriorityChangeRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PriorityChangeRequestsScreen> createState() => _PriorityChangeRequestsScreenState();
}

class _PriorityChangeRequestsScreenState extends State<PriorityChangeRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'PENDING';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final requests = await ApiService.getPriorityChangeRequests(_statusFilter);
      
      setState(() {
        _requests = List<Map<String, dynamic>>.from(requests);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load requests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reviewRequest(String requestId, String action) async {
    try {
      await ApiService.reviewPriorityChange(requestId, action);
      await _loadRequests();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${action.toLowerCase()}d successfully'),
          backgroundColor: action == 'APPROVE' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $action request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Change Requests'),
        actions: [
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
              DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value!;
              });
              _loadRequests();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _requests.isEmpty
                  ? const Center(child: Text('No requests found'))
                  : ListView.builder(
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            title: Text('${request['entityType']}: ${request['entityDetails']?['name'] ?? 'Unknown'}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Requested by: ${request['changer']['name']}'),
                                Text('From: ${request['oldPriority']} → To: ${request['newPriority']}'),
                                if (request['reason'] != null)
                                  Text('Reason: ${request['reason']}'),
                              ],
                            ),
                            trailing: request['status'] == 'PENDING'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        onPressed: () => _reviewRequest(request['id'], 'APPROVE'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => _reviewRequest(request['id'], 'REJECT'),
                                      ),
                                    ],
                                  )
                                : Text(request['status']),
                          ),
                        );
                      },
                    ),
    );
  }
}
