import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/disk_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_progress_widget.dart';
import '../widgets/sunburst_chart.dart';
import '../enums/scan_state.dart';

class DiskDetailScreen extends StatefulWidget {
  const DiskDetailScreen({super.key});

  @override
  State<DiskDetailScreen> createState() => _DiskDetailScreenState();
}

class _DiskDetailScreenState extends State<DiskDetailScreen> {
  Map<String, dynamic>? _diskData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _diskData == null) {
      _diskData = args;
      _startScan();
    }
  }

  void _startScan() {
    if (_diskData != null) {
      final diskPath = _diskData!['disk'] as String;
      context.read<DiskService>().startScan(diskPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_diskData == null) {
      return const Scaffold(
        body: Center(
          child: Text('No disk data provided'),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Header with back button and disk info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Disk List',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _diskData!['name'] as String? ?? 'Unknown Disk',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        _diskData!['disk'] as String,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Consumer<DiskService>(
                  builder: (context, diskService, child) {
                    return Row(
                      children: [
                        if (diskService.scanState == ScanState.scanning)
                          IconButton(
                            onPressed: () => diskService.stopScan(),
                            icon: const Icon(Icons.stop),
                            tooltip: 'Stop Scan',
                          )
                        else
                          IconButton(
                            onPressed: _startScan,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Rescan',
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Consumer<DiskService>(
              builder: (context, diskService, child) {
                if (diskService.scanState == ScanState.scanning) {
                  return Column(
                    children: [
                      Expanded(
                        child: ScanProgressWidget(
                          progress: diskService.progress,
                          currentPath: diskService.currentPath,
                          scannedItems: diskService.scannedItems,
                          totalItems: diskService.totalItems,
                        ),
                      ),
                    ],
                  );
                }

                if (diskService.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan Error',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            diskService.error!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _startScan,
                          child: const Text('Retry Scan'),
                        ),
                      ],
                    ),
                  );
                }

                if (diskService.scanResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No scan data',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click the scan button to analyze this disk',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _startScan,
                          child: const Text('Start Scan'),
                        ),
                      ],
                    ),
                  );
                }

                // Show the sunburst chart with scan results
                return SunburstChart(
                  data: diskService.scanResults,
                  onItemTap: (item) {
                    // Handle item tap - could show details or navigate deeper
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tapped: ${item.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}