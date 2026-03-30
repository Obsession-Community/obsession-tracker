import 'package:flutter/material.dart';

/// Application theme configuration for Obsession Tracker.
///
/// High-contrast "Treasure Hunter" theme with dark backgrounds
/// and antique gold accents. Optimized for outdoor visibility.
class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR PALETTE - Treasure Hunter Theme
  // ═══════════════════════════════════════════════════════════════════════════

  // Primary brand color - Antique Gold
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE5C76B);
  static const Color goldDark = Color(0xFFC9A227);

  // Dark mode backgrounds - Warm blacks
  static const Color darkBackground = Color(0xFF0D0B09); // Near black, warm
  static const Color darkSurface = Color(0xFF1A1714); // Elevated surfaces
  static const Color darkSurfaceElevated = Color(0xFF252220); // Cards, dialogs

  // Light mode backgrounds - Warm creams
  static const Color lightBackground = Color(0xFFFAF8F5); // Warm white
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white for cards
  static const Color lightSurfaceElevated = Color(0xFFF5F3F0); // Slight warmth

  // Text colors
  static const Color textOnDark = Color(0xFFF5F5F0); // Warm white
  static const Color textOnDarkMuted = Color(0xFFB0ADA8); // Muted for secondary
  static const Color textOnLight = Color(0xFF1A1714); // Warm black
  static const Color textOnLightMuted = Color(0xFF6B6560); // Muted for secondary

  // Semantic colors
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: gold,
          onPrimary: darkBackground, // Dark text on gold buttons
          secondary: goldDark,
          onSecondary: darkBackground,
          onSurface: textOnLight,
          error: error,
        ),
        scaffoldBackgroundColor: lightBackground,

        // App Bar - Light background with gold accents
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: lightSurface,
          foregroundColor: textOnLight,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnLight,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: gold),
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: darkBackground,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: gold,
            side: const BorderSide(color: gold, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: gold,
          ),
        ),

        // FAB
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: gold,
          foregroundColor: darkBackground,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: lightSurface,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),

        // Text
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textOnLight,
            letterSpacing: 0.25,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textOnLight,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnLight,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textOnLight,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textOnLight,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textOnLightMuted,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textOnLight,
            letterSpacing: 0.5,
          ),
        ),

        // Icons
        iconTheme: const IconThemeData(
          color: gold,
          size: 24,
        ),

        // Dividers
        dividerTheme: DividerThemeData(
          color: textOnLightMuted.withValues(alpha: 0.2),
          thickness: 1,
        ),

        // Input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: textOnLightMuted.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: textOnLightMuted.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: gold, width: 2),
          ),
          labelStyle: const TextStyle(color: textOnLightMuted),
          hintStyle: TextStyle(color: textOnLightMuted.withValues(alpha: 0.7)),
        ),

        // Bottom navigation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: lightSurface,
          selectedItemColor: gold,
          unselectedItemColor: textOnLightMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // Navigation bar (Material 3)
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightSurface,
          indicatorColor: gold.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: gold);
            }
            return const IconThemeData(color: textOnLightMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: textOnLightMuted, fontSize: 12);
          }),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: lightSurfaceElevated,
          selectedColor: gold.withValues(alpha: 0.2),
          labelStyle: const TextStyle(color: textOnLight),
          secondaryLabelStyle: const TextStyle(color: gold),
          side: BorderSide(color: textOnLightMuted.withValues(alpha: 0.2)),
        ),

        // Snackbar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkBackground,
          contentTextStyle: const TextStyle(color: textOnDark),
          actionTextColor: gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: lightSurface,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnLight,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: textOnLightMuted,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        // Switch
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold;
            return textOnLightMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold.withValues(alpha: 0.4);
            return textOnLightMuted.withValues(alpha: 0.3);
          }),
        ),

        // Checkbox
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(darkBackground),
          side: BorderSide(color: textOnLightMuted.withValues(alpha: 0.5), width: 1.5),
        ),

        // Progress indicators
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: gold,
          linearTrackColor: Color(0xFFE0DCD7),
        ),

        // List tiles
        listTileTheme: const ListTileThemeData(
          iconColor: gold,
          textColor: textOnLight,
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          onPrimary: darkBackground, // Dark text on gold buttons
          secondary: goldLight,
          onSecondary: darkBackground,
          surface: darkSurface,
          onSurface: textOnDark,
        ),
        scaffoldBackgroundColor: darkBackground,

        // App Bar - Black with gold text
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: darkBackground,
          foregroundColor: gold,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: gold,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: gold),
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: darkBackground,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: gold,
            side: const BorderSide(color: gold, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: gold,
          ),
        ),

        // FAB
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: gold,
          foregroundColor: darkBackground,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: darkSurface,
          shadowColor: Colors.black.withValues(alpha: 0.4),
        ),

        // Text
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textOnDark,
            letterSpacing: 0.25,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textOnDark,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnDark,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textOnDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textOnDark,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textOnDarkMuted,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textOnDark,
            letterSpacing: 0.5,
          ),
        ),

        // Icons
        iconTheme: const IconThemeData(
          color: gold,
          size: 24,
        ),

        // Dividers
        dividerTheme: DividerThemeData(
          color: gold.withValues(alpha: 0.15),
          thickness: 1,
        ),

        // Input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: gold.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: gold.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: gold, width: 2),
          ),
          labelStyle: const TextStyle(color: gold),
          hintStyle: TextStyle(color: textOnDarkMuted.withValues(alpha: 0.7)),
        ),

        // Bottom navigation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkBackground,
          selectedItemColor: gold,
          unselectedItemColor: textOnDarkMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // Navigation bar (Material 3)
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkSurface,
          indicatorColor: gold.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: gold);
            }
            return const IconThemeData(color: textOnDarkMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: textOnDarkMuted, fontSize: 12);
          }),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: darkSurfaceElevated,
          selectedColor: gold.withValues(alpha: 0.2),
          labelStyle: const TextStyle(color: textOnDark),
          secondaryLabelStyle: const TextStyle(color: gold),
          side: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),

        // Snackbar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkSurfaceElevated,
          contentTextStyle: const TextStyle(color: textOnDark),
          actionTextColor: gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: darkSurface,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnDark,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: textOnDarkMuted,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        // Switch
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold;
            return textOnDarkMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold.withValues(alpha: 0.4);
            return textOnDarkMuted.withValues(alpha: 0.3);
          }),
        ),

        // Checkbox
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return gold;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(darkBackground),
          side: BorderSide(color: gold.withValues(alpha: 0.5), width: 1.5),
        ),

        // Progress indicators
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: gold,
          linearTrackColor: gold.withValues(alpha: 0.2),
        ),

        // List tiles
        listTileTheme: const ListTileThemeData(
          iconColor: gold,
          textColor: textOnDark,
        ),
      );
}
