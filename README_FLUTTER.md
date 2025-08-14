# SquirrelDisk - Flutter Edition

<p align="center">
    <a href="https://github.com/NikolaiJDev/squirreldisk"><img src="https://img.shields.io/github/v/release/NikolaiJDev/squirreldisk?color=%23ff00a0&include_prereleases&label=version&sort=semver&style=flat-square"></a>
     &nbsp;
      <a href="https://github.com/NikolaiJDev/squirreldisk"><img src="https://shields.io/badge/-BETA-orange?color=%23ff00a0&include_prereleases&label=status&sort=semver&style=flat-square"></a>
    &nbsp;
    <a href="https://github.com/NikolaiJDev/squirreldisk"><img src="https://img.shields.io/badge/built_with-Flutter-blue.svg?style=flat-square"></a>
     &nbsp;
     <a href="https://discord.gg/Xp8QtMM65w"><img src="https://img.shields.io/badge/Discord-%235865F2.svg?style=flat-square&logo=discord&logoColor=white"></a>
</p>

<div align="center">

[![Windows Support](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/NikolaiJDev/squirreldisk/releases) [![Ubuntu Support](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://github.com/NikolaiJDev/squirreldisk/releases) [![macOS Support](https://img.shields.io/badge/MACOS-adb8c5?style=for-the-badge&logo=macos&logoColor=white)](https://github.com/NikolaiJDev/squirreldisk/releases)

</div>

![Screenshot](/public/squirrel-demo-2.gif)

## What's taking your hard disk space?

The easiest open source app you will ever use to detect huge files. Now rebuilt with Flutter/Dart for better performance and native platform integration.

SquirrelDisk is an open source alternative to software like: WinDirStat, WizTree, TreeSize and DaisyDisk.

## 🆕 Flutter Migration

This version has been completely rewritten from the ground up using Flutter/Dart, replacing the previous Rust + TypeScript (Tauri) implementation. This migration provides:

- **Better Performance**: Native compilation with Flutter's efficient rendering
- **Improved UI**: More responsive and fluid user interface
- **Enhanced Platform Integration**: Better native platform support
- **Modern Architecture**: Clean separation of concerns with proper state management
- **Maintainability**: Single codebase for all platforms using Dart

## Features

- 🚀 Fast scan and deep directory scanning
- 💾 Disk scanning or pick any directory
- 🔌 External disks real-time detection
- 📊 Interactive sunburst chart to quickly visualize disk usage
- 🎯 Drag and drop: collect all items to be deleted
- 📂 Right click on a folder/file to open the file explorer
- 🖥️ Cross-Platform: macOS, Windows, Linux
- 🔄 Auto-updater: get notified when there is a new update

## Technical Stack

- **Framework**: Flutter 3.x
- **Language**: Dart
- **State Management**: Provider
- **Platform Integration**: Method Channels for native functionality
- **Charts**: Custom Flutter painting for sunburst visualization
- **File Operations**: Platform-specific native implementations

## Architecture

```
lib/
├── models/          # Data models (DiskInfo, DiskItem, ScanProgress)
├── services/        # Business logic (DiskService, PlatformService)  
├── screens/         # UI screens (DiskListScreen, DiskDetailScreen)
├── widgets/         # Reusable widgets (SunburstChart, DiskItemWidget)
└── utils/          # Utilities (theming, formatting, etc.)

Platform-specific native code:
├── android/         # Android implementation
├── ios/             # iOS implementation  
├── macos/           # macOS implementation
├── windows/         # Windows implementation
└── linux/           # Linux implementation
```

## Installation

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Platform-specific requirements:
  - **Windows**: Visual Studio 2019 or later
  - **macOS**: Xcode 12 or later
  - **Linux**: GTK development libraries

### Development Setup

1. Clone the repository:
```bash
git clone https://github.com/NikolaiJDev/squirreldisk.git
cd squirreldisk
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Run on your preferred platform:
```bash
# Desktop
flutter run -d windows
flutter run -d macos  
flutter run -d linux

# Mobile (if supported)
flutter run -d android
flutter run -d ios
```

### Building for Distribution

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## Migration from Tauri Version

The legacy Tauri version (Rust + TypeScript) has been preserved in the repository for reference. Key differences in the Flutter version:

- **UI Framework**: React/TypeScript → Flutter/Dart widgets
- **Backend**: Rust → Dart with native platform channels
- **State Management**: React hooks → Flutter Provider
- **Build System**: Tauri → Flutter build tools
- **Visualization**: D3.js → Custom Flutter painting

## Contributing

We welcome contributions! Please see our contributing guidelines and join our Discord server for discussions.

- [Join our Discord Server](https://discord.gg/Xp8QtMM65w)
- Check out the [Issues](https://github.com/NikolaiJDev/squirreldisk/issues) page
- Submit feature requests in [Discussions](https://github.com/NikolaiJDev/squirreldisk/discussions)

## License

[License details to be specified]

## Credits

- Original Tauri version inspiration and architecture
- Flutter team for the amazing framework
- [parallel-disk-usage](https://github.com/KSXGitHub/parallel-disk-usage) for disk scanning algorithms
- Community contributors and testers