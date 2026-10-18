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

/// The standard `.ots` proof file for one SHA-256 digest.
library;

import 'dart:typed_data';

import 'attestation.dart';
import 'codec.dart';
import 'op.dart';
import 'timestamp.dart';

final _magic = Uint8List.fromList([
  0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, //
  0x6d, 0x70, 0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, //
  0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94,
]);
const _majorVersion = 1;

/// A timestamp proof over a 32-byte SHA-256 digest, in the `.ots` format
/// every OpenTimestamps tool reads (`ots verify -d <hex> proof.ots`).
class DetachedTimestampFile {
  /// Creates a proof with no attestations yet for [digest].
  DetachedTimestampFile(Uint8List digest) : timestamp = Timestamp(digest) {
    if (digest.length != 32) {
      throw ArgumentError.value(digest.length, 'digest', 'must be 32 bytes');
    }
  }

  DetachedTimestampFile._(this.timestamp);

  /// The proof tree, rooted at [digest].
  final Timestamp timestamp;

  /// The SHA-256 digest this proof timestamps.
  Uint8List get digest => timestamp.msg;

  /// Whether any path reaches a Bitcoin block header attestation.
  bool get isComplete => bitcoinHeights.isNotEmpty;

  /// Heights of every Bitcoin block the proof attests to.
  Set<int> get bitcoinHeights => {
        for (final (_, a) in timestamp.allAttestations())
          if (a is BitcoinBlockHeaderAttestation) a.height,
      };

  /// Calendars still holding a pending promise for this proof.
  Set<String> get pendingCalendars => {
        for (final (_, a) in timestamp.allAttestations())
          if (a is PendingAttestation) a.uri,
      };

  /// The `.ots` file bytes.
  Uint8List serialize() {
    final w = ByteWriter()
      ..write(_magic)
      ..writeVaruint(_majorVersion)
      ..writeByte(OpSHA256.tagByte)
      ..write(digest);
    timestamp.serialize(w);
    return w.toBytes();
  }

  /// Parses `.ots` file bytes; throws [FormatException] if they are not a
  /// well-formed SHA-256 proof.
  static DetachedTimestampFile deserialize(Uint8List bytes) {
    final r = ByteReader(bytes);
    if (!bytesEqual(r.read(_magic.length), _magic)) {
      throw const FormatException('Not an OpenTimestamps proof');
    }
    final version = r.readVaruint();
    if (version != _majorVersion) {
      throw FormatException('Unsupported proof version $version');
    }
    final hashOp = r.readByte();
    if (hashOp != OpSHA256.tagByte) {
      throw FormatException(
        'Unsupported file hash op 0x${hashOp.toRadixString(16)}; '
        'only SHA-256 is accepted',
      );
    }
    final digest = r.read(32);
    final timestamp = Timestamp.deserialize(r, digest);
    r.assertEnd();
    return DetachedTimestampFile._(timestamp);
  }
}
