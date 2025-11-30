import 'dart:typed_data';

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:test/test.dart';

void main() {
  group('PendingAttestation', () {
    test('stores uri correctly', () {
      const attestation = PendingAttestation('https://calendar.example.com');
      expect(attestation.uri, equals('https://calendar.example.com'));
    });

    test('tag is 0x83', () {
      const attestation = PendingAttestation('https://example.com');
      expect(attestation.tag, equals(0x83));
    });

    test('payload returns uri as bytes', () {
      const attestation = PendingAttestation('test');
      expect(attestation.payload,
          equals(Uint8List.fromList([116, 101, 115, 116])));
    });

    test('serialize includes tag and length prefix', () {
      const attestation = PendingAttestation('ABC');
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0x83)); // tag
      expect(serialized[1], equals(3)); // length varint (3 bytes)
      expect(serialized.sublist(2), equals([65, 66, 67])); // "ABC"
    });

    test('toString returns descriptive string', () {
      const attestation = PendingAttestation('https://example.com');
      expect(attestation.toString(),
          equals('PendingAttestation(https://example.com)'));
    });

    test('equality based on uri', () {
      const a = PendingAttestation('https://a.com');
      const b = PendingAttestation('https://a.com');
      const c = PendingAttestation('https://b.com');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on uri', () {
      const a = PendingAttestation('test');
      const b = PendingAttestation('test');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('handles empty uri', () {
      const attestation = PendingAttestation('');
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0x83));
      expect(serialized[1], equals(0)); // length 0
      expect(serialized.length, equals(2));
    });

    test('handles long uri', () {
      final longUri = 'https://example.com/${'x' * 200}';
      final attestation = PendingAttestation(longUri);

      expect(attestation.uri, equals(longUri));
      expect(attestation.payload.length, equals(longUri.length));
    });
  });

  group('BitcoinBlockHeaderAttestation', () {
    test('stores height correctly', () {
      const attestation = BitcoinBlockHeaderAttestation(800000);
      expect(attestation.height, equals(800000));
    });

    test('tag is 0x05', () {
      const attestation = BitcoinBlockHeaderAttestation(100);
      expect(attestation.tag, equals(0x05));
    });

    test('payload encodes height as varint', () {
      const attestation = BitcoinBlockHeaderAttestation(127);
      expect(attestation.payload, equals(Uint8List.fromList([127])));
    });

    test('payload encodes large height correctly', () {
      const attestation = BitcoinBlockHeaderAttestation(300);
      // 300 = 0x012c = [0xac, 0x02] in varint
      expect(attestation.payload, equals(Uint8List.fromList([0xac, 0x02])));
    });

    test('serialize includes tag, length, and height', () {
      const attestation = BitcoinBlockHeaderAttestation(5);
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0x05)); // tag
      expect(serialized[1], equals(1)); // length varint (1 byte for height)
      expect(serialized[2], equals(5)); // height varint
    });

    test('toString returns descriptive string', () {
      const attestation = BitcoinBlockHeaderAttestation(500000);
      expect(attestation.toString(),
          equals('BitcoinBlockHeaderAttestation(500000)'));
    });

    test('equality based on height', () {
      const a = BitcoinBlockHeaderAttestation(100);
      const b = BitcoinBlockHeaderAttestation(100);
      const c = BitcoinBlockHeaderAttestation(200);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on height', () {
      const a = BitcoinBlockHeaderAttestation(12345);
      const b = BitcoinBlockHeaderAttestation(12345);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('handles zero height', () {
      const attestation = BitcoinBlockHeaderAttestation(0);
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0x05)); // tag
      expect(serialized[1], equals(1)); // length (1 byte for varint 0)
      expect(serialized[2], equals(0)); // height
    });

    test('handles very large height', () {
      const attestation = BitcoinBlockHeaderAttestation(1000000);
      expect(attestation.height, equals(1000000));

      final serialized = attestation.serialize();
      expect(serialized.length, greaterThan(2)); // Needs multiple varint bytes
    });

    test('throws ArgumentError for negative height when accessing payload', () {
      const attestation = BitcoinBlockHeaderAttestation(-1);

      expect(
        () => attestation.payload,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for negative height when serializing', () {
      const attestation = BitcoinBlockHeaderAttestation(-100);

      expect(
        () => attestation.serialize(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('UnknownAttestation', () {
    test('stores tag and payload', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final attestation = UnknownAttestation(0x99, payload);

      expect(attestation.tag, equals(0x99));
      expect(attestation.payload, equals(payload));
    });

    test('serialize includes tag, length, and payload', () {
      final payload = Uint8List.fromList([10, 20, 30]);
      final attestation = UnknownAttestation(0xAB, payload);
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0xAB)); // tag
      expect(serialized[1], equals(3)); // length varint
      expect(serialized.sublist(2), equals([10, 20, 30])); // payload
    });

    test('toString shows hex tag', () {
      final attestation = UnknownAttestation(0xFF, Uint8List(0));
      expect(attestation.toString(), equals('UnknownAttestation(0xff)'));
    });

    test('equality based on tag and payload', () {
      final payload1 = Uint8List.fromList([1, 2, 3]);
      final payload2 = Uint8List.fromList([1, 2, 3]);
      final payload3 = Uint8List.fromList([4, 5, 6]);

      final a = UnknownAttestation(0x10, payload1);
      final b = UnknownAttestation(0x10, payload2);
      final c = UnknownAttestation(0x10, payload3);
      final d = UnknownAttestation(0x20, payload1);

      expect(a, equals(b));
      expect(a, isNot(equals(c))); // different payload
      expect(a, isNot(equals(d))); // different tag
    });

    test('hashCode combines tag and payload', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final a = UnknownAttestation(0x10, payload);
      final b = UnknownAttestation(0x10, payload);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('handles empty payload', () {
      final attestation = UnknownAttestation(0x01, Uint8List(0));
      final serialized = attestation.serialize();

      expect(serialized[0], equals(0x01));
      expect(serialized[1], equals(0)); // length 0
      expect(serialized.length, equals(2));
    });
  });

  group('Attestation type discrimination', () {
    test('different attestation types are not equal', () {
      const pending = PendingAttestation('test');
      const bitcoin = BitcoinBlockHeaderAttestation(100);
      final unknown =
          UnknownAttestation(0x83, Uint8List.fromList([116, 101, 115, 116]));

      expect(pending, isNot(equals(bitcoin)));
      expect(pending, isNot(equals(unknown)));
      expect(bitcoin, isNot(equals(unknown)));
    });
  });
}
