// Copyright 2025 Anspar Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
