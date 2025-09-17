import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? className;

  const StatusBadge({
    super.key,
    required this.status,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors['background'],
        border: Border.all(color: colors['border']!),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: colors['text'],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'yet to start':
      case 'pending':
        return {
          'background': DesignTokens.colors['gray100']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['gray300']!,
        };
      case 'in progress':
        return {
          'background': DesignTokens.colors['primary100']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['primary300']!,
        };
      case 'done':
      case 'completed':
        return {
          'background': DesignTokens.colors['primary']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['primary600']!,
        };
      case 'delayed':
        return {
          'background': const Color(0xFFFEE2E2), // red-100
          'text': const Color(0xFF991B1B), // red-800
          'border': const Color(0xFFFCA5A5), // red-300
        };
      case 'hold':
      case 'on hold':
        return {
          'background': const Color(0xFFFEF3C7), // yellow-100
          'text': const Color(0xFF92400E), // yellow-800
          'border': const Color(0xFFFDE68A), // yellow-300
        };
      default:
        return {
          'background': DesignTokens.colors['gray100']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['gray300']!,
        };
    }
  }
}
