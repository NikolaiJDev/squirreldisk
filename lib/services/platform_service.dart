import 'dart:io';

class PlatformService {
  /// Get the current platform name
  String getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'darwin';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
  
  /// Check if running on a desktop platform
  bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  
  /// Check if running on Linux
  bool get isLinux => Platform.isLinux;
  
  /// Check if running on macOS
  bool get isMacOS => Platform.isMacOS;
  
  /// Check if running on Windows
  bool get isWindows => Platform.isWindows;
  
  /// Get platform-specific paths to exclude from scanning
  List<String> getBannedPaths() {
    if (Platform.isLinux) {
      return ['/dev', '/mnt', '/cdrom', '/proc', '/media', '/sys', '/run'];
    } else if (Platform.isMacOS) {
      return ['/Volumes', '/System', '/private/var'];
    } else if (Platform.isWindows) {
      return ['C:\\Windows\\System32', 'C:\\ProgramData', 'C:\\\$Recycle.Bin'];
    }
    return [];
  }
  
  /// Get the default file manager command for the platform
  String getFileManagerCommand() {
    if (Platform.isWindows) {
      return 'explorer';
    } else if (Platform.isMacOS) {
      return 'open';
    } else if (Platform.isLinux) {
      return 'xdg-open';
    }
    return '';
  }
}