import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:test/test.dart';

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
        const PendingAttestation(
            'https://alice.btc.calendar.opentimestamps.org'),
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
      expect(
          pending.uri, equals('https://alice.btc.calendar.opentimestamps.org'));
    });

    test('Serialized format has correct magic bytes', () {
      final message = 'Test';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      final serialized = detached.serialize();

      // Check magic header
      expect(serialized[0], equals(0x00));
      expect(String.fromCharCodes(serialized.sublist(1, 15)),
          equals('OpenTimestamps'));
      expect(serialized[15], equals(0x00));
      expect(String.fromCharCodes(serialized.sublist(16, 21)), equals('Proof'));
      expect(serialized[21], equals(0x00));

      // Check version bytes
      expect(serialized.sublist(22, 30),
          equals([0xbf, 0x89, 0xe2, 0xe8, 0x84, 0xe8, 0x92, 0x94]));
    });

    test('File hash matches expected value for Hello World', () {
      // Verify our hash calculation is correct
      final message = 'Hello World!\n';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      final expectedHash =
          '03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340';
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

  group('DetachedTimestampFile', () {
    test('info() returns formatted string with hash and timestamp tree', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);
      detached.timestamp.addAttestation(
        const PendingAttestation('https://test.calendar'),
      );

      final info = detached.info();

      expect(info, contains('sha256'));
      expect(info, contains('hash:'));
      expect(info, contains('Timestamp:'));
      expect(info, contains('PendingAttestation'));
    });

    test('toString() returns same as info()', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      expect(detached.toString(), equals(detached.info()));
    });

    test('deserializes BitcoinBlockHeaderAttestation correctly', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Add an operation then a Bitcoin attestation on the result
      final hashed = detached.timestamp.add(const OpSHA256());
      hashed.addAttestation(
        const BitcoinBlockHeaderAttestation(500000),
      );

      // Serialize and deserialize
      final serialized = detached.serialize();
      final deserialized = DetachedTimestampFile.deserialize(serialized);

      // Verify Bitcoin attestation was preserved
      final attestations = deserialized.timestamp.getAllAttestations();
      expect(attestations.length, equals(1));
      expect(attestations.first, isA<BitcoinBlockHeaderAttestation>());

      final bitcoin = attestations.first as BitcoinBlockHeaderAttestation;
      expect(bitcoin.height, equals(500000));
    });

    test('deserializes UnknownAttestation correctly', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Add an operation then an unknown attestation
      final hashed = detached.timestamp.add(const OpSHA256());
      final unknownPayload = Uint8List.fromList([1, 2, 3, 4, 5]);
      hashed.addAttestation(
        UnknownAttestation(0x99, unknownPayload),
      );

      // Serialize and deserialize
      final serialized = detached.serialize();
      final deserialized = DetachedTimestampFile.deserialize(serialized);

      // Verify unknown attestation was preserved
      final attestations = deserialized.timestamp.getAllAttestations();
      expect(attestations.length, equals(1));
      expect(attestations.first, isA<UnknownAttestation>());

      final unknown = attestations.first as UnknownAttestation;
      expect(unknown.tag, equals(0x99));
      expect(unknown.payload, equals(unknownPayload));
    });

    test('round-trip with Bitcoin attestation after operations', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Build a simple chain: hash -> append -> sha256 -> attestation
      final appended =
          detached.timestamp.add(OpAppend(Uint8List.fromList([1, 2, 3])));
      final hashed = appended.add(const OpSHA256());
      hashed.addAttestation(const BitcoinBlockHeaderAttestation(800000));

      // Serialize and deserialize
      final serialized = detached.serialize();
      final deserialized = DetachedTimestampFile.deserialize(serialized);

      // Verify attestation was preserved
      final attestations = deserialized.timestamp.getAllAttestations();
      expect(attestations.length, equals(1));
      expect(attestations.first, isA<BitcoinBlockHeaderAttestation>());

      final bitcoin = attestations.first as BitcoinBlockHeaderAttestation;
      expect(bitcoin.height, equals(800000));
    });

    test('serializes fork points when timestamp has multiple branches', () {
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Create a fork: two different operations from the same timestamp
      // This creates a Merkle tree branch point
      final branch1 = detached.timestamp.add(const OpSHA256());
      branch1
          .addAttestation(const PendingAttestation('https://calendar1.test'));

      final branch2 =
          detached.timestamp.add(OpAppend(Uint8List.fromList([0xAB, 0xCD])));
      branch2
          .addAttestation(const PendingAttestation('https://calendar2.test'));

      // Verify we have two branches
      expect(detached.timestamp.ops.length, equals(2));

      // Serialize - this should include fork point markers (0xff)
      final serialized = detached.serialize();

      // The serialized data should contain 0xff fork markers
      expect(serialized.contains(0xff), isTrue,
          reason: 'Fork point marker should be present');

      // Deserialize and verify both branches are preserved
      final deserialized = DetachedTimestampFile.deserialize(serialized);
      final attestations = deserialized.timestamp.getAllAttestations();

      expect(attestations.length, equals(2));
      expect(
        attestations.whereType<PendingAttestation>().length,
        equals(2),
      );
    });

    test('info() includes hex-encoded hash', () {
      final hash = Uint8List.fromList([0xAB, 0xCD, 0xEF] + List.filled(29, 0));
      final detached = DetachedTimestampFile.fromHash(hash);

      final info = detached.info();

      // Should contain the hex-encoded hash
      expect(info, contains('abcdef'));
    });
  });
}
