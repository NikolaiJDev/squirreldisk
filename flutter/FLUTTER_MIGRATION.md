# Flutter Migration Guide - SquirrelDisk

## Overview

This document provides a comprehensive guide for the migration from the original Rust + TypeScript (Tauri) implementation to Flutter/Dart.

## Architecture Comparison

### Original Tauri Architecture
```
┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │
│   (React/TS)    │◄──►│    (Rust)       │
│   - UI Components│    │   - Disk Ops    │
│   - D3.js Charts│    │   - File System │
│   - State Mgmt  │    │   - Native APIs │
└─────────────────┘    └─────────────────┘
```

### New Flutter Architecture
```
┌─────────────────┐    ┌─────────────────┐
│   Flutter UI    │    │   Platform      │
│   (Dart)        │◄──►│   Channels      │
│   - Widgets     │    │   (Native)      │
│   - Custom Paint│    │   - C++/Swift   │
│   - Provider    │    │   - Disk APIs   │
└─────────────────┘    └─────────────────┘
```

## Migration Mapping

### File Structure Migration

| Original (Tauri) | New (Flutter) | Purpose |
|------------------|---------------|---------|
| `src/App.tsx` | `lib/main.dart` | Main application entry |
| `src/components/DiskList.tsx` | `lib/screens/disk_list_screen.dart` | Disk listing UI |
| `src/components/DiskDetail.tsx` | `lib/screens/disk_detail_screen.dart` | Disk detail view |
| `src/d3chart.ts` | `lib/widgets/sunburst_chart.dart` | Visualization |
| `src-tauri/src/main.rs` | Platform channels | Native operations |
| `src-tauri/src/scan.rs` | `lib/services/disk_service.dart` | Scanning logic |

### Functionality Migration

#### 1. Disk Enumeration
**Tauri (Rust):**
```rust
#[tauri::command]
fn get_disks() -> String {
    let mut sys = System::new_all();
    sys.refresh_all();
    // ... sysinfo implementation
}
```

**Flutter (Platform Channel):**
```dart
Future<List<DiskInfo>> _getNativeDisks() async {
  try {
    final result = await _channel.invokeMethod('getDrives');
    return result.map((disk) => DiskInfo.fromJson(disk)).toList();
  } catch (e) {
    throw Exception('Failed to get disks: $e');
  }
}
```

#### 2. Directory Scanning
**Tauri (Rust):**
```rust
pub fn start(app_handle: tauri::AppHandle, path: String, ratio: String) -> Result<(), ()> {
    // Uses parallel-disk-usage crate
    // Emits events through Tauri's event system
}
```

**Flutter (Service + Platform Channel):**
```dart
Future<void> startScan(String path, {double minRatio = 0.01}) async {
  await _channel.invokeMethod('startScan', {
    'path': path,
    'minRatio': minRatio.toString(),
  });
}
```

#### 3. UI Components
**Tauri (React):**
```typescript
const DiskItem: React.FC<{disk: DiskInfo}> = ({disk}) => {
  return (
    <div className="disk-item">
      {/* JSX template */}
    </div>
  );
};
```

**Flutter (Widget):**
```dart
class DiskItemWidget extends StatelessWidget {
  final DiskInfo disk;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: // Widget tree
    );
  }
}
```

## Platform-Specific Implementation

### Windows (C++)
- Uses Win32 APIs for disk enumeration (`GetLogicalDrives`, `GetDiskFreeSpaceEx`)
- `ShellExecute` for opening folders
- Directory traversal using `std::filesystem`

### macOS (Swift)
- Uses Foundation APIs (`FileManager.default.mountedVolumeURLs`)
- `NSWorkspace.shared.selectFile` for Finder integration
- Process spawning for `du` command equivalent

### Linux (C++/GTK)
- Parses `/proc/mounts` for mount points
- Uses `statvfs` for disk space information
- `xdg-open` for file manager integration

## State Management Migration

### Original (React + Hooks)
```typescript
const [disks, setDisks] = useState([]);
const [isScanning, setIsScanning] = useState(false);

useEffect(() => {
  // Side effects
}, [dependencies]);
```

### Flutter (Provider)
```dart
class DiskService extends ChangeNotifier {
  List<DiskInfo> _disks = [];
  bool _isScanning = false;
  
  // Getters
  List<DiskInfo> get disks => _disks;
  bool get isScanning => _isScanning;
  
  // Methods that call notifyListeners()
}
```

## Visualization Migration

### D3.js → Custom Flutter Painter

**Original D3.js:**
```typescript
const partition = d3.partition()
    .size([2 * Math.PI, radius]);

const arc = d3.arc()
    .startAngle(d => d.x0)
    .endAngle(d => d.x1)
    .innerRadius(d => d.y0)
    .outerRadius(d => d.y1);
```

**Flutter CustomPainter:**
```dart
class SunburstPainter extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Calculate angles and radii
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
  }
}
```

## Dependencies Comparison

### Tauri Dependencies
```toml
[dependencies]
tauri = { version = "1.2", features = ["api-all"] }
sysinfo = "0.27.7"
window-vibrancy = "0.3.2"
parallel-disk-usage = "0.8.3"
```

```json
{
  "dependencies": {
    "@tauri-apps/api": "^1.2.0",
    "d3": "^7.8.2",
    "react": "^18.2.0",
    "react-router-dom": "^6.8.0"
  }
}
```

### Flutter Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  path_provider: ^2.1.1
  file_picker: ^6.1.1
  fl_chart: ^0.65.0
  window_manager: ^0.3.7
```

## Testing Strategy

### Unit Tests
```dart
// test/services/disk_service_test.dart
void main() {
  group('DiskService', () {
    test('should parse disk information correctly', () {
      // Test implementation
    });
  });
}
```

### Widget Tests
```dart
// test/widgets/disk_item_widget_test.dart
void main() {
  testWidgets('DiskItemWidget displays disk information', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DiskItemWidget(disk: mockDisk),
    ));
    
    expect(find.text(mockDisk.name), findsOneWidget);
  });
}
```

### Integration Tests
```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('App Integration Tests', () {
    testWidgets('full app flow', (tester) async {
      // Test complete user workflow
    });
  });
}
```

## Build and Distribution

### Development
```bash
# Run on specific platforms
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Hot reload for rapid development
# (Flutter's hot reload vs Tauri's dev server)
```

### Release Builds
```bash
# Windows
flutter build windows --release

# macOS  
flutter build macos --release

# Linux
flutter build linux --release
```

### Packaging Comparison
- **Tauri**: Creates platform installers (.msi, .dmg, .deb)
- **Flutter**: Produces platform-specific bundles that need separate packaging

## Performance Considerations

### Advantages of Flutter Migration
1. **Single Codebase**: Dart for both UI and business logic
2. **Native Performance**: Compiled to native machine code
3. **Efficient Rendering**: Flutter's rendering engine optimized for 60fps
4. **Memory Management**: Dart's garbage collector vs manual Rust memory management

### Potential Challenges
1. **Bundle Size**: Flutter apps can be larger than Tauri apps
2. **Platform Integration**: More complex than Tauri's unified approach
3. **Learning Curve**: Team needs Dart/Flutter expertise vs TypeScript/Rust

## Migration Benefits

### Developer Experience
- Single language (Dart) for entire application
- Hot reload for rapid development
- Rich debugging tools
- Comprehensive widget library

### User Experience  
- Consistent UI across platforms
- Smooth animations and transitions
- Native platform integration
- Better performance characteristics

### Maintenance
- Simplified architecture
- Better separation of concerns
- Easier to test and debug
- More predictable behavior

## Future Enhancements

### Planned Features
1. **Enhanced Visualization**: More chart types using Flutter's painting system
2. **Better Platform Integration**: Native file operations
3. **Performance Optimizations**: Efficient scanning algorithms
4. **Mobile Support**: Potential Android/iOS versions

### Technical Debt Addressed
1. **State Management**: From React hooks to Provider pattern
2. **Platform Consistency**: Unified Flutter theming system
3. **Code Organization**: Better separation of concerns
4. **Testing**: Comprehensive test coverage

This migration represents a significant modernization of the SquirrelDisk codebase, providing a solid foundation for future development and enhanced user experience across all supported platforms.