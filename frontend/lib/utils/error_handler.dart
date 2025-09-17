import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized error handling utility for consistent error management
class ErrorHandler {
  /// Show a user-friendly error message using SnackBar
  static void showError(BuildContext context, String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a success message using SnackBar
  static void showSuccess(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFFA301),
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a warning message using SnackBar
  static void showWarning(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE6920E),
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Handle HTTP response errors with user-friendly messages
  static void handleHttpError(BuildContext context, http.Response response, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    String message = customMessage ?? 'An error occurred';
    
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body.containsKey('error')) {
        message = body['error'].toString();
      }
    } catch (e) {
      // Use status code based message if JSON parsing fails
      message = _getStatusCodeMessage(response.statusCode);
    }

    SnackBarAction? action;
    if (onRetry != null) {
      action = SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      );
    }

    showError(context, message, action: action);
  }

  /// Handle generic exceptions with user-friendly messages
  static void handleException(BuildContext context, dynamic exception, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    String message = customMessage ?? _getExceptionMessage(exception);
    
    SnackBarAction? action;
    if (onRetry != null) {
      action = SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      );
    }

    showError(context, message, action: action);
  }

  /// Show a loading error with retry option
  static void showLoadingError(BuildContext context, {
    String message = 'Failed to load data',
    required VoidCallback onRetry,
  }) {
    showError(
      context,
      message,
      action: SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
    );
  }

  /// Show a network error with retry option
  static void showNetworkError(BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      'Network error. Please check your connection.',
      action: onRetry != null ? SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      ) : null,
    );
  }

  /// Show a validation error
  static void showValidationError(BuildContext context, String field) {
    showError(context, 'Please provide a valid $field');
  }

  /// Show an unauthorized error
  static void showUnauthorizedError(BuildContext context) {
    showError(context, 'You are not authorized to perform this action');
  }

  /// Show a not found error
  static void showNotFoundError(BuildContext context, String resource) {
    showError(context, '$resource not found');
  }

  /// Get user-friendly message based on HTTP status code
  static String _getStatusCodeMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'You are not authorized. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 408:
        return 'Request timeout. Please try again.';
      case 409:
        return 'Conflict occurred. The resource may already exist.';
      case 422:
        return 'Invalid data provided. Please check your input.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Request timeout. Please try again.';
      default:
        return 'An unexpected error occurred (${statusCode}).';
    }
  }

  /// Get user-friendly message based on exception type
  static String _getExceptionMessage(dynamic exception) {
    final exceptionStr = exception.toString().toLowerCase();
    
    if (exceptionStr.contains('socket') || exceptionStr.contains('network')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (exceptionStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (exceptionStr.contains('format') || exceptionStr.contains('parse')) {
      return 'Data format error. Please try again.';
    } else if (exceptionStr.contains('permission')) {
      return 'Permission denied. Please check your access rights.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Log error for debugging (in development mode)
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    // Only log in debug mode
    assert(() {
      print('ERROR in $context: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
      return true;
    }());
  }

  /// Show a confirmation dialog for destructive actions
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: confirmColor ?? Colors.red,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

/// Extension to add error handling methods to BuildContext
extension ErrorHandlerExtension on BuildContext {
  void showError(String message, {Color? backgroundColor, VoidCallback? onRetry}) {
    ErrorHandler.showError(this, message, backgroundColor: backgroundColor);
  }

  void showSuccess(String message) {
    ErrorHandler.showSuccess(this, message);
  }

  void showWarning(String message) {
    ErrorHandler.showWarning(this, message);
  }

  void handleHttpError(http.Response response, {String? customMessage, VoidCallback? onRetry}) {
    ErrorHandler.handleHttpError(this, response, customMessage: customMessage, onRetry: onRetry);
  }

  void handleException(dynamic exception, {String? customMessage, VoidCallback? onRetry}) {
    ErrorHandler.handleException(this, exception, customMessage: customMessage, onRetry: onRetry);
  }
}
