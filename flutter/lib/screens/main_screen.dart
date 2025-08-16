import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/disk_service.dart';
import '../theme/app_theme.dart';
import '../widgets/disk_item_widget.dart';
import '../widgets/custom_folder_picker.dart';
import '../widgets/scan_progress_widget.dart';
import '../widgets/optimized_disk_item_widget.dart';
import '../enums/scan_state.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SquirrelDisk - Анализатор дисков'),
        actions: [
          Consumer<DiskService>(
            builder: (context, diskService, child) {
              return PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, diskService, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Обновить диски'),
                    ),
                  ),
                  if (diskService.isScanning) ...[
                    const PopupMenuItem(
                      value: 'pause',
                      child: ListTile(
                        leading: Icon(Icons.pause),
                        title: Text('Приостановить'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'stop',
                      child: ListTile(
                        leading: Icon(Icons.stop),
                        title: Text('Остановить'),
                      ),
                    ),
                  ],
                  if (diskService.isPaused)
                    const PopupMenuItem(
                      value: 'resume',
                      child: ListTile(
                        leading: Icon(Icons.play_arrow),
                        title: Text('Продолжить'),
                      ),
                    ),
                  if (diskService.scanResults.isNotEmpty)
                    const PopupMenuItem(
                      value: 'clear',
                      child: ListTile(
                        leading: Icon(Icons.clear),
                        title: Text('Очистить результаты'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DiskService>(
        builder: (context, diskService, child) {
          if (diskService.error != null) {
            return _buildErrorWidget(context, diskService);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return _buildTabletLayout(context, diskService);
              }
              return _buildMobileLayout(context, diskService);
            },
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DiskService diskService) {
    return Column(
      children: [
        if (diskService.scanState == ScanState.idle ||
            diskService.scanResults.isEmpty) ...[
          Expanded(
            child: _buildDiskListWidget(context, diskService),
          ),
        ] else ...[
          Expanded(
            child: _buildScanResultsWidget(context, diskService),
          ),
        ],
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, DiskService diskService) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildDiskListWidget(context, diskService),
        ),
        Expanded(
          flex: 2,
          child: _buildScanResultsWidget(context, diskService),
        ),
      ],
    );
  }

  Widget _buildDiskListWidget(BuildContext context, DiskService diskService) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Доступные диски',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Выберите диск для анализа',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => diskService.refreshDisks(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить список дисков',
              ),
            ],
          ),
        ),

        // Disk list
        Expanded(
          child: diskService.isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Загрузка дисков...'),
              ],
            ),
          )
              : diskService.disks.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storage_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text('Диски не найдены'),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: diskService.disks.length + 1, // +1 for folder picker
            itemBuilder: (context, index) {
              if (index == diskService.disks.length) {
                return const CustomFolderPickerWidget();
              }

              final disk = diskService.disks[index];
              return DiskItemWidget(
                disk: disk,
                onTap: () => diskService.startScan(disk.mountPoint),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScanResultsWidget(BuildContext context, DiskService diskService) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => diskService.clearResults(),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Назад к списку дисков',
              ),
              Expanded(
                child: Text(
                  'Результаты сканирования',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${diskService.scanResults.length} элементов',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // Progress indicator during scanning
        if (diskService.scanState == ScanState.scanning)
          ScanProgressWidget(
            progress: diskService.progress,
            currentPath: diskService.currentPath,
            scannedItems: diskService.scannedItems,
            totalItems: diskService.totalItems,
            onCancel: () => diskService.stopScan(),
            onPause: () => diskService.pauseScan(),
          ),

        // Pause state indicator
        if (diskService.scanState == ScanState.paused)
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.orange[700]),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Сканирование приостановлено'),
                  ),
                  TextButton(
                    onPressed: () => diskService.resumeScan(),
                    child: const Text('Продолжить'),
                  ),
                ],
              ),
            ),
          ),

        // Results list
        Expanded(
          child: diskService.scanResults.isEmpty && diskService.scanState != ScanState.scanning
              ? Center(
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
                  'Нет результатов сканирования',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: diskService.scanResults.length,
            itemBuilder: (context, index) {
              final item = diskService.scanResults[index];
              return OptimizedDiskItemWidget(
                item: item,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Выбран: ${item.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(BuildContext context, DiskService diskService) {
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
            'Ошибка',
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
            onPressed: () => diskService.refreshDisks(),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, DiskService diskService, String action) {
    switch (action) {
      case 'refresh':
        diskService.refreshDisks();
        break;
      case 'pause':
        diskService.pauseScan();
        break;
      case 'stop':
        diskService.stopScan();
        break;
      case 'resume':
        diskService.resumeScan();
        break;
      case 'clear':
        diskService.clearResults();
        break;
    }
  }
}