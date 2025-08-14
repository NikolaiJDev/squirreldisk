import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/disk_models.dart';
import 'platform_service.dart';

class DiskService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('squirreldisk/disk');
  static const EventChannel _scanEventChannel = EventChannel('squirreldisk/scan_events');
  
  final PlatformService _platformService = PlatformService();
  
  List<DiskInfo> _disks = [];
  List<DiskItem> _scanResults = [];
  ScanProgress? _scanProgress;
  bool _isScanning = false;
  String? _error;
  
  // Getters
  List<DiskInfo> get disks => _disks;
  List<DiskItem> get scanResults => _scanResults;
  ScanProgress? get scanProgress => _scanProgress;
  bool get isScanning => _isScanning;
  String? get error => _error;
  
  StreamSubscription? _scanSubscription;
  
  /// Initialize the disk service
  Future<void> initialize() async {
    await refreshDisks();
    
    // Set up scan event listener
    _scanSubscription = _scanEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _handleScanEvent(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }
  
  /// Refresh the list of available disks
  Future<void> refreshDisks() async {
    try {
      _error = null;
      
      // For now, we'll use a platform-specific approach
      // In a full implementation, this would call native code
      final List<DiskInfo> diskList = await _getNativeDisks();
      
      // Filter disks based on platform
      final filtered = diskList.where((disk) {
        final platform = _platformService.getCurrentPlatform();
        
        if (platform == 'darwin' && 
            disk.mountPoint == '/System/Volumes/Data') {
          return false;
        }
        
        if (platform == 'linux' && 
            (disk.mountPoint == '/var/snap/firefox/common/host-hunspell' ||
             disk.mountPoint == '/boot/efi')) {
          return false;
        }
        
        return true;
      }).toList();
      
      _disks = filtered;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// Start scanning a directory
  Future<void> startScan(String path, {double minRatio = 0.01}) async {
    try {
      _error = null;
      _isScanning = true;
      _scanProgress = null;
      _scanResults = [];
      notifyListeners();
      
      await _channel.invokeMethod('startScan', {
        'path': path,
        'minRatio': minRatio.toString(),
      });
      
    } catch (e) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
    }
  }
  
  /// Stop the current scan
  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// Show a file or directory in the system file manager
  Future<void> showInFileManager(String path) async {
    try {
      await _channel.invokeMethod('showInFolder', {'path': path});
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// Handle scan events from native code
  void _handleScanEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'progress':
        _scanProgress = ScanProgress.fromJson(event);
        notifyListeners();
        break;
        
      case 'completed':
        final resultData = event['data'] as String?;
        if (resultData != null) {
          try {
            final jsonData = jsonDecode(resultData);
            if (jsonData is List) {
              _scanResults = jsonData
                  .cast<Map<String, dynamic>>()
                  .map((item) => DiskItem.fromJson(item))
                  .toList();
            }
          } catch (e) {
            _error = 'Failed to parse scan results: $e';
          }
        }
        _isScanning = false;
        notifyListeners();
        break;
        
      case 'error':
        _error = event['message'] as String?;
        _isScanning = false;
        notifyListeners();
        break;
    }
  }
  
  /// Get native disk information (placeholder implementation)
  Future<List<DiskInfo>> _getNativeDisks() async {
    // This would normally call native platform code
    // For now, return mock data based on platform
    
    if (Platform.isLinux) {
      return _getLinuxDisks();
    } else if (Platform.isMacOS) {
      return _getMacOSDisks();
    } else if (Platform.isWindows) {
      return _getWindowsDisks();
    }
    
    return [];
  }
  
  Future<List<DiskInfo>> _getLinuxDisks() async {
    // Mock implementation - would use native code in real app
    return [
      DiskInfo(
        name: '/',
        mountPoint: '/',
        totalSpace: 100000000000, // 100GB
        availableSpace: 50000000000, // 50GB available
        isRemovable: false,
      ),
    ];
  }
  
  Future<List<DiskInfo>> _getMacOSDisks() async {
    // Mock implementation - would use native code in real app
    return [
      DiskInfo(
        name: 'Macintosh HD',
        mountPoint: '/',
        totalSpace: 500000000000, // 500GB
        availableSpace: 200000000000, // 200GB available
        isRemovable: false,
      ),
    ];
  }
  
  Future<List<DiskInfo>> _getWindowsDisks() async {
    // Mock implementation - would use native code in real app
    return [
      DiskInfo(
        name: 'C:',
        mountPoint: 'C:\\',
        totalSpace: 250000000000, // 250GB
        availableSpace: 100000000000, // 100GB available
        isRemovable: false,
      ),
    ];
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}