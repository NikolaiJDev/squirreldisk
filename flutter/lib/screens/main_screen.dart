import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/disk_service.dart';
import '../theme/app_theme.dart';
import '../widgets/enhanced_disk_list_widget.dart';
import '../widgets/enhanced_scan_progress_widget.dart';
import '../widgets/enhanced_results_view.dart';
import '../enums/scan_state.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiskService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiskService>(
      builder: (context, diskService, child) {
        // Show scanning progress if scanning
        if (diskService.isScanning) {
          return EnhancedScanProgressWidget(
            diskName: _getCurrentScanningDisk(diskService),
            currentPath: diskService.currentPath ?? '',
            progress: diskService.progress,
            onCancel: () => diskService.stopScan(),
          );
        }

        // Show results if scan is completed
        if (diskService.scanState == ScanState.completed && 
            diskService.scanResults.isNotEmpty) {
          return EnhancedResultsView(
            diskName: _getCurrentScanningDisk(diskService),
            items: diskService.scanResults,
            onBack: () => diskService.clearResults(),
          );
        }

        // Show main disk list
        return _buildMainDiskView(context, diskService);
      },
    );
  }

  Widget _buildMainDiskView(BuildContext context, DiskService diskService) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Empty space for symmetry
                  const SizedBox(width: 40),
                  
                  // Version info
                  Text(
                    'v. 0.3.4',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Error handling
            if (diskService.error != null)
              _buildErrorWidget(context, diskService)
            else
              Expanded(
                child: EnhancedDiskListWidget(
                  disks: diskService.disks,
                  onDiskTap: (disk) => _handleDiskTap(context, diskService, disk),
                  onScanTap: (disk) => _handleScanTap(context, diskService, disk),
                ),
              ),

            // Bottom tip
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Tip: Right Click for a full disk scan (slower)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, DiskService diskService) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Disks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            diskService.error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[300],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => diskService.refreshDisks(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _handleDiskTap(BuildContext context, DiskService diskService, dynamic disk) {
    // Show disk details or quick scan options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${disk.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${disk.formattedTotalSpace}'),
            Text('Free: ${disk.formattedFreeSpace}'),
            Text('Used: ${disk.formattedUsedSpace}'),
            Text('Usage: ${disk.usagePercentage.toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleScanTap(context, diskService, disk);
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  void _handleScanTap(BuildContext context, DiskService diskService, dynamic disk) {
    try {
      diskService.startScan(disk.mountPoint);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting scan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getCurrentScanningDisk(DiskService diskService) {
    // Try to determine which disk is being scanned from current path
    if (diskService.currentPath != null && diskService.currentPath!.isNotEmpty) {
      final path = diskService.currentPath!;
      if (path.length >= 2 && path[1] == ':') {
        final driveLetter = path[0].toUpperCase();
        final matchingDisks = diskService.disks.where(
          (d) => d.mountPoint.startsWith(driveLetter),
        ).toList();
        final disk = matchingDisks.isNotEmpty ? matchingDisks.first : null;
        return disk?.name ?? 'Disk ($driveLetter:)';
      }
    }
    
    // Fallback to first disk or generic name
    return diskService.disks.isNotEmpty 
        ? diskService.disks.first.name 
        : 'Unknown Disk';
  }
}