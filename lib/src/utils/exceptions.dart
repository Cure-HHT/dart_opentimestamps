/// OpenTimestamps exceptions
library;

class OpenTimestampsException implements Exception {
  const OpenTimestampsException(this.message);
  final String message;
  @override
  String toString() => 'OpenTimestampsException: $message';
}

class ProofParseException extends OpenTimestampsException {
  const ProofParseException(super.message);
}

class CalendarException extends OpenTimestampsException {
  const CalendarException(super.message);
}

class VerificationException extends OpenTimestampsException {
  const VerificationException(super.message);
}
