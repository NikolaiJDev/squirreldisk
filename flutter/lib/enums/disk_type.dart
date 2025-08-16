enum DiskType {
  fixed,
  removable,
  network,
  ram,
  cdrom,
  unknown;

  static DiskType diskTypeFromString(String? typeStr) {
    switch (typeStr?.toLowerCase()) {
      case 'fixed':
        return DiskType.fixed;
      case 'removable':
        return DiskType.removable;
      case 'network':
        return DiskType.network;
      case 'ram':
        return DiskType.ram;
      case 'cdrom':
        return DiskType.cdrom;
      default:
        return DiskType.unknown;
    }
  }
}