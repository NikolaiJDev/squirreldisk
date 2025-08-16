
import '../enums/disk_service_error_type.dart';

class DiskServiceError implements Exception {
  final String message;
  final String? details;
  final DiskServiceErrorType type;

  const DiskServiceError(
      this.message, {
        this.details,
        this.type = DiskServiceErrorType.unknown,
      });

  @override
  String toString() => 'DiskServiceError: $message${details != null ? ' ($details)' : ''}';
}