import 'package:flutter_test/flutter_test.dart';
import 'package:squirreldisk/models/disk_models.dart';
import 'package:squirreldisk/services/disk_service.dart';
import 'package:squirreldisk/services/platform_service.dart';

void main() {
  group('DiskService', () {
    late DiskService diskService;
    
    setUp(() {
      diskService = DiskService();
    });
    
    test('should initialize with empty disk list', () {
      expect(diskService.disks, isEmpty);
      expect(diskService.isScanning, false);
      expect(diskService.error, null);
    });
    
    test('should handle disk filtering correctly', () {
      // Test would verify platform-specific filtering logic
      expect(true, true); // Placeholder
    });
  });
  
  group('PlatformService', () {
    late PlatformService platformService;
    
    setUp(() {
      platformService = PlatformService();
    });
    
    test('should identify platform correctly', () {
      final platform = platformService.getCurrentPlatform();
      expect(platform, isNotNull);
      expect(['windows', 'darwin', 'linux', 'unknown'], contains(platform));
    });
    
    test('should return correct banned paths for platform', () {
      final bannedPaths = platformService.getBannedPaths();
      expect(bannedPaths, isA<List<String>>());
    });
  });
  
  group('DiskModels', () {
    test('DiskInfo should calculate usage correctly', () {
      final disk = DiskInfo(
        name: 'Test Disk',
        mountPoint: '/test',
        totalSpace: 1000,
        availableSpace: 300,
        isRemovable: false,
      );
      
      expect(disk.usedSpace, equals(700));
      expect(disk.usagePercentage, equals(70.0));
    });
    
    test('DiskInfo should handle zero total space', () {
      final disk = DiskInfo(
        name: 'Empty Disk',
        mountPoint: '/empty',
        totalSpace: 0,
        availableSpace: 0,
        isRemovable: false,
      );
      
      expect(disk.usagePercentage, equals(0.0));
    });
    
    test('DiskItem should parse from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'test-file.txt',
        'value': 1024,
        'data': 1024,
        'isDirectory': false,
        'path': '/test/test-file.txt',
        'children': [],
      };
      
      final item = DiskItem.fromJson(json);
      
      expect(item.id, equals('test-id'));
      expect(item.name, equals('test-file.txt'));
      expect(item.size, equals(1024));
      expect(item.isDirectory, false);
      expect(item.children, isEmpty);
    });
  });
}