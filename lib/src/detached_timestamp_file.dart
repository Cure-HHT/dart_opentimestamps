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

/// Detached timestamp file
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'core/attestation.dart';
import 'core/operations.dart';
import 'core/timestamp.dart';
import 'deserialization/stream_deserialization_context.dart';

/// A file with a detached timestamp
///
/// This represents a timestamp for a file where the file itself is separate
/// from the timestamp proof.
class DetachedTimestampFile {
  /// Creates a detached timestamp file
  DetachedTimestampFile(this.fileHashOp, this.timestamp);

  /// Creates a DetachedTimestampFile from file bytes
  factory DetachedTimestampFile.fromBytes(Uint8List fileBytes) {
    // Hash the file with SHA-256
    final fileHash = sha256.convert(fileBytes);
    final fileHashBytes = Uint8List.fromList(fileHash.bytes);

    // Create timestamp with the file hash as the message
    final timestamp = Timestamp(fileHashBytes);

    return DetachedTimestampFile(const OpSHA256(), timestamp);
  }

  /// Creates a DetachedTimestampFile from a pre-computed hash
  factory DetachedTimestampFile.fromHash(Uint8List hash) {
    final timestamp = Timestamp(hash);
    return DetachedTimestampFile(const OpSHA256(), timestamp);
  }

  /// Deserializes a DetachedTimestampFile from OTS file bytes
  factory DetachedTimestampFile.deserialize(Uint8List otsBytes) {
    final ctx = StreamDeserializationContext(otsBytes);

    // Read and verify magic header
    ctx.assertMagic([0x00]);
    ctx.assertMagic('OpenTimestamps'.codeUnits);
    ctx.assertMagic([0x00]);
    ctx.assertMagic('Proof'.codeUnits);
    ctx.assertMagic([0x00]);

    // Read version
    ctx.assertMagic([0xbf, 0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94]);

    // Read file hash operation
    final fileHashOpTag = ctx.readByte();
    final fileHashOp = ctx.deserializeOperation(fileHashOpTag);

    // Read file hash
    final fileHashLength = ctx.readByte();
    final fileHash = ctx.readBytes(fileHashLength);

    // Create timestamp and deserialize the tree
    final timestamp = Timestamp(fileHash);
    _deserializeTimestamp(ctx, timestamp);

    return DetachedTimestampFile(fileHashOp, timestamp);
  }

  /// Deserializes a timestamp tree from the stream
  static void _deserializeTimestamp(
    StreamDeserializationContext ctx,
    Timestamp timestamp,
  ) {
    while (!ctx.isEOF) {
      final tag = ctx.readByte();

      if (tag == 0x00) {
        // Attestation
        final attestationTag = ctx.readByte();
        final payload = ctx.readVarbytes(maxLength: 8192);

        final attestation = _deserializeAttestation(attestationTag, payload);
        timestamp.addAttestation(attestation);
      } else if (tag == 0xff) {
        // Fork point - multiple operations follow
        // The next tag will be an operation, so we continue the loop
        continue;
      } else {
        // Operation
        final op = ctx.deserializeOperation(tag);
        final newTimestamp = timestamp.add(op);
        _deserializeTimestamp(ctx, newTimestamp);
        return; // Operations create new branches
      }
    }
  }

  /// Deserializes an attestation from tag and payload
  static Attestation _deserializeAttestation(int tag, Uint8List payload) {
    switch (tag) {
      case 0x83: // Pending attestation
        final uri = String.fromCharCodes(payload);
        return PendingAttestation(uri);

      case 0x05: // Bitcoin block header
        // Decode varint from payload
        final ctx = StreamDeserializationContext(payload);
        final height = ctx.readVarint();
        return BitcoinBlockHeaderAttestation(height);

      default:
        return UnknownAttestation(tag, payload);
    }
  }

  /// The hash operation used on the file
  final Operation fileHashOp;

  /// The timestamp proof tree
  final Timestamp timestamp;

  /// Returns the file hash
  Uint8List get fileHash => timestamp.msg;

  /// Serializes this timestamp to bytes (OTS file format)
  Uint8List serialize() {
    // OTS file format:
    // - Magic bytes: 0x00 "OpenTimestamps" 0x00 "Proof" 0x00
    // - File hash operation tag
    // - File hash length + hash
    // - Timestamp tree

    final buffer = <int>[];

    // Magic header
    buffer.addAll([0x00]);
    buffer.addAll('OpenTimestamps'.codeUnits);
    buffer.addAll([0x00]);
    buffer.addAll('Proof'.codeUnits);
    buffer.addAll([0x00]);
    buffer.addAll([0xbf, 0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94]); // Version

    // File hash operation
    buffer.add(fileHashOp.tag);

    // File hash (length + data)
    final hashBytes = fileHash;
    buffer.add(hashBytes.length);
    buffer.addAll(hashBytes);

    // Timestamp tree
    buffer.addAll(_serializeTimestamp(timestamp));

    return Uint8List.fromList(buffer);
  }

  List<int> _serializeTimestamp(Timestamp timestamp) {
    final buffer = <int>[];

    // Serialize attestations
    for (final attestation in timestamp.attestations) {
      buffer.add(0x00); // Attestation tag
      buffer.addAll(attestation.serialize());
    }

    // Serialize operations
    final sortedOps = timestamp.ops.entries.toList()
      ..sort((a, b) => a.key.tag.compareTo(b.key.tag));

    for (final entry in sortedOps) {
      final op = entry.key;
      final childTimestamp = entry.value;

      // Add fork point if multiple operations
      if (timestamp.ops.length > 1 || timestamp.attestations.isNotEmpty) {
        buffer.add(0xff); // Fork point
      }

      buffer.addAll(op.serialize());
      buffer.addAll(_serializeTimestamp(childTimestamp));
    }

    return buffer;
  }

  /// Returns information about this timestamp
  String info() {
    final buffer = StringBuffer();
    final hashHex =
        fileHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    buffer.writeln('File $fileHashOp hash: $hashHex');
    buffer.writeln('Timestamp:');
    buffer.write(timestamp.strTree(indent: 1));

    return buffer.toString();
  }

  @override
  String toString() => info();
}
