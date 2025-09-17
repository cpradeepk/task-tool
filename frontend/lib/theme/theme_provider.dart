import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens for consistent styling
class DesignTokens {
  // Primary orange color from reference app
  static const Color primaryOrange = Color(0xFFFFA301);

  // Extended color palette
  static const Map<String, Color> colors = {
    'primary': primaryOrange,
    'primary50': Color(0xFFFFF8E6),
    'primary100': Color(0xFFFFECB3),
    'primary200': Color(0xFFFFE080),
    'primary300': Color(0xFFFFD54D),
    'primary400': Color(0xFFFFCA1A),
    'primary500': primaryOrange,
    'primary600': Color(0xFFE6920E),
    'primary700': Color(0xFFCC8200),
    'primary800': Color(0xFFB37200),
    'primary900': Color(0xFF996200),
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'gray50': Color(0xFFF8F8F8),
    'gray100': Color(0xFFF0F0F0),
    'gray200': Color(0xFFE8E8E8),
    'gray300': Color(0xFFD0D0D0),
    'gray400': Color(0xFFA0A0A0),
    'gray500': Color(0xFF808080),
    'gray600': Color(0xFF606060),
    'gray700': Color(0xFF404040),
    'gray800': Color(0xFF202020),
    'gray900': Color(0xFF101010),
  };

  // Spacing system
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // Typography
  static const String fontFamily = 'Signika';

  // Font sizes matching JSR web app
  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSize2XL = 20.0;
  static const double fontSize3XL = 24.0;
  static const double fontSize4XL = 28.0;
  static const double fontSize5XL = 32.0;
  static const double fontSize6XL = 36.0;

  // Text styles matching JSR web app hierarchy
  static TextStyle get headingLarge => GoogleFonts.signika(
    fontSize: fontSize5XL,
    fontWeight: FontWeight.w700,
    color: colors['black'],
    height: 1.2,
  );

  static TextStyle get headingMedium => GoogleFonts.signika(
    fontSize: fontSize3XL,
    fontWeight: FontWeight.w600,
    color: colors['black'],
    height: 1.3,
  );

  static TextStyle get headingSmall => GoogleFonts.signika(
    fontSize: fontSize2XL,
    fontWeight: FontWeight.w600,
    color: colors['black'],
    height: 1.4,
  );

  static TextStyle get bodyLarge => GoogleFonts.signika(
    fontSize: fontSizeL,
    fontWeight: FontWeight.w400,
    color: colors['black'],
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.signika(
    fontSize: fontSizeM,
    fontWeight: FontWeight.w400,
    color: colors['black'],
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.signika(
    fontSize: fontSizeS,
    fontWeight: FontWeight.w400,
    color: colors['gray600'],
    height: 1.4,
  );

  static TextStyle get labelLarge => GoogleFonts.signika(
    fontSize: fontSizeM,
    fontWeight: FontWeight.w500,
    color: colors['black'],
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.signika(
    fontSize: fontSizeS,
    fontWeight: FontWeight.w500,
    color: colors['gray700'],
    height: 1.4,
  );

  static TextStyle get labelSmall => GoogleFonts.signika(
    fontSize: fontSizeXS,
    fontWeight: FontWeight.w500,
    color: colors['gray600'],
    height: 1.3,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// Theme state class
class ThemeState {
  final String selectedTheme;
  final bool isDarkMode;
  final double zoomLevel;

  const ThemeState({
    this.selectedTheme = 'Orange',
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

  // Theme colors mapping - Orange only as per roadmap
  static const Map<String, Color> _themeColors = {
    'Orange': DesignTokens.primaryOrange,
  };

  Color get primaryColor => _themeColors[state.selectedTheme] ?? DesignTokens.primaryOrange;

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: DesignTokens.colors['white']!,
      ),
      scaffoldBackgroundColor: DesignTokens.colors['gray50'],
      textTheme: GoogleFonts.signikaTextTheme(
        TextTheme(
          displayLarge: DesignTokens.headingLarge,
          displayMedium: DesignTokens.headingMedium,
          displaySmall: DesignTokens.headingSmall,
          headlineLarge: DesignTokens.headingLarge,
          headlineMedium: DesignTokens.headingMedium,
          headlineSmall: DesignTokens.headingSmall,
          titleLarge: DesignTokens.headingSmall,
          titleMedium: DesignTokens.labelLarge,
          titleSmall: DesignTokens.labelMedium,
          bodyLarge: DesignTokens.bodyLarge,
          bodyMedium: DesignTokens.bodyMedium,
          bodySmall: DesignTokens.bodySmall,
          labelLarge: DesignTokens.labelLarge,
          labelMedium: DesignTokens.labelMedium,
          labelSmall: DesignTokens.labelSmall,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: DesignTokens.colors['black'],
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: DesignTokens.headingSmall.copyWith(
          color: DesignTokens.colors['black'],
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: DesignTokens.colors['black'],
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing16,
            vertical: DesignTokens.spacing12,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.colors['black'],
          side: BorderSide(color: DesignTokens.colors['gray300']!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: DesignTokens.colors['black'],
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        selectedColor: primaryColor,
        labelStyle: TextStyle(color: DesignTokens.colors['black']),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        ),
      ),
      // cardTheme: CardThemeData configuration removed for compatibility
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: DesignTokens.colors['gray300']!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: DesignTokens.colors['gray300']!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing12,
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
        primary: primaryColor,
        surface: DesignTokens.colors['gray800']!,
      ),
      scaffoldBackgroundColor: DesignTokens.colors['gray900'],
      textTheme: GoogleFonts.signikaTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: DesignTokens.headingLarge.copyWith(color: Colors.white),
          displayMedium: DesignTokens.headingMedium.copyWith(color: Colors.white),
          displaySmall: DesignTokens.headingSmall.copyWith(color: Colors.white),
          headlineLarge: DesignTokens.headingLarge.copyWith(color: Colors.white),
          headlineMedium: DesignTokens.headingMedium.copyWith(color: Colors.white),
          headlineSmall: DesignTokens.headingSmall.copyWith(color: Colors.white),
          titleLarge: DesignTokens.headingSmall.copyWith(color: Colors.white),
          titleMedium: DesignTokens.labelLarge.copyWith(color: Colors.white),
          titleSmall: DesignTokens.labelMedium.copyWith(color: Colors.white70),
          bodyLarge: DesignTokens.bodyLarge.copyWith(color: Colors.white),
          bodyMedium: DesignTokens.bodyMedium.copyWith(color: Colors.white),
          bodySmall: DesignTokens.bodySmall.copyWith(color: Colors.white70),
          labelLarge: DesignTokens.labelLarge.copyWith(color: Colors.white),
          labelMedium: DesignTokens.labelMedium.copyWith(color: Colors.white70),
          labelSmall: DesignTokens.labelSmall.copyWith(color: Colors.white60),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DesignTokens.colors['gray800'],
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: DesignTokens.headingSmall.copyWith(
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: DesignTokens.colors['black'],
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: DesignTokens.colors['black'],
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.2),
        selectedColor: primaryColor,
        labelStyle: const TextStyle(color: Colors.white70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        ),
      ),
      // cardTheme: CardThemeData configuration removed for compatibility
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.colors['gray800'],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: DesignTokens.colors['gray600']!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: DesignTokens.colors['gray600']!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
  
  ThemeData get currentTheme => state.isDarkMode ? darkTheme : lightTheme;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedTheme = prefs.getString(_themeKey) ?? 'Orange';
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
    return _themeColors[theme] ?? DesignTokens.primaryOrange;
  }
}

// Provider instance
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
