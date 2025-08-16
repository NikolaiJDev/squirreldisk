import 'dart:io';

import '../exceptions/disk_service_error.dart';

class PlatformService {
  static Future<String> getDefaultScanPath() async {
    if (Platform.isWindows) {
      return 'C:\\';
    }

    if (Platform.isMacOS) {
      return '/Users';
    }

    if (Platform.isLinux) {
      return '/home';
    }

    throw const DiskServiceError('Unsupported platform');
  }

  static Future<bool> hasPermission(String path) async {
    try {
      final directory = Directory(path);
      await directory.list(followLinks: false).take(1).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getSuggestedPaths() async {
    final paths = <String>[];

    if (Platform.isWindows) {
      paths.addAll(['C:\\', 'D:\\', 'E:\\']);
    } else if (Platform.isMacOS) {
      paths.addAll(['/Users', '/Applications', '/System']);
    } else if (Platform.isLinux) {
      paths.addAll(['/home', '/var', '/usr']);
    }

    final validPaths = <String>[];
    for (final path in paths) {
      if (await Directory(path).exists()) {
        validPaths.add(path);
      }
    }

    return validPaths;
  }

  static String getDisplayName(String path) {
    if (Platform.isWindows) {
      final match = RegExp(r'^([A-Z]:)').firstMatch(path);
      if (match != null) {
        return '${match.group(1)} Drive';
      }
    }
    return path;
  }
}