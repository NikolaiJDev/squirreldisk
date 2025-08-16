import '../enums/disk_type.dart';
import 'abstract_item.dart';

class DiskInfo {
  final String name;
  final String mountPoint;
  final int totalSpace;
  final int freeSpace;
  int usedSpace;
  final String fileSystem;
  final DiskType type;

  DiskInfo({
    required this.name,
    required this.mountPoint,
    required this.totalSpace,
    required this.freeSpace,
    required this.usedSpace,
    required this.fileSystem,
    required this.type,
  });

  double get usagePercentage {
    if (totalSpace == 0) return 0.0;
    return (usedSpace / totalSpace) * 100;
  }

  String get formattedTotalSpace => _formatBytes(totalSpace);
  String get formattedFreeSpace => _formatBytes(freeSpace);
  String get formattedUsedSpace => _formatBytes(usedSpace);

  String _formatBytes(int bytes) {
    return AbstractItem.formatBytes(bytes);
  }

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      name: json['name'] as String? ?? 'Unknown',
      mountPoint: json['mountPoint'] as String? ?? '',
      totalSpace: (json['totalSpace'] as num?)?.toInt() ?? 0,
      freeSpace: (json['freeSpace'] as num?)?.toInt() ?? 0,
      usedSpace: (json['usedSpace'] as num?)?.toInt() ?? 0,
      fileSystem: json['fileSystem'] as String? ?? 'Unknown',
      type: DiskType.diskTypeFromString(json['type'] as String?),
    );
  }

  bool get isRemovable  => DiskType.removable == type;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mountPoint': mountPoint,
      'totalSpace': totalSpace,
      'freeSpace': freeSpace,
      'usedSpace': usedSpace,
      'fileSystem': fileSystem,
      'type': type.name,
    };
  }

  @override
  String toString() {
    return 'DiskInfo(name: $name, mountPoint: $mountPoint, total: $formattedTotalSpace, free: $formattedFreeSpace)';
  }
}