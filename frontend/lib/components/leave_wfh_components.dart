import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';
import 'professional_card.dart';
import 'professional_buttons.dart';
import 'animations.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

/// Leave application form component
class LeaveApplicationForm extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const LeaveApplicationForm({
    super.key,
    this.onSubmitted,
  });

  @override
  State<LeaveApplicationForm> createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  String _selectedLeaveType = 'Annual Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  
  final List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Personal Leave',
    'Emergency Leave',
    'Maternity Leave',
    'Paternity Leave',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.event_busy,
                  color: DesignTokens.primaryOrange,
                  size: 24,
                ),
                const SizedBox(width: DesignTokens.spacing12),
                Text(
                  'Apply for Leave',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.colors['black'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing20),
            
            // Leave type dropdown
            DropdownButtonFormField<String>(
              value: _selectedLeaveType,
              decoration: const InputDecoration(
                labelText: 'Leave Type *',
                prefixIcon: Icon(Icons.category),
              ),
              items: _leaveTypes.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedLeaveType = value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a leave type';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Date range selection
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Select start date',
                        style: TextStyle(
                          color: _startDate != null
                              ? DesignTokens.colors['black']
                              : DesignTokens.colors['gray500'],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing16),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Select end date',
                        style: TextStyle(
                          color: _endDate != null
                              ? DesignTokens.colors['black']
                              : DesignTokens.colors['gray500'],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Duration display
            if (_startDate != null && _endDate != null)
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing12),
                decoration: BoxDecoration(
                  color: DesignTokens.colors['primary50'],
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                  border: Border.all(color: DesignTokens.primaryOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: DesignTokens.primaryOrange,
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Text(
                      'Duration: ${_calculateDuration()} day${_calculateDuration() != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Reason text field
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Please provide a reason for your leave',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason for your leave';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spacing24),
            
            // Submit button
            Row(
              children: [
                const Spacer(),
                ProfessionalButton(
                  text: 'Submit Application',
                  isLoading: _isSubmitting,
                  onPressed: _submitLeaveApplication,
                  icon: Icons.send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _startDate = date;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date first')),
      );
      return;
    }
    
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  int _calculateDuration() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.post(
        Uri.parse('$apiBase/task/api/leaves'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'leave_type': _selectedLeaveType,
          'start_date': _startDate!.toIso8601String().split('T')[0],
          'end_date': _endDate!.toIso8601String().split('T')[0],
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave application submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
          widget.onSubmitted?.call();
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to submit leave application';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _reasonController.clear();
    setState(() {
      _selectedLeaveType = 'Annual Leave';
      _startDate = null;
      _endDate = null;
    });
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }
}

/// WFH application form component
class WFHApplicationForm extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const WFHApplicationForm({
    super.key,
    this.onSubmitted,
  });

  @override
  State<WFHApplicationForm> createState() => _WFHApplicationFormState();
}

class _WFHApplicationFormState extends State<WFHApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.home_work,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: DesignTokens.spacing12),
                Text(
                  'Apply for Work From Home',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.colors['black'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing20),
            
            // Date selection
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'WFH Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select WFH date',
                  style: TextStyle(
                    color: _selectedDate != null
                        ? DesignTokens.colors['black']
                        : DesignTokens.colors['gray500'],
                  ),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Reason text field
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Please provide a reason for WFH request',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason for your WFH request';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spacing24),
            
            // Submit button
            Row(
              children: [
                const Spacer(),
                ProfessionalButton(
                  text: 'Submit Request',
                  isLoading: _isSubmitting,
                  onPressed: _submitWFHRequest,
                  icon: Icons.send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitWFHRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.post(
        Uri.parse('$apiBase/task/api/wfh'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': _selectedDate!.toIso8601String().split('T')[0],
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WFH request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
          widget.onSubmitted?.call();
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to submit WFH request';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _reasonController.clear();
    setState(() {
      _selectedDate = null;
    });
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }
}

/// Leave/WFH request card component
class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String type; // 'leave' or 'wfh'
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions;

  const RequestCard({
    super.key,
    required this.request,
    required this.type,
    this.onApprove,
    this.onReject,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              Icon(
                type == 'leave' ? Icons.event_busy : Icons.home_work,
                color: type == 'leave' ? DesignTokens.primaryOrange : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Expanded(
                child: Text(
                  type == 'leave' 
                      ? request['leave_type'] ?? 'Leave Request'
                      : 'Work From Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.colors['black'],
                  ),
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Employee info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: DesignTokens.primaryOrange,
                child: Text(
                  (request['employee_name'] ?? request['employee_email'] ?? 'U')
                      .substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: DesignTokens.colors['black'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['employee_name'] ?? request['employee_email'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.colors['black'],
                      ),
                    ),
                    if (request['employee_email'] != null)
                      Text(
                        request['employee_email'],
                        style: TextStyle(
                          fontSize: 12,
                          color: DesignTokens.colors['gray600'],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          
          // Date info
          _buildDateInfo(),
          
          // Reason
          if (request['reason'] != null && request['reason'].isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              'Reason: ${request['reason']}',
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.colors['gray700'],
              ),
            ),
          ],
          
          // Approval info
          if (request['approved_by_name'] != null) ...[
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              'Processed by: ${request['approved_by_name']}',
              style: TextStyle(
                fontSize: 12,
                color: DesignTokens.colors['gray600'],
              ),
            ),
          ],
          
          // Actions
          if (showActions && request['status'] == 'pending') ...[
            const SizedBox(height: DesignTokens.spacing16),
            Row(
              children: [
                const Spacer(),
                ProfessionalButton(
                  text: 'Reject',
                  size: ButtonSize.small,
                  variant: ButtonVariant.outline,
                  onPressed: onReject,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                ProfessionalButton(
                  text: 'Approve',
                  size: ButtonSize.small,
                  onPressed: onApprove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = request['status'] ?? 'pending';
    Color color;
    
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'pending':
        color = DesignTokens.primaryOrange;
        break;
      default:
        color = DesignTokens.colors['gray500']!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing8,
        vertical: DesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDateInfo() {
    if (type == 'leave') {
      return Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: DesignTokens.colors['gray500'],
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            '${_formatDate(request['start_date'])} - ${_formatDate(request['end_date'])}',
            style: TextStyle(
              fontSize: 14,
              color: DesignTokens.colors['gray700'],
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: DesignTokens.colors['gray500'],
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            _formatDate(request['date']),
            style: TextStyle(
              fontSize: 14,
              color: DesignTokens.colors['gray700'],
            ),
          ),
        ],
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
