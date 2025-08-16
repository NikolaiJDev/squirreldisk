enum ScanState {
  idle,
  scanning,
  completed,
  error,
  cancelled,
  paused;

  bool get isActive => this == scanning || this == paused;
  bool get isFinished => this == completed || this == error || this == cancelled;
  bool get canResume => this == paused;
  bool get canPause => this == scanning;
  bool get isError => this == error;
  bool get isCompleted => this == completed;
}