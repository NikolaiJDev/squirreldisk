import 'dart:math';

abstract class AbstractItem {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;
  final String type;

  const AbstractItem({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
    required this.type,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final int i = (log(bytes) / log(1024)).floor();
    final double value = bytes / pow(1024, i);
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  String get formattedSize => formatBytes(size);

  // Метод для расчета процента от общего размера
  double getSizePercentage(int totalSize) {
    if (totalSize == 0) return 0.0;
    return (size / totalSize) * 100;
  }

  // Абстрактный геттер для обратной совместимости
  double get sizePercentage => 0.0;

  Map<String, dynamic> toJson();

  bool get isDirectory;
  bool get isFile;
}