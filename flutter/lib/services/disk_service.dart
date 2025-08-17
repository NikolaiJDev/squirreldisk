// lib/services/disk_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../enums/disk_type.dart';
import '../enums/scan_state.dart';
import '../models/disk_info.dart';
import '../models/disk_item.dart';
import '../exceptions/disk_service_error.dart';
import '../utils/logger.dart';
import '../services/crash_service.dart';
import 'backend/interfaces/scan_backend.dart';
import 'backend/channel_scan_backend.dart';

class DiskService extends ChangeNotifier {
  final ScanBackend _scanBackend = ChannelScanBackend();

  List<DiskInfo> _disks = [];
  final List<DiskItem> _scanResults = [];
  ScanState _scanState = ScanState.idle;
  String? _error;
  bool _isLoading = false;
  double _progress = 0.0;
  int _scannedItems = 0;
  int _totalItems = 0;
  String? _currentPath;
  DateTime? _scanStartTime;

  StreamSubscription? _scanSubscription;

  // Getters
  List<DiskInfo> get disks => List.unmodifiable(_disks);
  List<DiskItem> get scanResults => List.unmodifiable(_scanResults);
  ScanState get scanState => _scanState;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isScanning => _scanState == ScanState.scanning;
  bool get isPaused => _scanState == ScanState.paused;
  double get progress => _progress;
  int get scannedItems => _scannedItems;
  int get totalItems => _totalItems;
  String? get currentPath => _currentPath;

  Future<void> initialize() async {
    Logger.instance.logDiskService('initialize', detail: 'Starting disk service initialization');
    CrashService.instance.recordOperation('DiskService.initialize');
    
    try {
      await refreshDisks();
      Logger.instance.logDiskService('initialize', detail: 'Disk service initialized successfully');
    } catch (e, stackTrace) {
      Logger.instance.logDiskService('initialize', error: e);
      Logger.instance.error('Failed to initialize DiskService', e, stackTrace);
      rethrow;
    }
  }

  Future<void> refreshDisks() async {
    Logger.instance.logDiskService('refreshDisks', detail: 'Starting disk refresh');
    CrashService.instance.recordOperation('DiskService.refreshDisks');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      CrashService.instance.beforeRiskyOperation('refresh_disks');
      Logger.instance.logMemoryUsage('before_refresh_disks');
      
      _disks = await _scanBackend.getAvailableDisks();
      _error = null;
      
      Logger.instance.logDiskService('refreshDisks', detail: 'Found ${_disks.length} disks');
      CrashService.instance.afterRiskyOperation('refresh_disks', true);
      
    } catch (e, stackTrace) {
      Logger.instance.logDiskService('refreshDisks', error: e);
      Logger.instance.error('Failed to refresh disks', e, stackTrace);
      CrashService.instance.afterRiskyOperation('refresh_disks', false, error: e);
      
      _error = 'Failed to load disks: ${e.toString()}';
      _disks = [];
    } finally {
      _isLoading = false;
      Logger.instance.logMemoryUsage('after_refresh_disks');
      notifyListeners();
    }
  }

  Future<void> startScan(String path) async {
    Logger.instance.logDiskService('startScan', detail: 'Starting scan of path: $path');
    CrashService.instance.recordScanStart(path);
    
    if (_scanState == ScanState.scanning) {
      throw const DiskServiceError('Scan already in progress');
    }

    try {
      CrashService.instance.beforeRiskyOperation('start_scan', metadata: {'path': path});
      
      _scanState = ScanState.scanning;
      _error = null;
      _progress = 0.0;
      _scannedItems = 0;
      _totalItems = 0;
      _currentPath = null;
      _scanResults.clear();
      _scanStartTime = DateTime.now();
      notifyListeners();

      Logger.instance.info('Scan started for path: $path');
      Logger.instance.logMemoryUsage('scan_start');

      _scanSubscription = _scanBackend.scanDirectory(path).listen(
        (result) {
          try {
            _scanResults.addAll(result.items);
            _progress = result.progress;
            _scannedItems = result.scannedItems;
            _totalItems = result.totalItems;
            _currentPath = result.currentPath;
            
            if (result.currentPath != null) {
              CrashService.instance.recordScanProgress(result.currentPath!, result.scannedItems, result.totalItems);
            }
            
            notifyListeners();
          } catch (e, stackTrace) {
            Logger.instance.error('Error processing scan result', e, stackTrace);
          }
        },
        onError: (error, stackTrace) {
          Logger.instance.error('Scan stream error', error, stackTrace);
          CrashService.instance.recordScanError(error, stackTrace);
          
          _scanState = ScanState.error;
          _error = error.toString();
          notifyListeners();
        },
        onDone: () {
          try {
            _scanState = ScanState.completed;
            
            final duration = _scanStartTime != null 
                ? DateTime.now().difference(_scanStartTime!) 
                : const Duration(seconds: 0);
            
            Logger.instance.logDiskService('startScan', detail: 'Scan completed in ${duration.inMilliseconds}ms');
            CrashService.instance.recordScanComplete(_scanResults.length, duration);
            Logger.instance.logMemoryUsage('scan_complete');
            
            notifyListeners();
          } catch (e, stackTrace) {
            Logger.instance.error('Error in scan completion', e, stackTrace);
          }
        },
      );
      
      CrashService.instance.afterRiskyOperation('start_scan', true);
      
    } catch (e, stackTrace) {
      Logger.instance.logDiskService('startScan', error: e);
      Logger.instance.error('Failed to start scan', e, stackTrace);
      CrashService.instance.afterRiskyOperation('start_scan', false, error: e);
      
      _scanState = ScanState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    Logger.instance.logDiskService('stopScan', detail: 'Stopping scan');
    CrashService.instance.recordOperation('DiskService.stopScan');
    
    try {
      await _scanSubscription?.cancel();
      await _scanBackend.cancelScan();
      _scanState = ScanState.idle;
      
      Logger.instance.info('Scan stopped successfully');
      Logger.instance.logMemoryUsage('scan_stop');
      
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.instance.error('Error stopping scan', e, stackTrace);
      throw DiskServiceError('Failed to stop scan: ${e.toString()}');
    }
  }

  Future<void> pauseScan() async {
    if (_scanState == ScanState.scanning) {
      await _scanBackend.pauseScan();
      _scanState = ScanState.paused;
      notifyListeners();
    }
  }

  Future<void> resumeScan() async {
    if (_scanState == ScanState.paused) {
      await _scanBackend.resumeScan();
      _scanState = ScanState.scanning;
      notifyListeners();
    }
  }

  void clearResults() {
    _scanResults.clear();
    _scanState = ScanState.idle;
    _error = null;
    _progress = 0.0;
    _scannedItems = 0;
    _totalItems = 0;
    _currentPath = null;
    notifyListeners();
  }

  String get formattedTotalSize {
    final totalBytes = _scanResults.fold<int>(0, (sum, item) => sum + item.size);
    return _formatBytes(totalBytes);
  }

  List<DiskItem> getTopLargestItems({int limit = 10}) {
    final sortedItems = List<DiskItem>.from(_scanResults);
    sortedItems.sort((a, b) => b.size.compareTo(a.size));
    return sortedItems.take(limit).toList();
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  // File operation methods
  Future<void> showInFolder(String path) async {
    Logger.instance.logDiskService('showInFolder', detail: path);
    CrashService.instance.recordFileOperation('showInFolder', path, true);
    
    try {
      await _scanBackend.showInFolder(path);
      Logger.instance.info('Successfully opened folder: $path');
    } catch (e, stackTrace) {
      Logger.instance.error('Failed to show in folder: $path', e, stackTrace);
      CrashService.instance.recordFileOperation('showInFolder', path, false, e);
      _error = 'Failed to show in folder: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteFileOrFolder(String path, {bool force = false}) async {
    Logger.instance.logDiskService('deleteFileOrFolder', detail: 'path=$path, force=$force');
    CrashService.instance.recordFileOperation('delete', path, true);
    
    try {
      await _scanBackend.deleteFileOrFolder(path, force: force);
      
      // Remove the item from scan results if it exists
      final removedCount = _scanResults.length;
      _scanResults.removeWhere((item) => item.path == path);
      final finalCount = _scanResults.length;
      
      Logger.instance.info('Successfully deleted: $path (removed ${removedCount - finalCount} items from results)');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.instance.error('Failed to delete: $path', e, stackTrace);
      CrashService.instance.recordFileOperation('delete', path, false, e);
      _error = 'Failed to delete file/folder: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFileProperties(String path) async {
    Logger.instance.logDiskService('getFileProperties', detail: path);
    
    try {
      final properties = await _scanBackend.getFileProperties(path);
      Logger.instance.info('Successfully retrieved properties for: $path');
      return properties;
    } catch (e, stackTrace) {
      Logger.instance.error('Failed to get file properties: $path', e, stackTrace);
      _error = 'Failed to get file properties: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> openFile(String path) async {
    Logger.instance.logDiskService('openFile', detail: path);
    CrashService.instance.recordFileOperation('open', path, true);
    
    try {
      await _scanBackend.openFile(path);
      Logger.instance.info('Successfully opened file: $path');
    } catch (e, stackTrace) {
      Logger.instance.error('Failed to open file: $path', e, stackTrace);
      CrashService.instance.recordFileOperation('open', path, false, e);
      _error = 'Failed to open file: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    Logger.instance.logDiskService('dispose', detail: 'Disposing DiskService');
    _scanSubscription?.cancel();
    super.dispose();
  }
}