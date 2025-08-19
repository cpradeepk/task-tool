import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme state class
class ThemeState {
  final String selectedTheme;
  final bool isDarkMode;
  final double zoomLevel;

  const ThemeState({
    this.selectedTheme = 'Blue',
    this.isDarkMode = false,
    this.zoomLevel = 1.0,
  });

  ThemeState copyWith({
    String? selectedTheme,
    bool? isDarkMode,
    double? zoomLevel,
  }) {
    return ThemeState(
      selectedTheme: selectedTheme ?? this.selectedTheme,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeKey = 'selected_theme';
  static const String _darkModeKey = 'dark_mode';
  static const String _zoomKey = 'zoom_level';

  static const double _minZoom = 0.8;
  static const double _maxZoom = 1.5;
  static const double _zoomStep = 0.1;

  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }
  
  // Theme colors mapping
  static const Map<String, Color> _themeColors = {
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Purple': Colors.purple,
    'Orange': Colors.orange,
    'Red': Colors.red,
    'Teal': Colors.teal,
    'Indigo': Colors.indigo,
    'Pink': Colors.pink,
  };
  
  Color get primaryColor => _themeColors[state.selectedTheme] ?? Colors.blue;

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        selectedColor: primaryColor,
        labelStyle: const TextStyle(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withValues(alpha: 0.2),
        selectedColor: primaryColor,
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  ThemeData get currentTheme => state.isDarkMode ? darkTheme : lightTheme;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedTheme = prefs.getString(_themeKey) ?? 'Blue';
    final isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    final zoomLevel = prefs.getDouble(_zoomKey) ?? 1.0;
    state = state.copyWith(
      selectedTheme: selectedTheme,
      isDarkMode: isDarkMode,
      zoomLevel: zoomLevel,
    );
  }

  Future<void> setTheme(String theme) async {
    if (_themeColors.containsKey(theme)) {
      state = state.copyWith(selectedTheme: theme);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!state.isDarkMode);
  }

  // Zoom functionality
  Future<void> zoomIn() async {
    final newZoom = (state.zoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
    await setZoomLevel(newZoom);
  }

  Future<void> zoomOut() async {
    final newZoom = (state.zoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
    await setZoomLevel(newZoom);
  }

  Future<void> resetZoom() async {
    await setZoomLevel(1.0);
  }

  Future<void> setZoomLevel(double zoom) async {
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    state = state.copyWith(zoomLevel: clampedZoom);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_zoomKey, clampedZoom);
  }

  List<String> get availableThemes => _themeColors.keys.toList();

  Color getThemeColor(String theme) {
    return _themeColors[theme] ?? Colors.blue;
  }
}

// Provider instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
