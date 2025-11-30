/// OpenTimestamps exceptions
library;

/// Base exception for all OpenTimestamps errors.
class OpenTimestampsException implements Exception {
  /// Creates an OpenTimestamps exception with the given [message].
  const OpenTimestampsException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'OpenTimestampsException: $message';
}

/// Exception thrown when parsing a timestamp proof fails.
class ProofParseException extends OpenTimestampsException {
  /// Creates a proof parse exception with the given [message].
  const ProofParseException(super.message);
}

/// Exception thrown when calendar server operations fail.
class CalendarException extends OpenTimestampsException {
  /// Creates a calendar exception with the given [message].
  const CalendarException(super.message);
}

/// Exception thrown when timestamp verification fails.
class VerificationException extends OpenTimestampsException {
  /// Creates a verification exception with the given [message].
  const VerificationException(super.message);
}
