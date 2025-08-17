import 'dart:async';

import 'package:flutter/services.dart';

import '../../exceptions/disk_service_error.dart';
import '../../models/disk_info.dart';
import '../../models/disk_item.dart';
import '../../utils/logger.dart';
import '../../services/crash_service.dart';
import 'interfaces/scan_backend.dart';

class ChannelScanBackend implements ScanBackend {
  static const MethodChannel _channel = MethodChannel('squirreldisk');
  static const EventChannel _eventChannel = EventChannel('squirreldisk_events');

  bool _isScanning = false;
  bool _isPaused = false;
  StreamSubscription? _eventSubscription;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get isPaused => _isPaused;

  @override
  Stream<ScanResult> scanDirectory(String path) async* {
    Logger.instance.debug('ChannelScanBackend.scanDirectory called for path: $path');
    CrashService.instance.recordPluginCall('startScan', {'path': path});
    
    if (_isScanning) {
      throw const DiskServiceError('Scan already in progress');
    }

    _isScanning = true;
    final controller = StreamController<ScanResult>();

    try {
      Logger.instance.info('Invoking startScan method with path: $path');
      await _channel.invokeMethod('startScan', {'path': path});

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          try {
            final result = _parseEventData(event);
            if (result != null) {
              controller.add(result);
            }
          } catch (e, stackTrace) {
            Logger.instance.error('Error parsing scan event data', e, stackTrace);
          }
        },
        onError: (error) {
          Logger.instance.error('Scan event stream error', error);
          CrashService.instance.recordPluginError('scanDirectory', error);
          controller.addError(DiskServiceError('Platform error: $error'));
        },
        onDone: () {
          Logger.instance.info('Scan event stream completed');
          controller.close();
        },
      );

      yield* controller.stream;
    } catch (e, stackTrace) {
      Logger.instance.error('Error in scanDirectory', e, stackTrace);
      CrashService.instance.recordPluginError('scanDirectory', e);
      rethrow;
    } finally {
      _isScanning = false;
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      Logger.instance.debug('Scan directory operation completed');
    }
  }

  ScanResult? _parseEventData(dynamic event) {
    if (event is Map<String, dynamic>) {
      final items = (event['items'] as List?)?.map((item) =>
          DiskItem.fromJson(item as Map<String, dynamic>)).toList() ?? [];

      return ScanResult(
        items: items,
        progress: (event['progress'] as num?)?.toDouble() ?? 0.0,
        scannedItems: event['scannedItems'] as int? ?? 0,
        totalItems: event['totalItems'] as int? ?? 0,
        currentPath: event['currentPath'] as String?,
      );
    }
    return null;
  }

  @override
  Future<List<DiskInfo>> getAvailableDisks() async {
    Logger.instance.debug('ChannelScanBackend.getAvailableDisks called');
    CrashService.instance.recordPluginCall('getDisks', null);
    
    try {
      final result = await _channel.invokeMethod('getDisks');
      
      // Handle the new enhanced format from Windows plugin
      if (result is Map) {
        final disks = (result['disks'] as List?)?.map((e) => 
          Map<String, dynamic>.from(e as Map)).toList() ?? [];
        Logger.instance.info('Retrieved ${disks.length} disks from plugin (enhanced format)');
        return disks.map((disk) => DiskInfo.fromJson(disk)).toList();
      } else {
        // Fallback for old format
        final disks = (result as List?)?.map((e) => 
          Map<String, dynamic>.from(e as Map)).toList() ?? [];
        Logger.instance.info('Retrieved ${disks.length} disks from plugin (legacy format)');
        return disks.map((disk) => DiskInfo.fromJson(disk)).toList();
      }
    } on PlatformException catch (e) {
      Logger.instance.error('Platform error getting disks', e);
      CrashService.instance.recordPluginError('getDisks', e);
      throw DiskServiceError('Failed to get available disks: ${e.message}');
    }
  }

  // Add new methods for enhanced Windows plugin functionality
  @override
  Future<void> showInFolder(String path) async {
    try {
      await _channel.invokeMethod('showInFolder', {'path': path});
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to show in folder: ${e.message}');
    }
  }

  @override
  Future<void> deleteFileOrFolder(String path, {bool force = false}) async {
    try {
      await _channel.invokeMethod('deleteFileOrFolder', {
        'path': path,
        'force': force,
      });
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to delete file/folder: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getFileProperties(String path) async {
    try {
      final result = await _channel.invokeMethod('getFileProperties', {'path': path});
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to get file properties: ${e.message}');
    }
  }

  @override
  Future<void> openFile(String path) async {
    try {
      await _channel.invokeMethod('openFile', {'path': path});
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to open file: ${e.message}');
    }
  }

  @override
  Future<void> cancelScan() async {
    try {
      await _channel.invokeMethod('stopScan');
      _isScanning = false;
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to cancel scan: ${e.message}');
    }
  }

  @override
  Future<void> pauseScan() async {
    try {
      await _channel.invokeMethod('pauseScan');
      _isPaused = true;
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to pause scan: ${e.message}');
    }
  }

  @override
  Future<void> resumeScan() async {
    try {
      await _channel.invokeMethod('resumeScan');
      _isPaused = false;
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to resume scan: ${e.message}');
    }
  }
}