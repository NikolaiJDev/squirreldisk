import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/disk_service.dart';
import '../widgets/custom_folder_picker.dart';
import '../widgets/disk_item_widget.dart';

class DiskListScreen extends StatefulWidget {
  const DiskListScreen({super.key});

  @override
  State<DiskListScreen> createState() => _DiskListScreenState();
}

class _DiskListScreenState extends State<DiskListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiskService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DiskService>(
        builder: (context, diskService, child) {
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
                    'Error loading disks',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    diskService.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => diskService.refreshDisks(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.storage,
                      color: Colors.deepPurple[300],
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SquirrelDisk',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'Disk Usage Analyzer',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => diskService.refreshDisks(),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Disks',
                    ),
                  ],
                ),
              ),

              // Disk list
              Expanded(
                child: diskService.disks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading disks...'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: diskService.disks.length + 1, // +1 for custom folder picker
                        itemBuilder: (context, index) {
                          if (index == diskService.disks.length) {
                            return const CustomFolderPickerWidget();
                          }
                          
                          final disk = diskService.disks[index];
                          return DiskItemWidget(
                            disk: disk,
                            onTap: () => _navigateToDiskDetail(context, disk),
                          );
                        },
                      ),
              ),

              // Footer with app version
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'SquirrelDisk v0.3.4 - Flutter Edition',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToDiskDetail(BuildContext context, disk) {
    Navigator.pushNamed(
      context,
      '/disk-detail',
      arguments: {
        'disk': disk.mountPoint,
        'name': disk.name,
        'used': disk.usedSpace,
        'fullscan': false,
        'isDirectory': true,
      },
    );
  }
}