import 'dart:convert';

class DiskInfo {
  final String name;
  final String mountPoint;
  final int totalSpace;
  final int availableSpace;
  final bool isRemovable;
  
  DiskInfo({
    required this.name,
    required this.mountPoint,
    required this.totalSpace,
    required this.availableSpace,
    required this.isRemovable,
  });
  
  int get usedSpace => totalSpace - availableSpace;
  
  double get usagePercentage => 
      totalSpace > 0 ? (usedSpace / totalSpace) * 100 : 0.0;
      
  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      name: json['name'] as String,
      mountPoint: json['sMountPoint'] as String,
      totalSpace: json['totalSpace'] as int,
      availableSpace: json['availableSpace'] as int,
      isRemovable: json['isRemovable'] as bool,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sMountPoint': mountPoint,
      'totalSpace': totalSpace,
      'availableSpace': availableSpace,
      'isRemovable': isRemovable,
    };
  }
}

class DiskItem {
  final String id;
  final String name;
  final int size;
  final int data;
  final bool isDirectory;
  final List<DiskItem> children;
  final String path;
  
  DiskItem({
    required this.id,
    required this.name,
    required this.size,
    required this.data,
    required this.isDirectory,
    required this.children,
    required this.path,
  });
  
  factory DiskItem.fromJson(Map<String, dynamic> json) {
    return DiskItem(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['value'] as int,
      data: json['data'] as int,
      isDirectory: json['isDirectory'] as bool,
      path: json['path'] as String? ?? '',
      children: (json['children'] as List<dynamic>?)
          ?.map((child) => DiskItem.fromJson(child as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': size,
      'data': data,
      'isDirectory': isDirectory,
      'path': path,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}

class ScanProgress {
  final int scannedItems;
  final int totalSize;
  final int errors;
  final bool isComplete;
  
  const ScanProgress({
    required this.scannedItems,
    required this.totalSize,
    required this.errors,
    required this.isComplete,
  });
  
  factory ScanProgress.fromJson(Map<String, dynamic> json) {
    return ScanProgress(
      scannedItems: json['items'] as int,
      totalSize: json['total'] as int,
      errors: json['errors'] as int,
      isComplete: json['isComplete'] as bool? ?? false,
    );
  }
}