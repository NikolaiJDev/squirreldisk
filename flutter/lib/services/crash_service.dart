// lib/services/crash_service.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class CrashService {
  static CrashService? _instance;
  static CrashService get instance => _instance ??= CrashService._internal();
  
  CrashService._internal();

  bool _initialized = false;
  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.now();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up global error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        Logger.instance.fatal(
          'Flutter Error: ${details.exception}',
          details.exception,
          details.stack,
        );
      };

      // Set up isolate error handling
      Isolate.current.addErrorListener(RawReceivePort((pair) async {
        final List<dynamic> errorAndStacktrace = pair;
        Logger.instance.fatal(
          'Isolate Error: ${errorAndStacktrace[0]}',
          errorAndStacktrace[0],
          errorAndStacktrace[1] != null ? StackTrace.fromString(errorAndStacktrace[1]) : null,
        );
      }).sendPort);

      // Start heartbeat monitoring
      _startHeartbeat();
      
      _initialized = true;
      Logger.instance.info('CrashService initialized successfully');
    } catch (e) {
      Logger.instance.error('Failed to initialize CrashService', e);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _lastHeartbeat = DateTime.now();
      Logger.instance.debug('Heartbeat: Application is running normally');
      
      // Check memory usage periodically
      Logger.instance.logMemoryUsage('heartbeat');
    });
  }

  void recordOperation(String operation, {Map<String, dynamic>? metadata}) {
    Logger.instance.info('Operation: $operation${metadata != null ? ' | $metadata' : ''}');
  }

  void recordScanStart(String path) {
    Logger.instance.info('=== SCAN STARTED ===');
    Logger.instance.info('Scan path: $path');
    Logger.instance.logMemoryUsage('scan_start');
  }

  void recordScanProgress(String path, int processed, int total) {
    Logger.instance.logScanProgress(path, processed, total, processed / (total > 0 ? total : 1));
  }

  void recordScanComplete(int totalItems, Duration duration) {
    Logger.instance.info('=== SCAN COMPLETED ===');
    Logger.instance.info('Total items processed: $totalItems');
    Logger.instance.info('Duration: ${duration.inMilliseconds}ms');
    Logger.instance.logMemoryUsage('scan_complete');
  }

  void recordScanError(Object error, StackTrace? stackTrace) {
    Logger.instance.error('=== SCAN ERROR ===', error, stackTrace);
    Logger.instance.logMemoryUsage('scan_error');
  }

  void recordPluginCall(String method, Map<String, dynamic>? arguments) {
    Logger.instance.logPluginCall(method, arguments);
  }

  void recordPluginError(String method, Object error) {
    Logger.instance.logPluginCall(method, null, error: error);
  }

  void recordFileOperation(String operation, String path, bool success, [Object? error]) {
    Logger.instance.logFileOperation(operation, path, success: success, error: error);
  }

  void recordUINavigation(String from, String to) {
    Logger.instance.info('Navigation: $from -> $to');
  }

  void recordUserAction(String action, {Map<String, dynamic>? context}) {
    Logger.instance.info('User action: $action${context != null ? ' | $context' : ''}');
  }

  void recordPerformanceMetric(String metric, Duration duration, {String? context}) {
    Logger.instance.info('Performance: $metric took ${duration.inMilliseconds}ms${context != null ? ' [$context]' : ''}');
  }

  void recordResourceUsage(String resource, String usage, {String? context}) {
    Logger.instance.info('Resource usage: $resource = $usage${context != null ? ' [$context]' : ''}');
  }

  // Method to be called before potentially problematic operations
  void beforeRiskyOperation(String operation, {Map<String, dynamic>? metadata}) {
    Logger.instance.warning('BEFORE RISKY OPERATION: $operation${metadata != null ? ' | $metadata' : ''}');
    Logger.instance.logMemoryUsage('before_$operation');
  }

  // Method to be called after potentially problematic operations
  void afterRiskyOperation(String operation, bool success, {Object? error}) {
    if (success) {
      Logger.instance.info('AFTER RISKY OPERATION SUCCESS: $operation');
    } else {
      Logger.instance.error('AFTER RISKY OPERATION FAILED: $operation', error);
    }
    Logger.instance.logMemoryUsage('after_$operation');
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    Logger.instance.info('CrashService disposed');
  }

  // Get diagnostic information
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'initialized': _initialized,
      'lastHeartbeat': _lastHeartbeat.toIso8601String(),
      'uptimeSeconds': DateTime.now().difference(_lastHeartbeat).inSeconds,
    };
  }
}