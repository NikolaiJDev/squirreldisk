import 'package:flutter/material.dart';

class ScanProgressWidget extends StatelessWidget {
  final double progress;
  final String? currentPath;
  final int? scannedItems;
  final int? totalItems;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;

  const ScanProgressWidget({
    Key? key,
    required this.progress,
    this.currentPath,
    this.scannedItems,
    this.totalItems,
    this.onCancel,
    this.onPause,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сканирование...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (onPause != null)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: onPause,
                    tooltip: 'Приостановить',
                  ),
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: onCancel,
                    tooltip: 'Отменить',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
            ),
            if (currentPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Текущий путь: $currentPath',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (scannedItems != null && totalItems != null) ...[
              const SizedBox(height: 4),
              Text(
                'Обработано: $scannedItems из $totalItems',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}