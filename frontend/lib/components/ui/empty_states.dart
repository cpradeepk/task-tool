import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import 'custom_buttons.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? customAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignTokens.colors['gray100'],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: DesignTokens.colors['gray400'],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DesignTokens.colors['black'],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.colors['gray600'],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (customAction != null) ...[
              const SizedBox(height: 24),
              customAction!,
            ] else if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: actionText!,
                onPressed: onAction,
                variant: ButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoTasksFound extends StatelessWidget {
  final VoidCallback? onCreateTask;

  const NoTasksFound({
    super.key,
    this.onCreateTask,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.task_alt,
      title: 'No tasks found',
      subtitle: 'Get started by creating your first task',
      actionText: onCreateTask != null ? 'Create Task' : null,
      onAction: onCreateTask,
    );
  }
}

class NoProjectsFound extends StatelessWidget {
  final VoidCallback? onCreateProject;

  const NoProjectsFound({
    super.key,
    this.onCreateProject,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.folder,
      title: 'No projects found',
      subtitle: 'Create a project to organize your tasks',
      actionText: onCreateProject != null ? 'Create Project' : null,
      onAction: onCreateProject,
    );
  }
}

class NoSearchResults extends StatelessWidget {
  final String searchTerm;
  final VoidCallback? onClearSearch;

  const NoSearchResults({
    super.key,
    required this.searchTerm,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No results found',
      subtitle: 'No results found for "$searchTerm".\nTry adjusting your search terms.',
      actionText: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
    );
  }
}

class ErrorState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: title,
      subtitle: subtitle ?? 'Please try again or contact support if the problem persists.',
      actionText: onRetry != null ? 'Try Again' : null,
      onAction: onRetry,
    );
  }
}

class NetworkError extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkError({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: 'Connection Error',
      subtitle: 'Please check your internet connection and try again.',
      onRetry: onRetry,
    );
  }
}

class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                DesignTokens.colors['primary']!,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.colors['gray600'],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
