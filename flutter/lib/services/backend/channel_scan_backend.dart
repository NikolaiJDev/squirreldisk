import 'dart:async';

import 'package:flutter/services.dart';

import '../../../exceptions/disk_service_error.dart';
import '../../../models/disk_info.dart';
import '../../models/disk_item.dart';
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
    if (_isScanning) {
      throw const DiskServiceError('Scan already in progress');
    }

    _isScanning = true;
    final controller = StreamController<ScanResult>();

    try {
      await _channel.invokeMethod('startScan', {'path': path});

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
            (event) {
          final result = _parseEventData(event);
          if (result != null) {
            controller.add(result);
          }
        },
        onError: (error) {
          controller.addError(DiskServiceError('Platform error: $error'));
        },
        onDone: () {
          controller.close();
        },
      );

      yield* controller.stream;
    } finally {
      _isScanning = false;
      await _eventSubscription?.cancel();
      _eventSubscription = null;
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
    try {
      final result = await _channel.invokeMethod('getDisks');
      final disks = (result as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      return disks.map((disk) => DiskInfo.fromJson(disk)).toList();
    } on PlatformException catch (e) {
      throw DiskServiceError('Failed to get available disks: ${e.message}');
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