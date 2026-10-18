import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:dart_opentimestamps/src/codec.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const _magicHex =
    '004f70656e54696d657374616d7073000050726f6f6600bf89e2e884e89294';

Uint8List _ots(String bodyHex, {String version = '01', String op = '08'}) =>
    hexDecode('$_magicHex$version$op${'11' * 32}$bodyHex');

void main() {
  group('reference vectors', () {
    for (final name in ['incomplete', 'two-calendars', 'merkle1']) {
      test('$name.txt.ots round-trips byte-identically', () {
        final bytes = fixture('$name.txt.ots');
        final proof = DetachedTimestampFile.deserialize(bytes);
        expect(proof.serialize(), bytes);
        expect(proof.digest, sha256.convert(fixture('$name.txt')).bytes);
        expect(proof.isComplete, isFalse);
        expect(proof.pendingCalendars, isNotEmpty);
      });
    }

    test('two-calendars names both calendars', () {
      final proof =
          DetachedTimestampFile.deserialize(fixture('two-calendars.txt.ots'));
      expect(proof.pendingCalendars, {
        'https://alice.btc.calendar.opentimestamps.org',
        'https://bob.btc.calendar.opentimestamps.org',
      });
    });

    test('hello-world.txt.ots (RIPEMD-160 op) is rejected cleanly', () {
      expect(
        () => DetachedTimestampFile.deserialize(fixture('hello-world.txt.ots')),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('0x03'))),
      );
    });

    test('the Bitcoin path of hello-world round-trips and is complete', () {
      final bytes = fixture('hello-world-bitcoin-path.ots');
      final proof = DetachedTimestampFile.deserialize(bytes);
      expect(proof.serialize(), bytes);
      expect(proof.isComplete, isTrue);
      expect(proof.bitcoinHeights, {358391});
      expect(proof.pendingCalendars, isEmpty);
    });
  });

  group('header', () {
    test('rejects a bad magic', () {
      final bytes = _ots('0083dfe30d2ef90c8e0100')..[1] = 0;
      expect(() => DetachedTimestampFile.deserialize(bytes),
          throwsFormatException);
    });

    test('rejects an unknown major version', () {
      expect(
          () => DetachedTimestampFile.deserialize(
              _ots('000588960d73d719010101', version: '02')),
          throwsFormatException);
    });

    test('rejects a file hash op other than SHA-256', () {
      expect(
          () => DetachedTimestampFile.deserialize(
              _ots('000588960d73d719010101', op: '02')),
          throwsFormatException);
    });

    test('writes the digest without a length prefix', () {
      final proof = DetachedTimestampFile(digestOf(0x11));
      proof.timestamp.attestations.add(const BitcoinBlockHeaderAttestation(1));
      expect(hexEncode(proof.serialize()),
          '$_magicHex' '0108${'11' * 32}' '000588960d73d719010101');
    });

    test('rejects truncation and trailing bytes', () {
      final good = _ots('000588960d73d719010101');
      DetachedTimestampFile.deserialize(good);
      expect(
          () => DetachedTimestampFile.deserialize(
              Uint8List.sublistView(good, 0, good.length - 1)),
          throwsFormatException);
      expect(
          () => DetachedTimestampFile.deserialize(
              Uint8List.fromList([...good, 0])),
          throwsFormatException);
    });

    test('requires a 32-byte digest', () {
      expect(() => DetachedTimestampFile(Uint8List(20)), throwsArgumentError);
      expect(() => DetachedTimestampFile(Uint8List(5000)), throwsArgumentError);
    });
  });

  group('timestamp serialization', () {
    test('writes attestations and ops in canonical order', () {
      final t = Timestamp(digestOf(0));
      t.attestations
        ..add(const BitcoinBlockHeaderAttestation(5))
        ..add(PendingAttestation('https://b'))
        ..add(PendingAttestation('https://a'));
      t.add(OpPrepend(Uint8List.fromList([2]))).attestations.add(
            const BitcoinBlockHeaderAttestation(1),
          );
      t.add(OpAppend(Uint8List.fromList([9]))).attestations.add(
            const BitcoinBlockHeaderAttestation(2),
          );
      t.add(OpAppend(Uint8List.fromList([1]))).attestations.add(
            const BitcoinBlockHeaderAttestation(3),
          );
      t.add(const OpSHA256()).attestations.add(
            const BitcoinBlockHeaderAttestation(4),
          );

      const btc = '0588960d73d71901';
      const pending = '83dfe30d2ef90c8e';
      final expected = [
        // Bitcoin's tag sorts before Pending's; pending URIs sort a < b.
        'ff00${btc}0105',
        'ff00${pending}0a0968747470733a2f2f61',
        'ff00${pending}0a0968747470733a2f2f62', // last attestation
        'ff08'
            '00${btc}0104', // sha256 (0x08) first
        'fff00101'
            '00${btc}0103', // append 01 before append 09
        'fff00109'
            '00${btc}0102',
        'f10102'
            '00${btc}0101', // last op has no 0xff
      ].join();
      expect(hexEncode(t.toBytes()), expected);

      final back = Timestamp.fromBytes(t.toBytes(), digestOf(0));
      expect(back.toBytes(), t.toBytes());
      expect(back.attestations, t.attestations);
      expect(back.ops.keys.toSet(), t.ops.keys.toSet());
    });

    test('an empty timestamp cannot be serialized', () {
      expect(() => Timestamp(digestOf(0)).toBytes(), throwsStateError);
    });

    test('unknown attestations round-trip byte-for-byte', () {
      const body = '00' '0102030405060708' '03aabbcc';
      final t = Timestamp.fromBytes(hexDecode(body), digestOf(0));
      final a = t.attestations.single as UnknownAttestation;
      expect(hexEncode(a.tag), '0102030405060708');
      expect(hexEncode(a.payload), 'aabbcc');
      expect(hexEncode(t.toBytes()), body);
    });

    test('rejects unsupported op tags', () {
      for (final tag in ['02', '03', '67', 'f2', 'f3']) {
        expect(
            () => Timestamp.fromBytes(
                hexDecode('$tag' '000588960d73d719010101'), digestOf(0)),
            throwsFormatException,
            reason: tag);
      }
    });

    test('rejects a pending URI with forbidden characters', () {
      final uri = 'https://x?y'.codeUnits;
      final payload = (ByteWriter()..writeVarbytes(uri)).toBytes();
      final w = ByteWriter()
        ..writeByte(0)
        ..write(PendingAttestation.tagBytes)
        ..writeVarbytes(payload);
      expect(() => Timestamp.fromBytes(w.toBytes(), digestOf(0)),
          throwsFormatException);
    });

    test('rejects attestation payload trailing bytes', () {
      expect(
          () => Timestamp.fromBytes(
              hexDecode('000588960d73d71901020100'), digestOf(0)),
          throwsFormatException);
    });

    test('rejects op results longer than 4096 bytes', () {
      final w = ByteWriter()
        ..writeByte(OpAppend.tagByte)
        ..writeVarbytes(Uint8List(4096 - 31))
        ..write(hexDecode('000588960d73d719010101'));
      expect(() => Timestamp.fromBytes(w.toBytes(), digestOf(0)),
          throwsFormatException);
    });

    test('enforces the recursion limit', () {
      Uint8List chain(int depth) =>
          hexDecode('08' * depth + '000588960d73d719010101');
      Timestamp.fromBytes(chain(255), digestOf(0));
      expect(() => Timestamp.fromBytes(chain(256), digestOf(0)),
          throwsFormatException);
    });
  });

  group('merge', () {
    test('unions attestations and paths', () {
      final a = Timestamp(digestOf(1));
      a.add(const OpSHA256()).attestations.add(PendingAttestation('https://a'));
      final b = Timestamp(digestOf(1));
      b.add(const OpSHA256()).attestations.add(
            const BitcoinBlockHeaderAttestation(7),
          );
      a.merge(b);
      expect(a.ops.length, 1);
      expect(a.ops.values.single.attestations, hasLength(2));
    });

    test('refuses a different message', () {
      expect(() => Timestamp(digestOf(1)).merge(Timestamp(digestOf(2))),
          throwsArgumentError);
    });
  });

  test('ops compute sha256, append and prepend', () {
    final m = Uint8List.fromList([1, 2]);
    expect(const OpSHA256()(m), sha256.convert(m).bytes);
    expect(OpAppend(Uint8List.fromList([3]))(m), [1, 2, 3]);
    expect(OpPrepend(Uint8List.fromList([0]))(m), [0, 1, 2]);
  });
}
