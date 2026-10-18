import 'dart:typed_data';

import 'package:dart_opentimestamps/src/codec.dart';
import 'package:test/test.dart';

void main() {
  group('varuint', () {
    for (final (value, hex) in [
      (0, '00'),
      (1, '01'),
      (127, '7f'),
      (128, '8001'),
      (300, 'ac02'),
      (358391, 'f7ef15'),
    ]) {
      test('$value <-> $hex', () {
        expect(hexEncode((ByteWriter()..writeVaruint(value)).toBytes()), hex);
        expect(ByteReader(hexDecode(hex)).readVaruint(), value);
      });
    }

    test('truncated input is a FormatException', () {
      expect(() => ByteReader(hexDecode('80')).readVaruint(),
          throwsFormatException);
    });

    test('overlong input is a FormatException', () {
      expect(() => ByteReader(hexDecode('ff' * 9 + '01')).readVaruint(),
          throwsFormatException);
    });
  });

  test('varbytes enforces bounds', () {
    final bytes = (ByteWriter()..writeVarbytes([1, 2, 3])).toBytes();
    expect(ByteReader(bytes).readVarbytes(max: 3), [1, 2, 3]);
    expect(() => ByteReader(bytes).readVarbytes(max: 2), throwsFormatException);
    expect(() => ByteReader(bytes).readVarbytes(max: 9, min: 4),
        throwsFormatException);
  });

  test('read past end and trailing bytes are FormatExceptions', () {
    final r = ByteReader(Uint8List.fromList([1, 2]));
    expect(() => r.read(3), throwsFormatException);
    r.read(1);
    expect(r.assertEnd, throwsFormatException);
    r.read(1);
    r.assertEnd();
  });

  test('hex round-trips and rejects bad input', () {
    expect(hexEncode(hexDecode('00ff7A')), '00ff7a');
    for (final bad in ['0', 'zz', '+1', ' 1', '-1']) {
      expect(() => hexDecode(bad), throwsFormatException, reason: bad);
    }
  });

  test('compareBytes is lexicographic', () {
    expect(compareBytes([1], [2]), isNegative);
    expect(compareBytes([1, 0], [1]), isPositive);
    expect(compareBytes([3], [3]), 0);
  });
}
