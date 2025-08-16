// lib/screens/adaptive_disk_analysis_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../enums/scan_state.dart';
import '../models/disk_item.dart';
import '../services/disk_service.dart';
import '../widgets/scan_progress_widget.dart';

class AdaptiveDiskAnalysisView extends StatelessWidget {
  const AdaptiveDiskAnalysisView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DiskService>(
      builder: (context, diskService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildTabletLayout(context, diskService);
            }
            return _buildMobileLayout(context, diskService);
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, DiskService diskService) {
    return Column(
      children: [
        if (diskService.scanState == ScanState.scanning)
          ScanProgressWidget(
            progress: diskService.progress,
            currentPath: diskService.currentPath,
            scannedItems: diskService.scannedItems,
            totalItems: diskService.totalItems,
          ),
        if (diskService.scanState == ScanState.paused)
          _buildPausedWidget(context, diskService),
        if (diskService.scanState == ScanState.error)
          _buildErrorWidget(context, diskService),
        Expanded(
          child: diskService.scanResults.isEmpty
              ? _buildEmptyState(context, diskService)
              : ListView.builder(
            itemCount: diskService.scanResults.length,
            itemBuilder: (context, index) {
              final item = diskService.scanResults[index];
              return ListTile(
                leading: Icon(
                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  color: item.isDirectory ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(item.formattedSize),
                trailing: item.isDirectory
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : null,
                onTap: () => _handleItemTap(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, DiskService diskService) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildMobileLayout(context, diskService),
        ),
        Expanded(
          flex: 1,
          child: _buildDetailsPanel(context, diskService),
        ),
      ],
    );
  }

  Widget _buildDetailsPanel(BuildContext context, DiskService diskService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детали анализа',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (diskService.scanResults.isNotEmpty) ...[
            _buildStatCard(
              context,
              'Всего элементов',
              diskService.scanResults.length.toString(),
              Icons.folder_outlined,
            ),
            const SizedBox(height: 8),
            _buildStatCard(
              context,
              'Общий размер',
              diskService.formattedTotalSize,
              Icons.storage,
            ),
            const SizedBox(height: 8),
            _buildStatCard(
              context,
              'Файлов',
              diskService.scanResults.where((item) => !item.isDirectory).length.toString(),
              Icons.insert_drive_file,
            ),
            const SizedBox(height: 8),
            _buildStatCard(
              context,
              'Папок',
              diskService.scanResults.where((item) => item.isDirectory).length.toString(),
              Icons.folder,
            ),
            const SizedBox(height: 16),
            Text(
              'Топ 5 самых больших',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: diskService.getTopLargestItems(limit: 5).map(
                      (item) => ListTile(
                    dense: true,
                    leading: Icon(
                      item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    ),
                    title: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.formattedSize),
                  ),
                ).toList(),
              ),
            ),
          ] else if (diskService.scanState == ScanState.idle) ...[
            const Text('Выберите папку для анализа'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedWidget(BuildContext context, DiskService diskService) {
    return Card(
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
    );
  }

  Widget _buildErrorWidget(BuildContext context, DiskService diskService) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ошибка сканирования'),
                  if (diskService.error != null)
                    Text(
                      diskService.error!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => diskService.clearResults(),
              child: const Text('Сбросить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DiskService diskService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет данных для отображения',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите папку для анализа',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(BuildContext context, DiskItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Выбран элемент: ${item.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}