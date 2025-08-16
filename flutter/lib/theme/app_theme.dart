import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    cardTheme: cardThemeData(),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    cardTheme: cardThemeData(),
  );

  static CardThemeData cardThemeData() {
    return const CardThemeData(
    elevation: 2,
    margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  );
  }
}