import 'package:flutter/material.dart';

import '../models/abstract_item.dart';
import '../models/disk_item.dart';

class OptimizedDiskItemWidget extends StatelessWidget {
  final AbstractItem item;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showProgress;

  const OptimizedDiskItemWidget({
    Key? key,
    required this.item,
    this.onTap,
    this.isSelected = false,
    this.showProgress = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: _buildIcon(),
        title: Text(
          item.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.formattedSize),
            if (showProgress && item.sizePercentage > 0) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: item.sizePercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getColorBySize()),
              ),
            ],
            if (item is DiskItem) ..._buildDiskItemInfo(item as DiskItem),
          ],
        ),
        trailing: item.sizePercentage > 0
            ? Text('${item.sizePercentage.toStringAsFixed(1)}%')
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;

    if (item.isDirectory) {
      iconData = Icons.folder;
    } else {
      iconData = _getFileIcon();
    }

    return CircleAvatar(
      backgroundColor: _getColorBySize(),
      child: Icon(
        iconData,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = item.name.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'exe':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }

  List<Widget> _buildDiskItemInfo(DiskItem diskItem) {
    if (!diskItem.hasChildren) return [];

    return [
      const SizedBox(height: 2),
      Text(
        '${diskItem.totalFiles} файлов, ${diskItem.totalDirectories} папок',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ];
  }

  Color _getColorBySize() {
    if (item.sizePercentage > 50) return Colors.red;
    if (item.sizePercentage > 25) return Colors.orange;
    if (item.sizePercentage > 10) return Colors.blue;
    return Colors.green;
  }
}