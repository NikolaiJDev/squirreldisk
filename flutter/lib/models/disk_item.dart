import 'abstract_item.dart';

class DiskItem extends AbstractItem {
  final List<DiskItem> children;
  final int depth;
  final int? _totalSize; // Кэш для общего размера

  const DiskItem({
    required super.name,
    required super.path,
    required super.size,
    required super.lastModified,
    required super.type,
    this.children = const [],
    this.depth = 0,
    int? totalSize,
  }) : _totalSize = totalSize;

  @override
  bool get isDirectory => type == 'directory';

  @override
  bool get isFile => type == 'file';

  bool get hasChildren => children.isNotEmpty;

  int get totalFiles => children.where((item) => item.isFile).length;
  int get totalDirectories => children.where((item) => item.isDirectory).length;

  @override
  double get sizePercentage {
    if (_totalSize != null) {
      return getSizePercentage(_totalSize!);
    }
    return 0.0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'lastModified': lastModified.toIso8601String(),
      'type': type,
      'depth': depth,
      'totalSize': _totalSize,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }

  factory DiskItem.fromJson(Map<String, dynamic> json) {
    return DiskItem(
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      type: json['type'] as String,
      depth: json['depth'] as int? ?? 0,
      totalSize: json['totalSize'] as int?,
      children: (json['children'] as List<dynamic>?)
          ?.map((child) => DiskItem.fromJson(child as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  DiskItem copyWith({
    String? name,
    String? path,
    int? size,
    DateTime? lastModified,
    String? type,
    List<DiskItem>? children,
    int? depth,
    int? totalSize,
  }) {
    return DiskItem(
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      type: type ?? this.type,
      children: children ?? this.children,
      depth: depth ?? this.depth,
      totalSize: totalSize ?? _totalSize,
    );
  }

  // Метод для установки общего размера для расчета процентов
  DiskItem withTotalSize(int totalSize) {
    return copyWith(totalSize: totalSize);
  }
}