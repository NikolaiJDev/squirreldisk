// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_screen.dart';
import 'services/disk_service.dart';
import 'services/crash_service.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging system
  await Logger.instance.initialize();
  Logger.instance.info('=== APPLICATION STARTING ===');
  
  // Initialize crash detection
  await CrashService.instance.initialize();
  
  runApp(const SquirrelDiskApp());
}

class SquirrelDiskApp extends StatelessWidget {
  const SquirrelDiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    Logger.instance.info('Building SquirrelDiskApp widget');
    
    return ChangeNotifierProvider(
      create: (_) {
        Logger.instance.info('Creating DiskService provider');
        return DiskService();
      },
      child: MaterialApp(
        title: 'SquirrelDisk',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Global error boundary
          ErrorWidget.builder = (FlutterErrorDetails details) {
            Logger.instance.error('Widget Error: ${details.exception}', details.exception, details.stack);
            return Material(
              child: Container(
                color: Theme.of(context).colorScheme.error,
                child: Center(
                  child: Text(
                    'Something went wrong!\nPlease check logs.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onError),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          };
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}