import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  final String? className;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getPriorityColors(priority);
    final label = _getPriorityLabel(priority);
    
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors['background'],
          border: Border.all(color: colors['border']!),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
        child: Text(
          priority,
          style: TextStyle(
            color: colors['text'],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toUpperCase()) {
      case 'U&I':
        return 'Urgent & Important';
      case 'NU&I':
        return 'Not Urgent but Important';
      case 'U&NI':
        return 'Urgent but Not Important';
      case 'NU&NI':
        return 'Not Urgent & Not Important';
      default:
        return priority;
    }
  }

  Map<String, Color> _getPriorityColors(String priority) {
    switch (priority.toUpperCase()) {
      case 'U&I':
        return {
          'background': DesignTokens.colors['primary']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['primary600']!,
        };
      case 'NU&I':
        return {
          'background': DesignTokens.colors['primary200']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['primary400']!,
        };
      case 'U&NI':
        return {
          'background': DesignTokens.colors['primary100']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['primary300']!,
        };
      case 'NU&NI':
        return {
          'background': DesignTokens.colors['gray100']!,
          'text': DesignTokens.colors['black']!,
          'border': DesignTokens.colors['gray300']!,
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
