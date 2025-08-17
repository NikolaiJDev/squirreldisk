import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/disk_item.dart';
import '../services/disk_service.dart';
import '../widgets/sunburst_chart.dart';
import '../utils/format_utils.dart';

class EnhancedResultsView extends StatefulWidget {
  final String diskName;
  final List<DiskItem> items;
  final VoidCallback? onBack;

  const EnhancedResultsView({
    super.key,
    required this.diskName,
    required this.items,
    this.onBack,
  });

  @override
  State<EnhancedResultsView> createState() => _EnhancedResultsViewState();
}

class _EnhancedResultsViewState extends State<EnhancedResultsView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DiskItem? _selectedItem;
  final ScrollController _fileListScrollController = ScrollController();
  String _searchQuery = '';
  bool _showFileList = true;
  
  // Sorting options
  String _sortBy = 'size'; // size, name, date
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fileListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSize = widget.items.fold<int>(0, (sum, item) => sum + item.size);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Row(
        children: [
          // Left panel - Sunburst chart
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Chart header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.diskName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FormatUtils.formatBytes(totalSize),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _exportData(context),
                            icon: const Icon(Icons.save_alt, color: Colors.grey),
                            tooltip: 'Export data',
                          ),
                          IconButton(
                            onPressed: () => setState(() => _showFileList = !_showFileList),
                            icon: Icon(
                              _showFileList ? Icons.view_list : Icons.pie_chart,
                              color: Colors.grey,
                            ),
                            tooltip: _showFileList ? 'Show chart only' : 'Show file list',
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sunburst chart
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: SunburstChart(
                          data: widget.items,
                          onItemTap: (item) {
                            setState(() {
                              _selectedItem = item;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right panel - File list
          if (_showFileList)
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    left: BorderSide(color: Colors.grey[700]!, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildFileListHeader(context, totalSize),
                    _buildSearchBar(context),
                    _buildSortingOptions(context),
                    Expanded(child: _buildFileList(context)),
                    _buildDeleteZone(context),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Icon(
            Icons.storage,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'SquirrelDisk',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'All Disks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.diskName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _refreshData(context),
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettings(context),
          tooltip: 'Settings',
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildFileListHeader(BuildContext context, int totalSize) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.diskName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                FormatUtils.formatBytes(totalSize),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.items.length} items',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search files and folders...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSortingOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 8),
          _buildSortChip('Size', 'size'),
          _buildSortChip('Name', 'name'),
          _buildSortChip('Date', 'date'),
          const Spacer(),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: Colors.grey[400],
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            tooltip: _sortAscending ? 'Sort descending' : 'Sort ascending',
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) => setState(() => _sortBy = value),
        backgroundColor: Colors.transparent,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[600]!,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildFileList(BuildContext context) {
    final filteredItems = _getFilteredAndSortedItems();
    
    return ListView.builder(
      controller: _fileListScrollController,
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildFileListItem(context, item);
      },
    );
  }

  Widget _buildFileListItem(BuildContext context, DiskItem item) {
    final theme = Theme.of(context);
    final isSelected = _selectedItem?.path == item.path;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.primaryColor.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: item.isDirectory 
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            item.isDirectory ? Icons.folder : Icons.insert_drive_file,
            size: 18,
            color: item.isDirectory ? Colors.orange : Colors.blue,
          ),
        ),
        title: Text(
          item.name,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          FormatUtils.formatBytes(item.size),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[400],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
          onSelected: (value) => _handleItemAction(context, item, value),
          itemBuilder: (context) => [
            if (!item.isDirectory)
              const PopupMenuItem(
                value: 'open',
                child: ListTile(
                  leading: Icon(Icons.open_in_new, size: 16),
                  title: Text('Open', style: TextStyle(fontSize: 14)),
                ),
              ),
            const PopupMenuItem(
              value: 'show_in_folder',
              child: ListTile(
                leading: Icon(Icons.folder_open, size: 16),
                title: Text('Show in Folder', style: TextStyle(fontSize: 14)),
              ),
            ),
            const PopupMenuItem(
              value: 'properties',
              child: ListTile(
                leading: Icon(Icons.info_outline, size: 16),
                title: Text('Properties', style: TextStyle(fontSize: 14)),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                title: Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
              ),
            ),
          ],
        ),
        onTap: () => setState(() => _selectedItem = item),
        onLongPress: () => _handleItemAction(context, item, 'show_in_folder'),
      ),
    );
  }

  Widget _buildDeleteZone(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.delete_outline,
            color: Colors.red.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Drag files and folders here to delete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<DiskItem> _getFilteredAndSortedItems() {
    var items = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery);
    }).toList();

    items.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'size':
          comparison = a.size.compareTo(b.size);
          break;
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'date':
          comparison = a.lastModified.compareTo(b.lastModified);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return items;
  }

  void _handleItemAction(BuildContext context, DiskItem item, String action) async {
    final diskService = context.read<DiskService>();
    
    try {
      switch (action) {
        case 'open':
          await diskService.openFile(item.path);
          break;
        case 'show_in_folder':
          await diskService.showInFolder(item.path);
          break;
        case 'properties':
          _showItemProperties(context, item);
          break;
        case 'delete':
          _confirmDelete(context, item);
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showItemProperties(BuildContext context, DiskItem item) async {
    try {
      final diskService = context.read<DiskService>();
      final properties = await diskService.getFileProperties(item.path);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Properties - ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyRow('Path', item.path),
              _buildPropertyRow('Size', FormatUtils.formatBytes(item.size)),
              _buildPropertyRow('Type', item.isDirectory ? 'Folder' : 'File'),
              _buildPropertyRow('Modified', item.lastModified.toString()),
              if (properties['isHidden'] == true)
                _buildPropertyRow('Attributes', 'Hidden'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting properties: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DiskItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${item.isDirectory ? 'Folder' : 'File'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${item.name}"?'),
            const SizedBox(height: 16),
            Text(
              item.isDirectory 
                  ? 'This will delete the folder and all its contents.'
                  : 'This file will be moved to the recycle bin.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _performDelete(context, item),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performDelete(BuildContext context, DiskItem item) async {
    Navigator.of(context).pop(); // Close dialog
    
    try {
      final diskService = context.read<DiskService>();
      await diskService.deleteFileOrFolder(item.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting ${item.name}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportData(BuildContext context) {
    // TODO: Implement data export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _refreshData(BuildContext context) {
    // TODO: Implement data refresh
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing data...')),
    );
  }

  void _showSettings(BuildContext context) {
    // TODO: Implement settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings dialog coming soon')),
    );
  }
}