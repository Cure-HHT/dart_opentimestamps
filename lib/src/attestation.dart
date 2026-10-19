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

/// Attestations: claims that a message existed at some time.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'codec.dart';

const _maxPayloadLength = 8192;
const _maxUriLength = 1000;
final _uriChars = RegExp(r'^[A-Za-z0-9._/:-]*$');

/// A claim that the message at a timestamp node existed at some time.
sealed class Attestation implements Comparable<Attestation> {
  const Attestation();

  /// The attestation's 8-byte type tag.
  Uint8List get tag;

  /// The attestation's payload, without its length prefix.
  Uint8List get payload;

  /// Writes the tag followed by the length-prefixed payload.
  void serialize(ByteWriter w) {
    w.write(tag);
    w.writeVarbytes(payload);
  }

  /// Reads one attestation (tag + payload).
  static Attestation deserialize(ByteReader r) {
    final tag = r.read(8);
    final payload = r.readVarbytes(max: _maxPayloadLength);
    if (bytesEqual(tag, PendingAttestation.tagBytes)) {
      final p = ByteReader(payload);
      final uri = p.readVarbytes(max: _maxUriLength);
      p.assertEnd();
      return PendingAttestation(ascii.decode(uri, allowInvalid: true));
    }
    if (bytesEqual(tag, BitcoinBlockHeaderAttestation.tagBytes)) {
      final p = ByteReader(payload);
      final height = p.readVaruint();
      p.assertEnd();
      return BitcoinBlockHeaderAttestation(height);
    }
    return UnknownAttestation(tag, payload);
  }

  /// Orders by tag, then by type-specific payload order.
  @override
  int compareTo(Attestation other) {
    final byTag = compareBytes(tag, other.tag);
    if (byTag != 0) return byTag;
    return switch ((this, other)) {
      (final PendingAttestation a, final PendingAttestation b) =>
        a.uri.compareTo(b.uri),
      (
        final BitcoinBlockHeaderAttestation a,
        final BitcoinBlockHeaderAttestation b,
      ) =>
        a.height.compareTo(b.height),
      _ => compareBytes(payload, other.payload),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Attestation &&
      bytesEqual(tag, other.tag) &&
      bytesEqual(payload, other.payload);

  @override
  int get hashCode => Object.hash(Object.hashAll(tag), Object.hashAll(payload));
}

/// A calendar's promise to commit the message to Bitcoin later; the proof
/// is fetched from [uri] by an upgrade. Not itself evidence of time.
final class PendingAttestation extends Attestation {
  /// Creates a pending attestation for calendar [uri].
  PendingAttestation(this.uri) {
    if (uri.length > _maxUriLength || !_uriChars.hasMatch(uri)) {
      throw FormatException('Invalid calendar URI', uri);
    }
  }

  /// Serialization tag.
  static final tagBytes =
      Uint8List.fromList([0x83, 0xdf, 0xe3, 0x0d, 0x2e, 0xf9, 0x0c, 0x8e]);

  /// The calendar that issued the promise.
  final String uri;

  @override
  Uint8List get tag => tagBytes;

  @override
  Uint8List get payload =>
      (ByteWriter()..writeVarbytes(ascii.encode(uri))).toBytes();

  @override
  String toString() => 'PendingAttestation($uri)';
}

/// The message equals the merkle root of the Bitcoin block at [height].
final class BitcoinBlockHeaderAttestation extends Attestation {
  /// Creates a Bitcoin attestation for block [height].
  const BitcoinBlockHeaderAttestation(this.height);

  /// Serialization tag.
  static final tagBytes =
      Uint8List.fromList([0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01]);

  /// The block height.
  final int height;

  @override
  Uint8List get tag => tagBytes;

  @override
  Uint8List get payload => (ByteWriter()..writeVaruint(height)).toBytes();

  @override
  String toString() => 'BitcoinBlockHeaderAttestation($height)';
}

/// An attestation of a type this library does not interpret. Kept
/// byte-for-byte so proofs round-trip; never counted as evidence.
final class UnknownAttestation extends Attestation {
  /// Creates an unknown attestation.
  const UnknownAttestation(this.tag, this.payload);

  @override
  final Uint8List tag;

  @override
  final Uint8List payload;

  @override
  String toString() => 'UnknownAttestation(${hexEncode(tag)})';
}
