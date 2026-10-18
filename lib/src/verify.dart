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

/// Offline verification of a proof against Bitcoin block headers.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'attestation.dart';
import 'codec.dart';
import 'detached_timestamp_file.dart';

/// The outcome of [verifyTimestamp].
sealed class VerificationResult {
  const VerificationResult();
}

/// The digest provably existed no later than [blockTime], the time of the
/// Bitcoin block at [height].
final class VerificationValid extends VerificationResult {
  /// Creates a valid result.
  const VerificationValid(this.height, this.blockTime);

  /// Earliest attested block height.
  final int height;

  /// That block's header timestamp (UTC).
  final DateTime blockTime;

  @override
  String toString() => 'valid: block $height at ${blockTime.toIso8601String()}';
}

/// Well-formed but not yet anchored in Bitcoin: only calendar promises.
final class VerificationPending extends VerificationResult {
  /// Creates a pending result.
  const VerificationPending(this.calendars);

  /// Calendars holding a pending promise.
  final Set<String> calendars;

  @override
  String toString() => 'pending: ${calendars.join(', ')}';
}

/// The proof does not establish a time for the expected digest.
final class VerificationInvalid extends VerificationResult {
  /// Creates an invalid result.
  const VerificationInvalid(this.reason);

  /// Why verification failed.
  final String reason;

  @override
  String toString() => 'invalid: $reason';
}

/// The proof-of-work limit (nBits 0x1d00ffff); an easier target is never a
/// valid Bitcoin block.
final _maxTarget = BigInt.from(0xffff) << (8 * 26);

/// Verifies `.ots` bytes [proof] for [expectedDigest] without network
/// access, using the 80-byte block headers in [headersByHeight].
///
/// Every Bitcoin attestation in the proof must have its header supplied,
/// the attested message must equal that header's merkle root, and the
/// header must carry valid proof of work. Never throws: malformed input
/// yields [VerificationInvalid].
///
/// Proof of work only shows a header was mined at some real difficulty;
/// that the header belongs to the Bitcoin chain comes from where the
/// caller obtained it (for example two independent explorers, or a node).
VerificationResult verifyTimestamp(
  Uint8List proof,
  Uint8List expectedDigest,
  Map<int, Uint8List> headersByHeight,
) {
  final DetachedTimestampFile file;
  try {
    file = DetachedTimestampFile.deserialize(proof);
  } on FormatException catch (e) {
    return VerificationInvalid('malformed proof: ${e.message}');
  }
  if (!bytesEqual(file.digest, expectedDigest)) {
    return const VerificationInvalid('proof is for a different digest');
  }

  VerificationValid? earliest;
  for (final (msg, attestation) in file.timestamp.allAttestations()) {
    if (attestation is! BitcoinBlockHeaderAttestation) continue;
    final height = attestation.height;
    final header = headersByHeight[height];
    if (header == null) {
      return VerificationInvalid('no block header supplied for $height');
    }
    final problem = _checkHeader(header, msg);
    if (problem != null) return VerificationInvalid('block $height: $problem');
    if (earliest == null || height < earliest.height) {
      earliest = VerificationValid(height, blockTime(header));
    }
  }
  if (earliest != null) return earliest;

  final pending = file.pendingCalendars;
  return pending.isEmpty
      ? const VerificationInvalid('no Bitcoin or pending attestation')
      : VerificationPending(pending);
}

String? _checkHeader(Uint8List header, Uint8List msg) {
  if (header.length != 80) return 'header is not 80 bytes';
  if (msg.length != 32) return 'attested message is not 32 bytes';
  if (!bytesEqual(msg, header.sublist(36, 68))) {
    return 'merkle root does not match the proof';
  }
  final target = _target(_uint32le(header, 72));
  if (target == null || target > _maxTarget) return 'invalid difficulty bits';
  if (_littleEndian(blockHash(header)) > target) {
    return 'insufficient proof of work';
  }
  return null;
}

/// The double-SHA-256 hash of [header], in internal byte order.
Uint8List blockHash(Uint8List header) =>
    Uint8List.fromList(sha256.convert(sha256.convert(header).bytes).bytes);

/// The timestamp field of an 80-byte block [header].
DateTime blockTime(Uint8List header) => DateTime.fromMillisecondsSinceEpoch(
      _uint32le(header, 68) * 1000,
      isUtc: true,
    );

BigInt? _target(int bits) {
  final exponent = bits >> 24;
  final mantissa = bits & 0x007fffff;
  if (bits & 0x00800000 != 0 || mantissa == 0) return null;
  final m = BigInt.from(mantissa);
  return exponent <= 3 ? m >> (8 * (3 - exponent)) : m << (8 * (exponent - 3));
}

int _uint32le(Uint8List b, int offset) =>
    ByteData.sublistView(b, offset, offset + 4).getUint32(0, Endian.little);

BigInt _littleEndian(Uint8List bytes) {
  var n = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    n = (n << 8) | BigInt.from(bytes[i]);
  }
  return n;
}
