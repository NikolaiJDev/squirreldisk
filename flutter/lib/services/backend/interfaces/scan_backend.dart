import '../../../models/disk_info.dart';
import '../../../models/disk_item.dart';

abstract class ScanBackend {
  Stream<ScanResult> scanDirectory(String path);
  Future<List<DiskInfo>> getAvailableDisks();
  Future<void> cancelScan();
  Future<void> pauseScan();
  Future<void> resumeScan();

  bool get isScanning;
  bool get isPaused;
}

class ScanResult {
  final List<DiskItem> items;
  final double progress;
  final int scannedItems;
  final int totalItems;
  final String? currentPath;

  const ScanResult({
    required this.items,
    required this.progress,
    required this.scannedItems,
    required this.totalItems,
    this.currentPath,
  });
}