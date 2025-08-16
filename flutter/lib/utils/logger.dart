// lib/utils/logger.dart
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

class Logger {
  static Logger? _instance;
  static Logger get instance => _instance ??= Logger._internal();
  
  Logger._internal();

  File? _logFile;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get application documents directory
      final appDir = Directory.current;
      final logsDir = Directory(path.join(appDir.path, 'logs'));
      
      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Create log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final logFileName = 'squirreldisk_$timestamp.log';
      _logFile = File(path.join(logsDir.path, logFileName));

      // Initialize log file with system information
      await _writeSystemInfo();
      
      _initialized = true;
      info('Logger initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  Future<void> _writeSystemInfo() async {
    if (_logFile == null) return;

    try {
      final systemInfo = [
        '=== SQUIRRELDISK APPLICATION LOG ===',
        'Timestamp: ${DateTime.now().toIso8601String()}',
        'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'Dart Version: ${Platform.version}',
        'Executable: ${Platform.executable}',
        'Script: ${Platform.script}',
        'Environment: ${kDebugMode ? 'DEBUG' : 'RELEASE'}',
        '======================================\n',
      ];

      await _logFile!.writeAsString(systemInfo.join('\n'), mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write system info: $e');
    }
  }

  Future<void> _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) async {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logEntry = '[$timestamp] $levelStr: $message';

    // Log to console
    developer.log(message, level: _getLogLevelValue(level), error: error, stackTrace: stackTrace);
    
    // Also print to debug console for immediate visibility
    if (kDebugMode) {
      debugPrint(logEntry);
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Log to file
    if (_initialized && _logFile != null) {
      try {
        var fullEntry = '$logEntry\n';
        if (error != null) {
          fullEntry += 'Error: $error\n';
        }
        if (stackTrace != null) {
          fullEntry += 'Stack trace:\n$stackTrace\n';
        }
        fullEntry += '\n';

        await _logFile!.writeAsString(fullEntry, mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }
  }

  int _getLogLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.fatal:
        return 1200;
    }
  }

  void debug(String message) => _log(LogLevel.debug, message);
  
  void info(String message) => _log(LogLevel.info, message);
  
  void warning(String message, [Object? error]) => _log(LogLevel.warning, message, error);
  
  void error(String message, [Object? error, StackTrace? stackTrace]) => 
      _log(LogLevel.error, message, error, stackTrace);
  
  void fatal(String message, [Object? error, StackTrace? stackTrace]) => 
      _log(LogLevel.fatal, message, error, stackTrace);

  // Specific logging methods for different components
  void logDiskService(String operation, {String? detail, Object? error}) {
    final message = 'DiskService.$operation${detail != null ? ': $detail' : ''}';
    if (error != null) {
      this.error(message, error);
    } else {
      info(message);
    }
  }

  void logPluginCall(String method, Map<String, dynamic>? arguments, {Object? error}) {
    final message = 'Plugin.$method${arguments != null ? ' with args: $arguments' : ''}';
    if (error != null) {
      this.error(message, error);
    } else {
      debug(message);
    }
  }

  void logScanProgress(String path, int processed, int total, double progress) {
    debug('Scan progress: $path | $processed/$total (${(progress * 100).toStringAsFixed(1)}%)');
  }

  void logMemoryUsage(String context) {
    try {
      final info = ProcessInfo.currentRss;
      debug('Memory usage in $context: ${(info / 1024 / 1024).toStringAsFixed(2)} MB');
    } catch (e) {
      warning('Could not get memory usage for $context', e);
    }
  }

  void logFileOperation(String operation, String path, {bool success = true, Object? error}) {
    final message = 'File operation: $operation on $path';
    if (success) {
      info('$message - SUCCESS');
    } else {
      this.error('$message - FAILED', error);
    }
  }

  // Method to rotate logs if they get too large
  Future<void> rotateLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    try {
      final stat = await _logFile!.stat();
      const maxSize = 10 * 1024 * 1024; // 10MB

      if (stat.size > maxSize) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final archivePath = '${_logFile!.path}.archive_$timestamp';
        await _logFile!.copy(archivePath);
        await _logFile!.delete();
        
        // Re-initialize the log file
        _initialized = false;
        await initialize();
        info('Log rotated due to size limit. Archived to: $archivePath');
      }
    } catch (e) {
      warning('Failed to rotate logs', e);
    }
  }

  Future<String> getLogFilePath() async {
    return _logFile?.path ?? 'Log file not initialized';
  }

  Future<List<String>> getRecentLogs({int lines = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return ['Log file not available'];
    }

    try {
      final content = await _logFile!.readAsString();
      final allLines = content.split('\n');
      final recentLines = allLines.length > lines 
          ? allLines.sublist(allLines.length - lines)
          : allLines;
      return recentLines.where((line) => line.isNotEmpty).toList();
    } catch (e) {
      return ['Error reading log file: $e'];
    }
  }
}