class Environment {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://localhost:3000',
  );

  // Google OAuth Configuration
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: 'your-google-client-id.apps.googleusercontent.com',
  );

  // App Configuration
  static const String appName = 'Task Management Tool';
  static const String appVersion = '1.0.0';
  
  // Feature Flags
  static const bool enableChat = bool.fromEnvironment(
    'ENABLE_CHAT',
    defaultValue: true,
  );
  
  static const bool enableNotifications = bool.fromEnvironment(
    'ENABLE_NOTIFICATIONS',
    defaultValue: true,
  );
  
  static const bool enableFileSharing = bool.fromEnvironment(
    'ENABLE_FILE_SHARING',
    defaultValue: true,
  );
  
  static const bool enableTimeTracking = bool.fromEnvironment(
    'ENABLE_TIME_TRACKING',
    defaultValue: true,
  );

  // Development Configuration
  static const bool isDebugMode = bool.fromEnvironment(
    'DEBUG',
    defaultValue: true,
  );
  
  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );

  // File Upload Configuration
  static const int maxFileSize = int.fromEnvironment(
    'MAX_FILE_SIZE',
    defaultValue: 10485760, // 10MB
  );
  
  static const List<String> allowedFileTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv',
  ];

  // Pagination Configuration
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Configuration
  static const Duration cacheExpiration = Duration(minutes: 30);
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);

  // Socket Configuration
  static const Duration socketReconnectDelay = Duration(seconds: 5);
  static const int maxSocketReconnectAttempts = 5;

  // Notification Configuration
  static const Duration notificationDisplayDuration = Duration(seconds: 5);
  static const int maxNotificationsToShow = 50;

  // Chat Configuration
  static const int maxMessageLength = 1000;
  static const Duration typingIndicatorTimeout = Duration(seconds: 3);
  static const int maxMessagesPerPage = 50;

  // Theme Configuration
  static const String defaultTheme = 'light';
  static const List<String> availableThemes = ['light', 'dark', 'system'];

  // Validation Configuration
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;

  // Helper methods
  static bool get isProduction => !isDebugMode;
  
  static String get environment => isDebugMode ? 'development' : 'production';
  
  static Map<String, dynamic> get config => {
    'apiBaseUrl': apiBaseUrl,
    'socketUrl': socketUrl,
    'googleClientId': googleClientId,
    'appName': appName,
    'appVersion': appVersion,
    'environment': environment,
    'features': {
      'chat': enableChat,
      'notifications': enableNotifications,
      'fileSharing': enableFileSharing,
      'timeTracking': enableTimeTracking,
    },
    'limits': {
      'maxFileSize': maxFileSize,
      'defaultPageSize': defaultPageSize,
      'maxPageSize': maxPageSize,
      'maxMessageLength': maxMessageLength,
      'maxNotificationsToShow': maxNotificationsToShow,
    },
  };

  // Validation methods
  static bool isValidFileType(String mimeType) {
    return allowedFileTypes.contains(mimeType.toLowerCase());
  }
  
  static bool isValidFileSize(int size) {
    return size <= maxFileSize;
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // URL builders
  static String buildApiUrl(String endpoint) {
    return '$apiBaseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}';
  }
  
  static String buildFileUrl(String fileId) {
    return buildApiUrl('/files/$fileId');
  }
  
  static String buildFileDownloadUrl(String fileId) {
    return buildApiUrl('/files/$fileId/download');
  }
  
  static String buildFilePreviewUrl(String fileId) {
    return buildApiUrl('/files/$fileId/preview');
  }

  // Debug helpers
  static void printConfig() {
    if (isDebugMode) {
      print('=== Environment Configuration ===');
      print('API Base URL: $apiBaseUrl');
      print('Socket URL: $socketUrl');
      print('Environment: $environment');
      print('Features: ${config['features']}');
      print('================================');
    }
  }
}
