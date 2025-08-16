# Build and Deployment Guide - SquirrelDisk Flutter

## Development Environment Setup

### Prerequisites

1. **Flutter SDK**: Version 3.10.0 or higher
2. **Dart SDK**: Included with Flutter
3. **Platform-specific requirements**:
   - **Windows**: Visual Studio 2019+ with C++ desktop development tools
   - **macOS**: Xcode 12+ with Command Line Tools
   - **Linux**: GTK development libraries, Clang

### Installation Steps

1. **Install Flutter**:
```bash
# Download and extract Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

2. **Platform Setup**:
```bash
# Windows
flutter config --enable-windows-desktop

# macOS  
flutter config --enable-macos-desktop

# Linux
flutter config --enable-linux-desktop
```

3. **Project Dependencies**:
```bash
cd squirreldisk
flutter pub get
```

## Development Workflow

### Running in Development

```bash
# Hot reload development on specific platform
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Debug mode with verbose logging
flutter run -d windows --debug -v

# Profile mode for performance testing
flutter run -d windows --profile
```

### Code Quality

```bash
# Static analysis
flutter analyze

# Format code
dart format lib/ test/

# Run tests
flutter test

# Generate coverage
flutter test --coverage
lcov --summary coverage/lcov.info
```

## Build Configuration

### Release Builds

1. **Windows**:
```bash
flutter build windows --release

# Output: build/windows/runner/Release/
# Main executable: squirreldisk.exe
# Required DLLs are included automatically
```

2. **macOS**:
```bash
flutter build macos --release

# Output: build/macos/Build/Products/Release/
# App bundle: SquirrelDisk.app
```

3. **Linux**:
```bash
flutter build linux --release

# Output: build/linux/x64/release/bundle/
# Executable: squirreldisk
# Shared libraries included in bundle
```

### Build Optimization

```bash
# Optimize bundle size
flutter build windows --release --tree-shake-icons

# Enable obfuscation (production builds)
flutter build windows --release --obfuscate --split-debug-info=debug-info/

# Target specific architecture
flutter build windows --release --target-platform windows-x64
```

## Packaging for Distribution

### Windows

1. **Using Inno Setup** (recommended):
```pascal
; squirreldisk.iss
[Setup]
AppName=SquirrelDisk
AppVersion=0.3.4
DefaultDirName={autopf}\SquirrelDisk
OutputBaseFilename=SquirrelDisk-Setup

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{autodesktop}\SquirrelDisk"; Filename: "{app}\squirreldisk.exe"
Name: "{autoprograms}\SquirrelDisk"; Filename: "{app}\squirreldisk.exe"
```

2. **Build installer**:
```bash
iscc squirreldisk.iss
```

### macOS

1. **Create DMG**:
```bash
# Create app bundle structure
cp -r build/macos/Build/Products/Release/SquirrelDisk.app dist/

# Create DMG
hdiutil create -volname "SquirrelDisk" -srcfolder dist -ov -format UDZO SquirrelDisk.dmg
```

2. **Code signing** (for distribution):
```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name" SquirrelDisk.app

# Create signed DMG
codesign --force --sign "Developer ID Application: Your Name" SquirrelDisk.dmg
```

### Linux

1. **Create AppImage**:
```bash
# Install linuxdeploy
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

# Create AppImage
./linuxdeploy-x86_64.AppImage --appdir AppDir --executable build/linux/x64/release/bundle/squirreldisk --desktop-file squirreldisk.desktop --icon-file assets/icon.png --output appimage
```

2. **Create DEB package**:
```bash
# Create package structure
mkdir -p debian-package/DEBIAN
mkdir -p debian-package/usr/bin
mkdir -p debian-package/usr/share/applications
mkdir -p debian-package/usr/share/icons/hicolor/256x256/apps

# Copy files
cp -r build/linux/x64/release/bundle/* debian-package/usr/bin/
cp squirreldisk.desktop debian-package/usr/share/applications/
cp assets/icon.png debian-package/usr/share/icons/hicolor/256x256/apps/squirreldisk.png

# Create control file
cat > debian-package/DEBIAN/control << EOF
Package: squirreldisk
Version: 0.3.4
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libblkid1
Maintainer: Your Name <email@example.com>
Description: Disk usage analyzer and visualizer
 SquirrelDisk helps you understand what's taking up space on your disk
 with interactive visualizations and detailed file system analysis.
EOF

# Build DEB package
dpkg-deb --build debian-package squirreldisk_0.3.4_amd64.deb
```

## CI/CD Pipeline

### GitHub Actions Workflow

```yaml
name: Build and Release

on:
  push:
    tags: ['v*']

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - run: flutter config --enable-windows-desktop
      - run: flutter pub get
      - run: flutter test
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v3
        with:
          name: windows-build
          path: build/windows/runner/Release/

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - run: flutter config --enable-macos-desktop
      - run: flutter pub get
      - run: flutter test
      - run: flutter build macos --release
      - uses: actions/upload-artifact@v3
        with:
          name: macos-build
          path: build/macos/Build/Products/Release/

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: |
          sudo apt-get update -y
          sudo apt-get install -y ninja-build libgtk-3-dev
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - run: flutter config --enable-linux-desktop
      - run: flutter pub get
      - run: flutter test
      - run: flutter build linux --release
      - uses: actions/upload-artifact@v3
        with:
          name: linux-build
          path: build/linux/x64/release/bundle/
```

## Performance Optimization

### Build Optimizations

1. **Tree Shaking**:
```bash
flutter build windows --release --tree-shake-icons
```

2. **Split Debug Info**:
```bash
flutter build windows --release --split-debug-info=debug-symbols/
```

3. **Platform-specific optimizations**:
```dart
// pubspec.yaml
flutter:
  assets:
    - assets/images/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Bold.ttf  
          weight: 700
```

### Runtime Performance

1. **Memory Management**:
```dart
// Dispose resources properly
@override
void dispose() {
  _controller.dispose();
  _subscription?.cancel();
  super.dispose();
}
```

2. **Efficient Rendering**:
```dart
// Use const constructors where possible
const SizedBox(height: 16),
const Divider(),

// Minimize rebuilds with keys
ListView.builder(
  key: const ValueKey('disk-list'),
  itemBuilder: (context, index) => DiskItemWidget(
    key: ValueKey(disks[index].mountPoint),
    disk: disks[index],
  ),
)
```

## Testing Strategy

### Automated Testing

```bash
# Unit tests
flutter test test/unit_tests.dart

# Widget tests  
flutter test test/widget_tests.dart

# Integration tests
flutter test integration_test/app_test.dart

# Test coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Manual Testing Checklist

- [ ] Disk enumeration on all platforms
- [ ] Directory selection and scanning
- [ ] Sunburst chart interaction
- [ ] File manager integration
- [ ] Error handling
- [ ] Performance with large directories
- [ ] Memory usage during long scans
- [ ] Platform-specific UI elements

## Deployment Considerations

### Security

1. **Code signing certificates** (Windows/macOS)
2. **Sandboxing** considerations for file system access
3. **Permission handling** for disk access

### Distribution Channels

1. **Direct download** from GitHub releases
2. **Package managers**: 
   - Windows: winget, chocolatey
   - macOS: Homebrew
   - Linux: apt, snap, flatpak

### Update Mechanism

Consider implementing auto-update functionality:
```dart
// Using updater package
import 'package:updater/updater.dart';

class UpdateService {
  static Future<void> checkForUpdates() async {
    final updater = Updater(
      repositoryUrl: 'https://api.github.com/repos/NikolaiJDev/squirreldisk',
      currentVersion: '0.3.4',
    );
    
    final hasUpdate = await updater.hasUpdate();
    if (hasUpdate) {
      // Show update dialog
    }
  }
}
```

This comprehensive build and deployment guide ensures consistent, reproducible builds across all supported platforms while maintaining high code quality and performance standards.