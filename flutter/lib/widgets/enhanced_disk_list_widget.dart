import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squirreldisk/enums/disk_type.dart';

import '../models/disk_info.dart';
import '../services/disk_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/logger.dart';

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
    Logger.instance.debug('Building EnhancedDiskListWidget with ${disks.length} disks');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with improved styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // App icon with orange squirrel color
              Icon(
                Icons.storage,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'SquirrelDisk',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Disk list with improved cards
        Expanded(
          child: disks.isEmpty 
            ? _buildEmptyState(context)
            : ListView.builder(
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
    
    // Use AppTheme colors for consistency
    final progressColor = AppTheme.getUsageColor(usagePercentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => onDiskTap?.call(disk),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Disk icon with proper styling
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Icon(
                  _getDiskIcon(disk),
                  size: 28,
                  color: AppTheme.getDiskTypeColor(disk.type.toString().toLowerCase()),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Disk information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Disk name and percentage
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getDiskDisplayName(disk),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${usagePercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
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
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkSubtext,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${disk.formattedFreeSpace} Free',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkSubtext,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Progress bar with exact styling from screenshot
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: usagePercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [
                                    progressColor,
                                    progressColor.withValues(alpha: 0.8),
                                  ],
                                ),
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
              
              // Scan button with proper styling
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: IconButton(
                  onPressed: () => onScanTap?.call(disk),
                  icon: Icon(
                    Icons.search,
                    color: AppTheme.darkSubtext,
                    size: 18,
                  ),
                  tooltip: 'Scan disk',
                  splashRadius: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Folder icon with proper styling  
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Icon(
              Icons.folder_outlined,
              color: Colors.orange.shade600,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Text content
          const Expanded(
            child: Text(
              'Select a folder to Scan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage_outlined,
            size: 64,
            color: AppTheme.darkSubtext,
          ),
          SizedBox(height: 16),
          Text(
            'No disks found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check your system connections',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkSubtext,
            ),
          ),
        ],
      ),
    );
  }

  void _selectCustomFolder(BuildContext context) {
    // TODO: Implement custom folder picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom folder selection coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  IconData _getDiskIcon(DiskInfo disk) {

    switch (disk.type) {
      case DiskType.removable:
        return Icons.usb;
      case DiskType.cdrom:
        return Icons.album;
      case DiskType.network:
        return Icons.lan;
      case DiskType.ram:
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
      } else if (disk.name.toLowerCase().contains('gaming')) {
        return 'Gaming ($driveLetter:)';
      } else if (disk.name.toLowerCase().contains('development')) {
        return 'Development ($driveLetter:)';
      } else if (disk.name.toLowerCase().contains('repository')) {
        return 'Repository ($driveLetter:)';
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