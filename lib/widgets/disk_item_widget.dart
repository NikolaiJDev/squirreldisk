import 'package:flutter/material.dart';
import '../models/disk_models.dart';
import '../utils/format_utils.dart';

class DiskItemWidget extends StatelessWidget {
  final DiskInfo disk;
  final VoidCallback? onTap;

  const DiskItemWidget({
    super.key,
    required this.disk,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Disk icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  disk.isRemovable ? Icons.usb : Icons.storage,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Disk information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disk.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disk.mountPoint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Usage bar
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Progress bar
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: disk.usagePercentage / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _getUsageColor(disk.usagePercentage),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 4),
                              
                              // Usage text
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${FormatUtils.formatBytes(disk.usedSpace)} used',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${FormatUtils.formatBytes(disk.totalSpace)} total',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Usage percentage
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getUsageColor(disk.usagePercentage).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${disk.usagePercentage.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _getUsageColor(disk.usagePercentage),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUsageColor(double percentage) {
    if (percentage > 90) {
      return Colors.red.shade400;
    } else if (percentage > 75) {
      return Colors.orange.shade400;
    } else if (percentage > 50) {
      return Colors.yellow.shade400;
    } else {
      return Colors.green.shade400;
    }
  }
}