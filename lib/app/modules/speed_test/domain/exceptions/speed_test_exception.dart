class SpeedTestException implements Exception {
  final String message;
  final dynamic originalError;

  SpeedTestException(this.message, [this.originalError]);

  @override
  String toString() => 'SpeedTestException: $message';
}

