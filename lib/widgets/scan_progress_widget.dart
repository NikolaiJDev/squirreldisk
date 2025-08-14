import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/disk_service.dart';
import '../utils/format_utils.dart';

class ScanProgressWidget extends StatelessWidget {
  const ScanProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DiskService>(
      builder: (context, diskService, child) {
        final progress = diskService.scanProgress;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scanning animation
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.search,
                      size: 40,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Status text
              Text(
                'Scanning Directory',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Analyzing file system structure...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade400,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Progress information
              if (progress != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildProgressItem(
                        context,
                        'Scanned Items',
                        FormatUtils.formatNumber(progress.scannedItems),
                        Icons.description,
                      ),
                      const SizedBox(height: 12),
                      _buildProgressItem(
                        context,
                        'Total Size Found',
                        FormatUtils.formatBytes(progress.totalSize),
                        Icons.storage,
                      ),
                      if (progress.errors > 0) ...[
                        const SizedBox(height: 12),
                        _buildProgressItem(
                          context,
                          'Errors',
                          progress.errors.toString(),
                          Icons.warning,
                          color: Colors.orange.shade400,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
              
              // Cancel button
              OutlinedButton(
                onPressed: () => diskService.stopScan(),
                child: const Text('Cancel Scan'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildProgressItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final itemColor = color ?? Theme.of(context).primaryColor;
    
    return Row(
      children: [
        Icon(
          icon,
          color: itemColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: itemColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}