import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/theme_provider.dart';
import 'professional_card.dart';

/// Professional employee ID card component
class EmployeeIdCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final bool showQRCode;
  final bool isPrintable;

  const EmployeeIdCard({
    super.key,
    required this.employee,
    this.showQRCode = true,
    this.isPrintable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isPrintable ? 350 : 320,
      height: isPrintable ? 220 : 200,
      child: ProfessionalCard(
        backgroundColor: Colors.white,
        customShadow: isPrintable ? [] : DesignTokens.cardShadow,
        child: Column(
          children: [
            // Header with company branding
            _buildHeader(),
            
            // Employee details
            Expanded(child: _buildEmployeeDetails()),
            
            // Footer with QR code or additional info
            if (showQRCode) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: DesignTokens.primaryOrange,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DesignTokens.radiusLarge),
          topRight: Radius.circular(DesignTokens.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          Text(
            employee['company'] ?? 'Margadarshi',
            style: TextStyle(
              fontSize: isPrintable ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing4),
          Text(
            'Employee ID Card',
            style: TextStyle(
              fontSize: isPrintable ? 12 : 10,
              color: DesignTokens.colors['black']!.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDetails() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      child: Row(
        children: [
          // Photo section
          _buildPhotoSection(),
          const SizedBox(width: DesignTokens.spacing12),
          
          // Details section
          Expanded(child: _buildDetailsSection()),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Container(
          width: isPrintable ? 80 : 70,
          height: isPrintable ? 80 : 70,
          decoration: BoxDecoration(
            color: DesignTokens.colors['gray200'],
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.colors['gray300']!),
          ),
          child: employee['photo'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                  child: Image.memory(
                    // Decode base64 photo
                    _decodeBase64Photo(employee['photo']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                  ),
                )
              : _buildDefaultAvatar(),
        ),
        const SizedBox(height: DesignTokens.spacing8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing6,
            vertical: DesignTokens.spacing2,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.colors['gray100'],
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          ),
          child: Text(
            'ID: ${employee['employee_id']}',
            style: TextStyle(
              fontSize: isPrintable ? 10 : 8,
              fontWeight: FontWeight.w600,
              color: DesignTokens.colors['gray700'],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    final name = employee['name'] ?? employee['email'] ?? 'User';
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();
    
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.primaryOrange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: isPrintable ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: DesignTokens.primaryOrange,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Name
        Text(
          employee['name'] ?? employee['email'] ?? 'Unknown',
          style: TextStyle(
            fontSize: isPrintable ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: DesignTokens.colors['black'],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: DesignTokens.spacing4),
        
        // Email
        Text(
          employee['email'] ?? '',
          style: TextStyle(
            fontSize: isPrintable ? 12 : 10,
            color: DesignTokens.colors['gray600'],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: DesignTokens.spacing8),
        
        // Roles
        if (employee['roles'] != null && (employee['roles'] as List).isNotEmpty)
          Wrap(
            spacing: DesignTokens.spacing4,
            runSpacing: DesignTokens.spacing4,
            children: (employee['roles'] as List).map((role) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing6,
                vertical: DesignTokens.spacing2,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                role.toString(),
                style: TextStyle(
                  fontSize: isPrintable ? 9 : 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            )).toList(),
          ),
        
        const SizedBox(height: DesignTokens.spacing8),
        
        // Manager
        if (employee['manager'] != null)
          Row(
            children: [
              Icon(
                Icons.supervisor_account,
                size: isPrintable ? 14 : 12,
                color: DesignTokens.colors['gray500'],
              ),
              const SizedBox(width: DesignTokens.spacing4),
              Expanded(
                child: Text(
                  'Manager: ${employee['manager']}',
                  style: TextStyle(
                    fontSize: isPrintable ? 10 : 9,
                    color: DesignTokens.colors['gray600'],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        
        // Hire date
        if (employee['hire_date'] != null)
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: isPrintable ? 14 : 12,
                color: DesignTokens.colors['gray500'],
              ),
              const SizedBox(width: DesignTokens.spacing4),
              Text(
                'Since: ${_formatDate(employee['hire_date'])}',
                style: TextStyle(
                  fontSize: isPrintable ? 10 : 9,
                  color: DesignTokens.colors['gray600'],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing8),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(DesignTokens.radiusLarge),
          bottomRight: Radius.circular(DesignTokens.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          // QR Code
          Container(
            width: isPrintable ? 40 : 35,
            height: isPrintable ? 40 : 35,
            child: QrImageView(
              data: _generateQRData(),
              version: QrVersions.auto,
              size: isPrintable ? 40 : 35,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          
          // Footer info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${employee['status'] ?? 'Active'}',
                  style: TextStyle(
                    fontSize: isPrintable ? 10 : 9,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(employee['status']),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing2),
                Text(
                  'Generated: ${_formatDate(employee['generated_at'])}',
                  style: TextStyle(
                    fontSize: isPrintable ? 9 : 8,
                    color: DesignTokens.colors['gray500'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateQRData() {
    return 'EMP:${employee['employee_id']}|${employee['email']}|${employee['name']}';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return DesignTokens.colors['gray600']!;
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

  List<int> _decodeBase64Photo(String base64String) {
    try {
      // Remove data URL prefix if present
      final cleanBase64 = base64String.replaceFirst(RegExp(r'^data:image\/[^;]+;base64,'), '');
      return Uri.dataFromString(cleanBase64, encoding: Encoding.getByName('base64')!).data;
    } catch (e) {
      throw Exception('Invalid base64 image data');
    }
  }
}

/// Employee ID card dialog for viewing/printing
class EmployeeIdCardDialog extends StatelessWidget {
  final Map<String, dynamic> employee;

  const EmployeeIdCardDialog({
    super.key,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        child: ProfessionalCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.badge,
                    color: DesignTokens.primaryOrange,
                    size: 24,
                  ),
                  const SizedBox(width: DesignTokens.spacing12),
                  Expanded(
                    child: Text(
                      'Employee ID Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.colors['black'],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: DesignTokens.colors['gray600'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing20),
              
              // ID Card
              Center(
                child: EmployeeIdCard(
                  employee: employee,
                  showQRCode: true,
                  isPrintable: false,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing20),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: DesignTokens.spacing8),
                  ElevatedButton.icon(
                    onPressed: () => _printIdCard(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _printIdCard(BuildContext context) {
    // TODO: Implement printing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality will be implemented'),
      ),
    );
  }
}
