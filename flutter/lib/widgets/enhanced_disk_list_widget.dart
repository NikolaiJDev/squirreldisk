import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/disk_info.dart';
import '../services/disk_service.dart';
import '../utils/format_utils.dart';

class EnhancedDiskListWidget extends StatelessWidget {
  final List<DiskInfo> disks;
  final Function(DiskInfo)? onDiskTap;
  final Function(DiskInfo)? onScanTap;

  const EnhancedDiskListWidget({
    super.key,
    required this.disks,
    this.onDiskTap,
    this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.storage,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'SquirrelDisk',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Disk list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: disks.length,
            itemBuilder: (context, index) {
              final disk = disks[index];
              return _buildEnhancedDiskItem(context, disk);
            },
          ),
        ),

        // Folder selector section
        Container(
          margin: const EdgeInsets.all(20),
          child: _buildFolderSelector(context),
        ),
      ],
    );
  }

  Widget _buildEnhancedDiskItem(BuildContext context, DiskInfo disk) {
    final usagePercentage = disk.usagePercentage;
    final theme = Theme.of(context);

    // Determine progress bar color based on usage
    Color progressColor;
    if (usagePercentage >= 90) {
      progressColor = Colors.red;
    } else if (usagePercentage >= 75) {
      progressColor = Colors.orange;
    } else if (usagePercentage >= 50) {
      progressColor = Colors.yellow;
    } else {
      progressColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => onDiskTap?.call(disk),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Disk icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDiskIcon(disk),
                  size: 28,
                  color: theme.primaryColor,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Disk information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Disk name and drive letter
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getDiskDisplayName(disk),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${usagePercentage.toStringAsFixed(0)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Storage info
                    Row(
                      children: [
                        Text(
                          disk.formattedUsedSpace,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${disk.formattedFreeSpace} Free',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[300],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Progress bar
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: usagePercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Scan button
              IconButton(
                onPressed: () => onScanTap?.call(disk),
                icon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Right Click for a full disk scan (slower)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder_outlined,
              color: Colors.orange,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a folder to Scan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  'Choose any folder on your system to analyze',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          IconButton(
            onPressed: () => _selectCustomFolder(context),
            icon: const Icon(
              Icons.folder_open,
              color: Colors.white,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            tooltip: 'Select custom folder',
          ),
        ],
      ),
    );
  }

  void _selectCustomFolder(BuildContext context) {
    // TODO: Implement custom folder picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom folder selection coming soon')),
    );
  }

  IconData _getDiskIcon(DiskInfo disk) {
    switch (disk.type.name.toLowerCase()) {
      case 'removable':
        return Icons.usb;
      case 'cdrom':
        return Icons.album;
      case 'network':
        return Icons.lan;
      case 'ramdisk':
        return Icons.memory;
      default:
        return Icons.storage;
    }
  }

  String _getDiskDisplayName(DiskInfo disk) {
    // Extract drive letter from mount point
    final driveLetter = disk.mountPoint.isNotEmpty 
        ? disk.mountPoint.substring(0, 1).toUpperCase()
        : '';
    
    if (disk.name.contains('(') && disk.name.contains(')')) {
      // Already has drive letter in parentheses
      return disk.name;
    }
    
    // Add drive letter if not present
    if (driveLetter.isNotEmpty) {
      if (disk.name.toLowerCase().contains('windows')) {
        return 'Windows ($driveLetter:)';
      } else if (disk.name.toLowerCase().contains('local disk')) {
        return 'Local Disk ($driveLetter:)';
      } else if (disk.name.toLowerCase().contains('removable')) {
        return 'Removable Disk ($driveLetter:)';
      } else {
        return '${disk.name} ($driveLetter:)';
      }
    }
    
    return disk.name;
  }
}