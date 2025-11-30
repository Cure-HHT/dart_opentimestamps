/// OpenTimestamps timestamp tree structure
library;

import 'dart:typed_data';
import 'attestation.dart';
import 'operations.dart';

/// Proof that one or more attestations commit to a message
///
/// The proof is in the form of a tree, with each node being a message, and the
/// edges being operations acting on those messages. The leaves of the tree are
/// attestations that attest to the time that messages in the tree existed prior.
class Timestamp {
  /// Creates a timestamp
  Timestamp(this.msg);

  /// The message this timestamp commits to
  final Uint8List msg;

  /// Attestations for this message
  final List<Attestation> attestations = [];

  /// Map of operations to timestamps
  /// Each operation produces a new message and timestamp
  final Map<Operation, Timestamp> ops = {};

  /// Adds an operation to this timestamp
  ///
  /// Returns the timestamp produced by the operation
  Timestamp add(Operation op) {
    // Check if this operation already exists
    final existing = ops[op];
    if (existing != null) {
      return existing;
    }

    // Apply the operation to get the new message
    final newMsg = op.apply(msg);

    // Create new timestamp for the result
    final newTimestamp = Timestamp(newMsg);

    // Add to operations map
    ops[op] = newTimestamp;

    return newTimestamp;
  }

  /// Adds an attestation to this timestamp
  void addAttestation(Attestation attestation) {
    attestations.add(attestation);
  }

  /// Returns all attestations in this timestamp tree
  List<Attestation> getAllAttestations() {
    final allAttestations = <Attestation>[];

    // Add attestations from this timestamp
    allAttestations.addAll(attestations);

    // Recursively add attestations from child timestamps
    for (final timestamp in ops.values) {
      allAttestations.addAll(timestamp.getAllAttestations());
    }

    return allAttestations;
  }

  /// Returns a string representation of the timestamp tree
  String strTree({int indent = 0}) {
    final buffer = StringBuffer();

    if (attestations.isNotEmpty) {
      for (final attestation in attestations) {
        buffer.write(_indention(indent));
        buffer.write('verify $attestation\n');
      }
    }

    if (ops.isEmpty) {
      if (attestations.isEmpty) {
        buffer.write(_indention(indent));
        buffer.write('(no attestations)\n');
      }
      return buffer.toString();
    }

    // Sort operations for consistent output
    final sortedOps = ops.entries.toList()
      ..sort((a, b) => a.key.tag.compareTo(b.key.tag));

    var first = true;
    for (final entry in sortedOps) {
      final op = entry.key;
      final timestamp = entry.value;

      if (!first) {
        buffer.write(_indention(indent));
      }
      first = false;

      buffer.write(_indention(indent));
      buffer.write(op.toString());
      buffer.write('\n');
      buffer.write(timestamp.strTree(indent: indent + 1));
    }

    return buffer.toString();
  }

  String _indention(int indent) => ' ' * indent;

  @override
  String toString() => strTree();
}
