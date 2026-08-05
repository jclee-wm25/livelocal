enum AppErrorCode {
  validation,
  authentication,
  emailNotVerified,
  forbidden,
  conflict,
  network,
  notFound,
  unavailable,
  unexpected,
}

class AppException implements Exception {
  const AppException({
    required this.code,
    required this.userMessage,
    this.technicalMessage,
    this.cause,
  });

  final AppErrorCode code;
  final String userMessage;
  final String? technicalMessage;
  final Object? cause;

  @override
  String toString() => technicalMessage ?? userMessage;
}
