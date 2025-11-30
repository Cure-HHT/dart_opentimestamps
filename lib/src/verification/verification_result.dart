/// Verification result
library;

/// Result of verifying a timestamp against the Bitcoin blockchain.
class VerificationResult {
  /// Creates a verification result.
  const VerificationResult({
    required this.isValid,
    this.attestedTime,
    this.bitcoinBlockHeight,
    this.errors = const [],
  });

  /// Whether the timestamp verification was successful.
  final bool isValid;

  /// The time when the timestamp was attested, if verification succeeded.
  final DateTime? attestedTime;

  /// The Bitcoin block height where the timestamp was included.
  final int? bitcoinBlockHeight;

  /// List of error messages if verification failed.
  final List<String> errors;

  /// Creates a successful verification result.
  factory VerificationResult.success({
    required DateTime attestedTime,
    required int bitcoinBlockHeight,
  }) =>
      VerificationResult(
        isValid: true,
        attestedTime: attestedTime,
        bitcoinBlockHeight: bitcoinBlockHeight,
      );

  /// Creates a failed verification result with the given [errors].
  factory VerificationResult.failure(List<String> errors) =>
      VerificationResult(isValid: false, errors: errors);
}
