import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/disk_service.dart';

class CustomFolderPickerWidget extends StatelessWidget {
  const CustomFolderPickerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pickFolder(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Folder icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder_open,
                  size: 32,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 16),

              // Text information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выбрать папку',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Анализировать любую папку на вашей системе',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
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

  Future<void> _pickFolder(BuildContext context) async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && context.mounted) {
        // Используем DiskService напрямую вместо навигации
        context.read<DiskService>().startScan(selectedDirectory);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора папки: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }
}