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
    await refreshDisks();
  }

  Future<void> refreshDisks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _disks = await _scanBackend.getAvailableDisks();
      _error = null;
    } catch (e) {
      _error = 'Failed to load disks: ${e.toString()}';
      _disks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startScan(String path) async {
    if (_scanState == ScanState.scanning) {
      throw const DiskServiceError('Scan already in progress');
    }

    try {
      _scanState = ScanState.scanning;
      _error = null;
      _progress = 0.0;
      _scannedItems = 0;
      _totalItems = 0;
      _currentPath = null;
      _scanResults.clear();
      notifyListeners();

      _scanSubscription = _scanBackend.scanDirectory(path).listen(
            (result) {
          _scanResults.addAll(result.items);
          _progress = result.progress;
          _scannedItems = result.scannedItems;
          _totalItems = result.totalItems;
          _currentPath = result.currentPath;
          notifyListeners();
        },
        onError: (error) {
          _scanState = ScanState.error;
          _error = error.toString();
          notifyListeners();
        },
        onDone: () {
          _scanState = ScanState.completed;
          notifyListeners();
        },
      );
    } catch (e) {
      _scanState = ScanState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    await _scanBackend.cancelScan();
    _scanState = ScanState.idle;
    notifyListeners();
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

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}