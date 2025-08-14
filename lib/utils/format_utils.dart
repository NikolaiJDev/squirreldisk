class FormatUtils {
  /// Format bytes into human-readable format (e.g., 1.5 GB, 500 MB)
  static String formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 B';
    
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${suffixes[i]}';
  }
  
  /// Format a file path for display (truncate if too long)
  static String formatPath(String path, {int maxLength = 50}) {
    if (path.length <= maxLength) return path;
    
    return '...${path.substring(path.length - maxLength + 3)}';
  }
  
  /// Get file extension icon based on file name
  static String getFileIcon(String fileName, bool isDirectory) {
    if (isDirectory) return '📁';
    
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'txt':
      case 'md':
      case 'doc':
      case 'docx':
        return '📄';
      case 'pdf':
        return '📋';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return '🖼️';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return '🎬';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return '🎵';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return '🗜️';
      case 'exe':
      case 'msi':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return '⚙️';
      case 'js':
      case 'ts':
      case 'dart':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'cs':
        return '💻';
      default:
        return '📄';
    }
  }
  
  /// Format number with commas for large numbers
  static String formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
  }
  
  /// Format duration in seconds to human readable format
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    }
  }
}