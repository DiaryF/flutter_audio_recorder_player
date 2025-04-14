import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Provides the application theme
class AppTheme {
  /// Creates a modern theme with Material 3 design
  static ThemeData createTheme() {
    // Define a modern color scheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6200EE),
      brightness: Brightness.light,
      secondary: const Color(0xFF03DAC6),
      tertiary: const Color(0xFFFF8A65),
    );
    
    // Create a modern theme with Google Fonts
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withAlpha(50),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withAlpha(50),
      ),
    );
  }
}
