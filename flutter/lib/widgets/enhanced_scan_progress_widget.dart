import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';

class EnhancedScanProgressWidget extends StatefulWidget {
  final String diskName;
  final String currentPath;
  final double progress;
  final VoidCallback? onCancel;

  const EnhancedScanProgressWidget({
    super.key,
    required this.diskName,
    required this.currentPath,
    required this.progress,
    this.onCancel,
  });

  @override
  State<EnhancedScanProgressWidget> createState() => _EnhancedScanProgressWidgetState();
}

class _EnhancedScanProgressWidgetState extends State<EnhancedScanProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    Logger.instance.info('Scan progress widget initialized for disk: ${widget.diskName}');
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Logger.instance.debug('Building scan progress widget with ${(widget.progress * 100).toStringAsFixed(1)}% progress');
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Navigation breadcrumb
                  _buildBreadcrumb(),
                  
                  const Spacer(),
                  
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.darkText,
                      size: 24,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated disk icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppTheme.darkCardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.darkBorder,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.storage,
                              size: 64,
                              color: AppTheme.darkAccent,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Scanning text with percentage
                    Text(
                      'Scanning ${widget.diskName} ${(widget.progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Progress bar
                    Container(
                      width: 400,
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
                            widthFactor: widget.progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.darkAccent,
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.darkAccent,
                                    AppTheme.darkAccent.withValues(alpha: 0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Cancel button
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Row(
      children: [
        Icon(
          Icons.storage,
          color: Colors.orange.shade600,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'SquirrelDisk',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right,
          color: AppTheme.darkSubtext,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'All Disks',
          style: TextStyle(
            color: AppTheme.darkSubtext,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right,
          color: AppTheme.darkSubtext,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          widget.diskName,
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Progress bar
            Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue,
                            Colors.lightBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Current path being scanned
            if (widget.currentPath.isNotEmpty) ...[
              Text(
                'Scanning:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(
                  widget.currentPath,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Cancel button
            OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MultiDiskScanProgressWidget extends StatefulWidget {
  final List<DiskScanProgress> diskProgresses;
  final VoidCallback? onCancel;

  const MultiDiskScanProgressWidget({
    super.key,
    required this.diskProgresses,
    this.onCancel,
  });

  @override
  State<MultiDiskScanProgressWidget> createState() => _MultiDiskScanProgressWidgetState();
}

class _MultiDiskScanProgressWidgetState extends State<MultiDiskScanProgressWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _pulseAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      widget.diskProgresses.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1500 + (index * 200)),
        vsync: this,
      ),
    );
    
    _pulseAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
    
    for (var controller in _animationControllers) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Multi-Disk Scanning',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Overall progress header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Scanning Multiple Disks',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_getCompletedCount()} of ${widget.diskProgresses.length} completed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
          
          // Individual disk progress cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.diskProgresses.length,
              itemBuilder: (context, index) {
                final diskProgress = widget.diskProgresses[index];
                return _buildDiskProgressCard(context, diskProgress, index);
              },
            ),
          ),
          
          // Cancel button
          Padding(
            padding: const EdgeInsets.all(24),
            child: OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel All',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiskProgressCard(BuildContext context, DiskScanProgress diskProgress, int index) {
    final theme = Theme.of(context);
    final isCompleted = diskProgress.progress >= 1.0;
    final isScanning = diskProgress.progress > 0.0 && diskProgress.progress < 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? Colors.green.withValues(alpha: 0.5)
              : isScanning 
                  ? Colors.blue.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Animated disk icon
            AnimatedBuilder(
              animation: _pulseAnimations[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: isScanning ? _pulseAnimations[index].value : 1.0,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.2)
                          : isScanning
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCompleted 
                          ? Icons.check_circle 
                          : Icons.storage,
                      size: 32,
                      color: isCompleted
                          ? Colors.green
                          : isScanning
                              ? Colors.blue
                              : Colors.grey,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(width: 16),
            
            // Disk info and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diskProgress.diskName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    _getStatusText(diskProgress),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[300],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Progress bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: diskProgress.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCompleted 
                              ? Colors.green 
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Progress percentage
            Text(
              '${(diskProgress.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isCompleted 
                    ? Colors.green 
                    : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCompletedCount() {
    return widget.diskProgresses
        .where((progress) => progress.progress >= 1.0)
        .length;
  }

  String _getStatusText(DiskScanProgress progress) {
    if (progress.progress >= 1.0) {
      return 'Scan completed';
    } else if (progress.progress > 0.0) {
      return 'Scanning... ${progress.currentPath}';
    } else {
      return 'Waiting to start...';
    }
  }
}

class DiskScanProgress {
  final String diskName;
  final String diskPath;
  final double progress;
  final String currentPath;
  final bool isCompleted;

  DiskScanProgress({
    required this.diskName,
    required this.diskPath,
    required this.progress,
    this.currentPath = '',
    this.isCompleted = false,
  });

  DiskScanProgress copyWith({
    String? diskName,
    String? diskPath,
    double? progress,
    String? currentPath,
    bool? isCompleted,
  }) {
    return DiskScanProgress(
      diskName: diskName ?? this.diskName,
      diskPath: diskPath ?? this.diskPath,
      progress: progress ?? this.progress,
      currentPath: currentPath ?? this.currentPath,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}