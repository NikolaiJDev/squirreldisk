// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_screen.dart';
import 'services/disk_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SquirrelDiskApp());
}

class SquirrelDiskApp extends StatelessWidget {
  const SquirrelDiskApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DiskService(),
      child: MaterialApp(
        title: 'SquirrelDisk',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}