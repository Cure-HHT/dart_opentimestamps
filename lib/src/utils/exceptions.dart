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
