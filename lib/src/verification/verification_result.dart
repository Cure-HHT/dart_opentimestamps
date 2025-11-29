/// Verification result
library;

class VerificationResult {
  const VerificationResult({
    required this.isValid,
    this.attestedTime,
    this.bitcoinBlockHeight,
    this.errors = const [],
  });

  final bool isValid;
  final DateTime? attestedTime;
  final int? bitcoinBlockHeight;
  final List<String> errors;

  factory VerificationResult.success({
    required DateTime attestedTime,
    required int bitcoinBlockHeight,
  }) =>
      VerificationResult(
        isValid: true,
        attestedTime: attestedTime,
        bitcoinBlockHeight: bitcoinBlockHeight,
      );

  factory VerificationResult.failure(List<String> errors) =>
      VerificationResult(isValid: false, errors: errors);
}
