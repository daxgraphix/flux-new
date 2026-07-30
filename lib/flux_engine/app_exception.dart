enum ExceptionType {
  network,
  timeout,
  unavailable,
  broken,
  unknown,
}

class AppException implements Exception {
  final String message;
  final ExceptionType type;
  final dynamic originalError;

  AppException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'AppException: $message (Type: $type)';

  String get localizedMessage {
    switch (type) {
      case ExceptionType.network:
        return 'No internet connection. Please check your network and try again.';
      case ExceptionType.timeout:
        return 'The connection timed out. The station might be overloaded or offline.';
      case ExceptionType.unavailable:
        return 'This content is currently unavailable in your region.';
      case ExceptionType.broken:
        return 'The link seems to be broken or the format is unsupported.';
      case ExceptionType.unknown:
        return 'Oops! Something went wrong. Please try again later.';
    }
  }

  bool get canRetry => type != ExceptionType.broken;
}
