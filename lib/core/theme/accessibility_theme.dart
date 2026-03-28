import 'package:flutter/material.dart';

/// Enhanced theme system with accessibility support including high contrast,
/// large text, color filters, and focus indicators.
class AccessibilityTheme {
  AccessibilityTheme._();

  // Base color palette
  static const Color _primaryColor = Color(0xFF2E7D32); // Forest green
  static const Color _secondaryColor = Color(0xFFFF6F00); // Amber orange
  static const Color _surfaceColor = Color(0xFFFAFAFA);
  static const Color _errorColor = Color(0xFFD32F2F);

  // High contrast colors
  static const Color _highContrastPrimary = Color(0xFF000000);
  static const Color _highContrastSecondary = Color(0xFFFFFFFF);
  static const Color _highContrastSurface = Color(0xFFFFFFFF);
  static const Color _highContrastError = Color(0xFF000000);

  // Dark theme colors
  static const Color _darkPrimaryColor = Color(0xFF4CAF50);
  static const Color _darkSurfaceColor = Color(0xFF121212);
  static const Color _darkHighContrastPrimary = Color(0xFFFFFFFF);
  static const Color _darkHighContrastSurface = Color(0xFF000000);

  /// Standard light theme
  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        surfaceColor: _surfaceColor,
        errorColor: _errorColor,
        isHighContrast: false,
        fontScale: 1.0,
      );

  /// Standard dark theme
  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        primaryColor: _darkPrimaryColor,
        secondaryColor: _secondaryColor,
        surfaceColor: _darkSurfaceColor,
        errorColor: _errorColor,
        isHighContrast: false,
        fontScale: 1.0,
      );

  /// High contrast light theme
  static ThemeData get highContrastLightTheme => _buildTheme(
        brightness: Brightness.light,
        primaryColor: _highContrastPrimary,
        secondaryColor: _highContrastSecondary,
        surfaceColor: _highContrastSurface,
        errorColor: _highContrastError,
        isHighContrast: true,
        fontScale: 1.0,
      );

  /// High contrast dark theme
  static ThemeData get highContrastDarkTheme => _buildTheme(
        brightness: Brightness.dark,
        primaryColor: _darkHighContrastPrimary,
        secondaryColor: _highContrastPrimary,
        surfaceColor: _darkHighContrastSurface,
        errorColor: _darkHighContrastPrimary,
        isHighContrast: true,
        fontScale: 1.0,
      );

  /// Large text light theme
  static ThemeData get largeTextLightTheme => _buildTheme(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        secondaryColor: _secondaryColor,
        surfaceColor: _surfaceColor,
        errorColor: _errorColor,
        isHighContrast: false,
        fontScale: 1.5,
      );

  /// Large text dark theme
  static ThemeData get largeTextDarkTheme => _buildTheme(
        brightness: Brightness.dark,
        primaryColor: _darkPrimaryColor,
        secondaryColor: _secondaryColor,
        surfaceColor: _darkSurfaceColor,
        errorColor: _errorColor,
        isHighContrast: false,
        fontScale: 1.5,
      );

  /// Build custom theme with accessibility options
  static ThemeData buildCustomTheme({
    required Brightness brightness,
    bool isHighContrast = false,
    double fontScale = 1.0,
    String colorFilter = 'none',
    bool enhancedFocus = false,
  }) {
    Color primaryColor;
    Color secondaryColor;
    Color surfaceColor;
    Color errorColor;

    if (brightness == Brightness.light) {
      if (isHighContrast) {
        primaryColor = _highContrastPrimary;
        secondaryColor = _highContrastSecondary;
        surfaceColor = _highContrastSurface;
        errorColor = _highContrastError;
      } else {
        primaryColor = _primaryColor;
        secondaryColor = _secondaryColor;
        surfaceColor = _surfaceColor;
        errorColor = _errorColor;
      }
    } else {
      if (isHighContrast) {
        primaryColor = _darkHighContrastPrimary;
        secondaryColor = _highContrastPrimary;
        surfaceColor = _darkHighContrastSurface;
        errorColor = _darkHighContrastPrimary;
      } else {
        primaryColor = _darkPrimaryColor;
        secondaryColor = _secondaryColor;
        surfaceColor = _darkSurfaceColor;
        errorColor = _errorColor;
      }
    }

    // Apply color filters
    if (colorFilter != 'none') {
      final filteredColors = _applyColorFilter(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        surfaceColor: surfaceColor,
        errorColor: errorColor,
        filter: colorFilter,
      );
      primaryColor = filteredColors['primary']!;
      secondaryColor = filteredColors['secondary']!;
      surfaceColor = filteredColors['surface']!;
      errorColor = filteredColors['error']!;
    }

    return _buildTheme(
      brightness: brightness,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      surfaceColor: surfaceColor,
      errorColor: errorColor,
      isHighContrast: isHighContrast,
      fontScale: fontScale,
      enhancedFocus: enhancedFocus,
    );
  }

  /// Build theme with specified parameters
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primaryColor,
    required Color secondaryColor,
    required Color surfaceColor,
    required Color errorColor,
    required bool isHighContrast,
    required double fontScale,
    bool enhancedFocus = false,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
    );

    final textTheme = _buildTextTheme(brightness, fontScale, isHighContrast);
    final focusColor = _buildFocusColor(enhancedFocus, isHighContrast);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      focusColor: focusColor,
      appBarTheme: _buildAppBarTheme(primaryColor, brightness, fontScale),
      elevatedButtonTheme:
          _buildElevatedButtonTheme(primaryColor, fontScale, isHighContrast),
      textButtonTheme:
          _buildTextButtonTheme(primaryColor, fontScale, isHighContrast),
      outlinedButtonTheme:
          _buildOutlinedButtonTheme(primaryColor, fontScale, isHighContrast),
      floatingActionButtonTheme: _buildFABTheme(secondaryColor),
      cardTheme: _buildCardThemeData(surfaceColor, isHighContrast),
      listTileTheme: _buildListTileTheme(fontScale, isHighContrast),
      inputDecorationTheme:
          _buildInputDecorationTheme(primaryColor, isHighContrast),
      iconTheme: _buildIconTheme(primaryColor, fontScale),
      chipTheme: _buildChipTheme(primaryColor, secondaryColor, fontScale),
      tooltipTheme: _buildTooltipTheme(brightness, fontScale),
      snackBarTheme: _buildSnackBarTheme(brightness, fontScale),
      dialogTheme: _buildDialogThemeData(surfaceColor, fontScale),
      bottomNavigationBarTheme:
          _buildBottomNavTheme(primaryColor, brightness, fontScale),
      tabBarTheme: _buildTabBarThemeData(primaryColor, brightness, fontScale),
      sliderTheme: _buildSliderTheme(primaryColor, isHighContrast),
      switchTheme: _buildSwitchTheme(primaryColor, isHighContrast),
      checkboxTheme: _buildCheckboxTheme(primaryColor, isHighContrast),
      radioTheme: _buildRadioTheme(primaryColor, isHighContrast),
      // Enhanced accessibility features
      visualDensity: isHighContrast
          ? VisualDensity.comfortable
          : VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  /// Build text theme with accessibility considerations
  static TextTheme _buildTextTheme(
      Brightness brightness, double fontScale, bool isHighContrast) {
    final baseColor =
        brightness == Brightness.light ? Colors.black87 : Colors.white;
    final contrastColor = isHighContrast
        ? (brightness == Brightness.light ? Colors.black : Colors.white)
        : baseColor;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.22,
      ),
      headlineLarge: TextStyle(
        fontSize: 32 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.33,
      ),
      titleLarge: TextStyle(
        fontSize: 22 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.3 : 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 16 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.4 : 1.50,
      ),
      titleSmall: TextStyle(
        fontSize: 14 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.4 : 1.43,
      ),
      bodyLarge: TextStyle(
        fontSize: 16 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.5 : 1.50,
      ),
      bodyMedium: TextStyle(
        fontSize: 14 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.5 : 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12 * fontScale,
        fontWeight: FontWeight.w400,
        color: contrastColor,
        height: isHighContrast ? 1.5 : 1.33,
      ),
      labelLarge: TextStyle(
        fontSize: 14 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.4 : 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 12 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.4 : 1.33,
      ),
      labelSmall: TextStyle(
        fontSize: 11 * fontScale,
        fontWeight: FontWeight.w500,
        color: contrastColor,
        height: isHighContrast ? 1.4 : 1.45,
      ),
    );
  }

  /// Build focus color for enhanced accessibility
  static Color? _buildFocusColor(bool enhancedFocus, bool isHighContrast) =>
      enhancedFocus
          ? (isHighContrast
              ? Colors.yellow
              : Colors.blue.withValues(alpha: 0.3))
          : null;

  /// Apply color filters for color blindness support
  static Map<String, Color> _applyColorFilter({
    required Color primaryColor,
    required Color secondaryColor,
    required Color surfaceColor,
    required Color errorColor,
    required String filter,
  }) {
    switch (filter) {
      case 'protanopia':
        return {
          'primary': _simulateProtanopia(primaryColor),
          'secondary': _simulateProtanopia(secondaryColor),
          'surface': surfaceColor,
          'error': _simulateProtanopia(errorColor),
        };
      case 'deuteranopia':
        return {
          'primary': _simulateDeuteranopia(primaryColor),
          'secondary': _simulateDeuteranopia(secondaryColor),
          'surface': surfaceColor,
          'error': _simulateDeuteranopia(errorColor),
        };
      case 'tritanopia':
        return {
          'primary': _simulateTritanopia(primaryColor),
          'secondary': _simulateTritanopia(secondaryColor),
          'surface': surfaceColor,
          'error': _simulateTritanopia(errorColor),
        };
      case 'monochrome':
        return {
          'primary': _toGrayscale(primaryColor),
          'secondary': _toGrayscale(secondaryColor),
          'surface': _toGrayscale(surfaceColor),
          'error': _toGrayscale(errorColor),
        };
      default:
        return {
          'primary': primaryColor,
          'secondary': secondaryColor,
          'surface': surfaceColor,
          'error': errorColor,
        };
    }
  }

  /// Simulate protanopia (red-blind) color vision
  static Color _simulateProtanopia(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    final newR = 0.567 * r + 0.433 * g;
    final newG = 0.558 * r + 0.442 * g;
    final newB = 0.242 * g + 0.758 * b;

    return Color.fromARGB(
      (color.a * 255.0).round().clamp(0, 255),
      (newR * 255).round().clamp(0, 255),
      (newG * 255).round().clamp(0, 255),
      (newB * 255).round().clamp(0, 255),
    );
  }

  /// Simulate deuteranopia (green-blind) color vision
  static Color _simulateDeuteranopia(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    final newR = 0.625 * r + 0.375 * g;
    final newG = 0.7 * r + 0.3 * g;
    final newB = 0.3 * g + 0.7 * b;

    return Color.fromARGB(
      (color.a * 255.0).round().clamp(0, 255),
      (newR * 255).round().clamp(0, 255),
      (newG * 255).round().clamp(0, 255),
      (newB * 255).round().clamp(0, 255),
    );
  }

  /// Simulate tritanopia (blue-blind) color vision
  static Color _simulateTritanopia(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    final newR = 0.95 * r + 0.05 * g;
    final newG = 0.433 * g + 0.567 * b;
    final newB = 0.475 * g + 0.525 * b;

    return Color.fromARGB(
      (color.a * 255.0).round().clamp(0, 255),
      (newR * 255).round().clamp(0, 255),
      (newG * 255).round().clamp(0, 255),
      (newB * 255).round().clamp(0, 255),
    );
  }

  /// Convert color to grayscale
  static Color _toGrayscale(Color color) {
    final gray = (0.299 * (color.r * 255.0) +
            0.587 * (color.g * 255.0) +
            0.114 * (color.b * 255.0))
        .round();
    return Color.fromARGB(
        (color.a * 255.0).round().clamp(0, 255), gray, gray, gray);
  }

  // Theme component builders
  static AppBarTheme _buildAppBarTheme(
          Color primaryColor, Brightness brightness, double fontScale) =>
      AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor:
            brightness == Brightness.light ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.light ? Colors.white : Colors.black,
        ),
      );

  static ElevatedButtonThemeData _buildElevatedButtonTheme(
          Color primaryColor, double fontScale, bool isHighContrast) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: isHighContrast ? 8 : 2,
          padding: EdgeInsets.symmetric(
            horizontal: 24 * fontScale,
            vertical: 12 * fontScale,
          ),
          minimumSize: Size(48 * fontScale, 48 * fontScale),
          textStyle: TextStyle(fontSize: 14 * fontScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isHighContrast ? const BorderSide(width: 2) : BorderSide.none,
          ),
        ),
      );

  static TextButtonThemeData _buildTextButtonTheme(
          Color primaryColor, double fontScale, bool isHighContrast) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(
            horizontal: 16 * fontScale,
            vertical: 8 * fontScale,
          ),
          minimumSize: Size(48 * fontScale, 48 * fontScale),
          textStyle: TextStyle(fontSize: 14 * fontScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isHighContrast
                ? BorderSide(color: primaryColor)
                : BorderSide.none,
          ),
        ),
      );

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(
          Color primaryColor, double fontScale, bool isHighContrast) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(
            horizontal: 24 * fontScale,
            vertical: 12 * fontScale,
          ),
          minimumSize: Size(48 * fontScale, 48 * fontScale),
          textStyle: TextStyle(fontSize: 14 * fontScale),
          side: BorderSide(
            color: primaryColor,
            width: isHighContrast ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

  static FloatingActionButtonThemeData _buildFABTheme(Color secondaryColor) =>
      FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      );

  static CardThemeData _buildCardThemeData(
          Color surfaceColor, bool isHighContrast) =>
      CardThemeData(
        elevation: isHighContrast ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: isHighContrast ? const BorderSide() : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );

  static ListTileThemeData _buildListTileTheme(
          double fontScale, bool isHighContrast) =>
      ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16 * fontScale,
          vertical: 8 * fontScale,
        ),
        minVerticalPadding: 8 * fontScale,
        titleTextStyle: TextStyle(fontSize: 16 * fontScale),
        subtitleTextStyle: TextStyle(fontSize: 14 * fontScale),
      );

  static InputDecorationTheme _buildInputDecorationTheme(
          Color primaryColor, bool isHighContrast) =>
      InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: primaryColor,
            width: isHighContrast ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: primaryColor,
            width: isHighContrast ? 3 : 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  static IconThemeData _buildIconTheme(Color primaryColor, double fontScale) =>
      IconThemeData(
        color: primaryColor,
        size: 24 * fontScale,
      );

  static ChipThemeData _buildChipTheme(
          Color primaryColor, Color secondaryColor, double fontScale) =>
      ChipThemeData(
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        selectedColor: primaryColor,
        labelStyle: TextStyle(fontSize: 12 * fontScale),
        padding: EdgeInsets.symmetric(
            horizontal: 8 * fontScale, vertical: 4 * fontScale),
      );

  static TooltipThemeData _buildTooltipTheme(
          Brightness brightness, double fontScale) =>
      TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 12 * fontScale,
          color: brightness == Brightness.light ? Colors.white : Colors.black,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.light ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  static SnackBarThemeData _buildSnackBarTheme(
          Brightness brightness, double fontScale) =>
      SnackBarThemeData(
        contentTextStyle: TextStyle(fontSize: 14 * fontScale),
        actionTextColor:
            brightness == Brightness.light ? Colors.yellow : Colors.blue,
      );

  static DialogThemeData _buildDialogThemeData(
          Color surfaceColor, double fontScale) =>
      DialogThemeData(
        titleTextStyle:
            TextStyle(fontSize: 20 * fontScale, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(fontSize: 16 * fontScale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static BottomNavigationBarThemeData _buildBottomNavTheme(
          Color primaryColor, Brightness brightness, double fontScale) =>
      BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor:
            brightness == Brightness.light ? Colors.grey : Colors.grey[400],
        selectedLabelStyle: TextStyle(fontSize: 12 * fontScale),
        unselectedLabelStyle: TextStyle(fontSize: 12 * fontScale),
      );

  static TabBarThemeData _buildTabBarThemeData(
          Color primaryColor, Brightness brightness, double fontScale) =>
      TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor:
            brightness == Brightness.light ? Colors.grey : Colors.grey[400],
        labelStyle:
            TextStyle(fontSize: 14 * fontScale, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 14 * fontScale),
      );

  static SliderThemeData _buildSliderTheme(
          Color primaryColor, bool isHighContrast) =>
      SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withValues(alpha: 0.3),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        trackHeight: isHighContrast ? 6 : 4,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: isHighContrast ? 12 : 10,
        ),
      );

  static SwitchThemeData _buildSwitchTheme(
          Color primaryColor, bool isHighContrast) =>
      SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return null;
        }),
        trackOutlineWidth: WidgetStateProperty.all(isHighContrast ? 2 : 1),
      );

  static CheckboxThemeData _buildCheckboxTheme(
          Color primaryColor, bool isHighContrast) =>
      CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        side: isHighContrast ? BorderSide(color: primaryColor, width: 2) : null,
      );

  static RadioThemeData _buildRadioTheme(
          Color primaryColor, bool isHighContrast) =>
      RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
      );
}

/// Theme configuration for accessibility
class AccessibilityThemeConfig {
  const AccessibilityThemeConfig({
    this.isHighContrast = false,
    this.isLargeText = false,
    this.fontScale = 1.0,
    this.colorFilter = 'none',
    this.enhancedFocus = false,
    this.brightness = Brightness.light,
  });
  final bool isHighContrast;
  final bool isLargeText;
  final double fontScale;
  final String colorFilter;
  final bool enhancedFocus;
  final Brightness brightness;

  AccessibilityThemeConfig copyWith({
    bool? isHighContrast,
    bool? isLargeText,
    double? fontScale,
    String? colorFilter,
    bool? enhancedFocus,
    Brightness? brightness,
  }) =>
      AccessibilityThemeConfig(
        isHighContrast: isHighContrast ?? this.isHighContrast,
        isLargeText: isLargeText ?? this.isLargeText,
        fontScale: fontScale ?? this.fontScale,
        colorFilter: colorFilter ?? this.colorFilter,
        enhancedFocus: enhancedFocus ?? this.enhancedFocus,
        brightness: brightness ?? this.brightness,
      );

  /// Get theme data based on configuration
  ThemeData get themeData => AccessibilityTheme.buildCustomTheme(
        brightness: brightness,
        isHighContrast: isHighContrast,
        fontScale: isLargeText ? 1.5 : fontScale,
        colorFilter: colorFilter,
        enhancedFocus: enhancedFocus,
      );
}
