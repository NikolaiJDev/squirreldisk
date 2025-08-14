import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:squirreldisk/models/disk_models.dart';
import 'package:squirreldisk/services/disk_service.dart';
import 'package:squirreldisk/widgets/disk_item_widget.dart';
import 'package:squirreldisk/utils/app_theme.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('DiskItemWidget displays disk information correctly', (tester) async {
      final mockDisk = DiskInfo(
        name: 'Test Drive',
        mountPoint: '/test',
        totalSpace: 1000000000, // 1GB
        availableSpace: 500000000, // 500MB available
        isRemovable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DiskItemWidget(
              disk: mockDisk,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify disk name is displayed
      expect(find.text('Test Drive'), findsOneWidget);
      
      // Verify mount point is displayed
      expect(find.text('/test'), findsOneWidget);
      
      // Verify usage percentage is calculated and displayed
      expect(find.textContaining('50.0%'), findsOneWidget);
      
      // Verify disk icon is present
      expect(find.byIcon(Icons.storage), findsOneWidget);
    });

    testWidgets('DiskItemWidget shows removable icon for USB drives', (tester) async {
      final removableDisk = DiskInfo(
        name: 'USB Drive',
        mountPoint: '/media/usb',
        totalSpace: 16000000000, // 16GB
        availableSpace: 8000000000, // 8GB available
        isRemovable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DiskItemWidget(
              disk: removableDisk,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify removable USB icon is displayed
      expect(find.byIcon(Icons.usb), findsOneWidget);
    });

    testWidgets('DiskItemWidget responds to tap events', (tester) async {
      bool tapped = false;
      final mockDisk = DiskInfo(
        name: 'Test Drive',
        mountPoint: '/test',
        totalSpace: 1000000000,
        availableSpace: 500000000,
        isRemovable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DiskItemWidget(
              disk: mockDisk,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the widget
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Verify the callback was called
      expect(tapped, true);
    });

    testWidgets('AppTheme provides correct dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      final ThemeData theme = Theme.of(tester.element(find.text('Test')));
      
      // Verify it's a dark theme
      expect(theme.brightness, Brightness.dark);
      
      // Verify custom colors are applied
      expect(theme.primaryColor, const Color(0xFF9333EA));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1F2937));
    });
  });

  group('DiskService Provider Tests', () {
    testWidgets('DiskService provider integration', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DiskService>(
          create: (_) => DiskService(),
          child: MaterialApp(
            home: Consumer<DiskService>(
              builder: (context, diskService, child) {
                return Scaffold(
                  body: Column(
                    children: [
                      Text('Disks: ${diskService.disks.length}'),
                      Text('Scanning: ${diskService.isScanning}'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Disks: 0'), findsOneWidget);
      expect(find.text('Scanning: false'), findsOneWidget);
    });
  });
}