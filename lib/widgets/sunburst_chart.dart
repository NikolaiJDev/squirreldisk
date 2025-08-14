import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/disk_models.dart';
import '../utils/format_utils.dart';

class SunburstChart extends StatefulWidget {
  final List<DiskItem> data;
  final Function(DiskItem)? onItemTap;

  const SunburstChart({
    super.key,
    required this.data,
    this.onItemTap,
  });

  @override
  State<SunburstChart> createState() => _SunburstChartState();
}

class _SunburstChartState extends State<SunburstChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  DiskItem? _hoveredItem;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('No data to display'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) - 40;
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

        return Stack(
          children: [
            // Main chart
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: SunburstPainter(
                data: widget.data,
                center: center,
                radius: size / 2,
                animation: _animation,
                hoveredItem: _hoveredItem,
              ),
            ),
            
            // Gesture detection
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (details) {
                  _tapPosition = details.localPosition;
                },
                onTap: () {
                  if (_tapPosition != null) {
                    final tappedItem = _getItemAtPosition(_tapPosition!, center, size / 2);
                    if (tappedItem != null && widget.onItemTap != null) {
                      widget.onItemTap!(tappedItem);
                    }
                  }
                },
                onPanUpdate: (details) {
                  final hoveredItem = _getItemAtPosition(details.localPosition, center, size / 2);
                  if (hoveredItem != _hoveredItem) {
                    setState(() {
                      _hoveredItem = hoveredItem;
                    });
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Hover tooltip
            if (_hoveredItem != null && _tapPosition != null)
              Positioned(
                left: _tapPosition!.dx + 10,
                top: _tapPosition!.dy - 50,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hoveredItem!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        FormatUtils.formatBytes(_hoveredItem!.size),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  DiskItem? _getItemAtPosition(Offset position, Offset center, double radius) {
    // This is a simplified implementation
    // In a real app, you'd calculate which segment was clicked based on angle and radius
    final distance = (position - center).distance;
    
    if (distance > radius) return null;
    
    // For now, return the first item as a placeholder
    // Real implementation would calculate the angle and determine the correct segment
    return widget.data.isNotEmpty ? widget.data.first : null;
  }
}

class SunburstPainter extends CustomPainter {
  final List<DiskItem> data;
  final Offset center;
  final double radius;
  final Animation<double> animation;
  final DiskItem? hoveredItem;

  SunburstPainter({
    required this.data,
    required this.center,
    required this.radius,
    required this.animation,
    this.hoveredItem,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final totalSize = data.fold<int>(0, (sum, item) => sum + item.size);
    
    double startAngle = -math.pi / 2; // Start from top
    
    // Draw segments
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final sweepAngle = (item.size / totalSize) * 2 * math.pi * animation.value;
      
      // Color based on item type and size
      final color = _getItemColor(item, i);
      paint.color = item == hoveredItem 
          ? color.withOpacity(0.8)
          : color.withOpacity(0.6);
      
      // Draw the arc
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      
      // Draw inner segments for children (simplified)
      if (item.children.isNotEmpty && item.children.length < 10) {
        _drawChildSegments(canvas, item, center, radius * 0.7, startAngle, sweepAngle, i);
      }
      
      startAngle += sweepAngle;
    }
    
    // Draw center circle
    paint.color = Theme.of(canvas as BuildContext? ?? 
        NavigatorState().overlay!.context).scaffoldBackgroundColor;
    canvas.drawCircle(center, radius * 0.3, paint);
  }
  
  void _drawChildSegments(Canvas canvas, DiskItem parent, Offset center, 
      double childRadius, double parentStart, double parentSweep, int parentIndex) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    final totalChildSize = parent.children.fold<int>(0, (sum, child) => sum + child.size);
    if (totalChildSize == 0) return;
    
    double childStart = parentStart;
    
    for (int i = 0; i < parent.children.length; i++) {
      final child = parent.children[i];
      final childSweep = (child.size / totalChildSize) * parentSweep;
      
      final childColor = _getItemColor(child, parentIndex * 10 + i);
      paint.color = child == hoveredItem 
          ? childColor.withOpacity(0.9)
          : childColor.withOpacity(0.7);
      
      final rect = Rect.fromCircle(center: center, radius: childRadius);
      canvas.drawArc(rect, childStart, childSweep, true, paint);
      
      childStart += childSweep;
    }
  }
  
  Color _getItemColor(DiskItem item, int index) {
    // Generate colors based on item type and index
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
      Colors.lime.shade400,
      Colors.cyan.shade400,
    ];
    
    if (item.isDirectory) {
      return colors[index % colors.length];
    } else {
      return colors[index % colors.length].withOpacity(0.8);
    }
  }

  @override
  bool shouldRepaint(SunburstPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
           oldDelegate.hoveredItem != hoveredItem ||
           oldDelegate.data != data;
  }
}