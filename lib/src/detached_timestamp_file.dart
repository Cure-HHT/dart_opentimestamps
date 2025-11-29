/// Detached timestamp file
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'core/operations.dart';
import 'core/timestamp.dart';

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

    // Timestamp tree (to be implemented)
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
    final hashHex = fileHash
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    buffer.writeln('File ${fileHashOp.toString()} hash: $hashHex');
    buffer.writeln('Timestamp:');
    buffer.write(timestamp.strTree(indent: 1));

    return buffer.toString();
  }

  @override
  String toString() => info();
}
