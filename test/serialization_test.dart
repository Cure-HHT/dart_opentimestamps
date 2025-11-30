import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_opentimestamps/open_timestamps.dart';

void main() {
  group('Serialization/Deserialization', () {
    test('Round-trip serialization of simple timestamp', () {
      // Create a simple timestamp
      final message = 'Hello World!\n';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);
      
      // Serialize
      final serialized = detached.serialize();
      
      // Deserialize
      final deserialized = DetachedTimestampFile.deserialize(serialized);
      
      // Verify file hash matches
      expect(deserialized.fileHash, equals(detached.fileHash));
      expect(deserialized.fileHashOp, equals(const OpSHA256()));
    });

    test('Round-trip with operations and attestations', () {
      // Create a timestamp with operations and attestations
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);
      
      // Add operations
      final nonce = Uint8List.fromList([1, 2, 3, 4]);
      final nonceAppended = detached.timestamp.add(OpAppend(nonce));
      final sha256After = nonceAppended.add(const OpSHA256());
      
      // Add attestation
      sha256After.addAttestation(
        const PendingAttestation('https://alice.btc.calendar.opentimestamps.org'),
      );
      
      // Serialize
      final serialized = detached.serialize();
      
      // Deserialize
      final deserialized = DetachedTimestampFile.deserialize(serialized);
      
      // Verify structure
      expect(deserialized.fileHash, equals(hash));
      
      // Check attestations were preserved
      final allAttestations = deserialized.timestamp.getAllAttestations();
      expect(allAttestations.length, equals(1));
      expect(allAttestations.first, isA<PendingAttestation>());
      
      final pending = allAttestations.first as PendingAttestation;
      expect(pending.uri, equals('https://alice.btc.calendar.opentimestamps.org'));
    });

    test('Serialized format has correct magic bytes', () {
      final message = 'Test';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);
      
      final serialized = detached.serialize();
      
      // Check magic header
      expect(serialized[0], equals(0x00));
      expect(String.fromCharCodes(serialized.sublist(1, 15)), equals('OpenTimestamps'));
      expect(serialized[15], equals(0x00));
      expect(String.fromCharCodes(serialized.sublist(16, 21)), equals('Proof'));
      expect(serialized[21], equals(0x00));
      
      // Check version bytes
      expect(serialized.sublist(22, 30), equals([0xbf, 0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94]));
    });

    test('File hash matches expected value for Hello World', () {
      // Verify our hash calculation is correct
      final message = 'Hello World!\n';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);
      
      final expectedHash = '03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340';
      final actualHash = detached.fileHash
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      
      expect(actualHash, equals(expectedHash));
    });
  });

  group('Attestation serialization', () {
    test('PendingAttestation serializes correctly', () {
      final attestation = const PendingAttestation('https://example.com');
      final serialized = attestation.serialize();
      
      // First byte should be tag (0x83)
      expect(serialized[0], equals(0x83));
      
      // Should contain the URI
      final uri = String.fromCharCodes(serialized.sublist(2));
      expect(uri, equals('https://example.com'));
    });

    test('BitcoinBlockHeaderAttestation serializes correctly', () {
      final attestation = const BitcoinBlockHeaderAttestation(515107);
      final serialized = attestation.serialize();
      
      // First byte should be tag (0x05)
      expect(serialized[0], equals(0x05));
      
      // Height should be encoded as varint
      expect(serialized.length, greaterThan(1));
    });
  });
}
