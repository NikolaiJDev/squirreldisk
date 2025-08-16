import 'package:flutter/material.dart';

class AppTheme {
  // Dark theme colors to match the target screenshots
  static const Color darkBackground = Color(0xFF1A1B21);
  static const Color darkSurface = Color(0xFF23252C);
  static const Color darkCardBackground = Color(0xFF2A2D35);
  static const Color darkAccent = Color(0xFF4A90E2);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSubtext = Color(0xFFB0B3B8);
  static const Color darkBorder = Color(0xFF3A3D44);
  
  // Progress bar colors
  static const Color greenUsage = Color(0xFF4CAF50);
  static const Color yellowUsage = Color(0xFFFFC107);
  static const Color orangeUsage = Color(0xFFFF9800);
  static const Color redUsage = Color(0xFFF44336);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: darkAccent,
      brightness: Brightness.light,
    ),
    cardTheme: cardThemeData(),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      surface: darkSurface,
      onSurface: darkText,
      primary: darkAccent,
      onPrimary: Colors.white,
      secondary: darkAccent,
      onSecondary: Colors.white,
      tertiary: darkSubtext,
      onTertiary: darkText,
      outline: darkBorder,
      surfaceContainer: darkCardBackground,
    ),
    scaffoldBackgroundColor: darkBackground,
    cardTheme: cardThemeData(),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkText,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: darkCardBackground,
      textColor: darkText,
      subtitleTextStyle: TextStyle(color: darkSubtext),
    ),
    dividerTheme: DividerThemeData(
      color: darkBorder,
      thickness: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    iconTheme: IconThemeData(
      color: darkSubtext,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkText),
      bodySmall: TextStyle(color: darkSubtext),
      labelLarge: TextStyle(color: darkText),
      labelMedium: TextStyle(color: darkText),
      labelSmall: TextStyle(color: darkSubtext),
    ),
  );

  static CardThemeData cardThemeData() {
    return CardThemeData(
      color: darkCardBackground,
      elevation: 2,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkBorder, width: 1),
      ),
    );
  }

  // Helper method to get usage color based on percentage
  static Color getUsageColor(double percentage) {
    if (percentage < 50) return greenUsage;
    if (percentage < 75) return yellowUsage;
    if (percentage < 90) return orangeUsage;
    return redUsage;
  }

  // Additional color helpers
  static Color getDiskTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fixed':
        return darkAccent;
      case 'removable':
        return orangeUsage;
      case 'network':
        return Colors.purple;
      case 'cdrom':
        return Colors.teal;
      default:
        return darkSubtext;
    }
  }
}