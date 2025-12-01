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

import 'dart:typed_data';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

void main() {
  group('StreamDeserializationContext', () {
    group('constructor and properties', () {
      test('initializes with buffer at position 0', () {
        final buffer = Uint8List.fromList([1, 2, 3]);
        final ctx = StreamDeserializationContext(buffer);

        expect(ctx.position, equals(0));
        expect(ctx.isEOF, isFalse);
      });

      test('empty buffer is immediately at EOF', () {
        final ctx = StreamDeserializationContext(Uint8List(0));

        expect(ctx.isEOF, isTrue);
        expect(ctx.position, equals(0));
      });
    });

    group('readByte', () {
      test('reads single byte and advances position', () {
        final ctx =
            StreamDeserializationContext(Uint8List.fromList([0xAB, 0xCD]));

        expect(ctx.readByte(), equals(0xAB));
        expect(ctx.position, equals(1));
        expect(ctx.readByte(), equals(0xCD));
        expect(ctx.position, equals(2));
      });

      test('throws FormatException at EOF', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([0x01]));
        ctx.readByte(); // consume the byte

        expect(ctx.readByte, throwsFormatException);
      });

      test('throws with position in error message', () {
        final ctx = StreamDeserializationContext(Uint8List(0));

        expect(
          ctx.readByte,
          throwsA(predicate(
              (e) => e is FormatException && e.message.contains('position 0'))),
        );
      });
    });

    group('readBytes', () {
      test('reads multiple bytes', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([1, 2, 3, 4, 5]),
        );

        final result = ctx.readBytes(3);

        expect(result, equals(Uint8List.fromList([1, 2, 3])));
        expect(ctx.position, equals(3));
      });

      test('reads zero bytes', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2, 3]));

        final result = ctx.readBytes(0);

        expect(result, isEmpty);
        expect(ctx.position, equals(0));
      });

      test('throws when not enough bytes available', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2]));

        expect(() => ctx.readBytes(5), throwsFormatException);
      });

      test('throws with detailed error message', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2]));

        expect(
          () => ctx.readBytes(10),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.message.contains('requested 10 bytes') &&
              e.message.contains('only 2 bytes available'))),
        );
      });

      test('reads exact remaining bytes', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2, 3]));

        final result = ctx.readBytes(3);

        expect(result.length, equals(3));
        expect(ctx.isEOF, isTrue);
      });
    });

    group('readVarint', () {
      test('reads single-byte varint', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([0x7F]));
        expect(ctx.readVarint(), equals(127));
      });

      test('reads two-byte varint', () {
        // 128 = 0x80 | (0x01 << 7)
        final ctx =
            StreamDeserializationContext(Uint8List.fromList([0x80, 0x01]));
        expect(ctx.readVarint(), equals(128));
      });

      test('reads larger varint', () {
        // 300 = [0xac, 0x02]
        final ctx =
            StreamDeserializationContext(Uint8List.fromList([0xac, 0x02]));
        expect(ctx.readVarint(), equals(300));
      });

      test('reads varint value 0', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([0x00]));
        expect(ctx.readVarint(), equals(0));
      });

      test('throws on incomplete varint', () {
        // 0x80 means "more bytes follow" but there are none
        final ctx = StreamDeserializationContext(Uint8List.fromList([0x80]));

        expect(ctx.readVarint, throwsFormatException);
      });

      test('throws on varint too large', () {
        // Create a varint with too many continuation bytes
        final bytes = <int>[...List.filled(10, 0x80), 0x01]; // terminator
        final ctx = StreamDeserializationContext(Uint8List.fromList(bytes));

        expect(
          ctx.readVarint,
          throwsA(predicate(
              (e) => e is FormatException && e.message.contains('too large'))),
        );
      });
    });

    group('readVarbytes', () {
      test('reads variable-length bytes', () {
        // length 3, then [1, 2, 3]
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x03, 1, 2, 3]),
        );

        final result = ctx.readVarbytes();

        expect(result, equals(Uint8List.fromList([1, 2, 3])));
      });

      test('reads zero-length varbytes', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([0x00]));

        final result = ctx.readVarbytes();

        expect(result, isEmpty);
      });

      test('respects maxLength parameter', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x10, ...List.filled(16, 0xFF)]),
        );

        expect(() => ctx.readVarbytes(maxLength: 5), throwsFormatException);
      });

      test('throws with descriptive error for exceeding maxLength', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x64, ...List.filled(100, 0)]),
        );

        expect(
          () => ctx.readVarbytes(maxLength: 50),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.message.contains('exceeds maximum 50'))),
        );
      });

      test('allows exactly maxLength bytes', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x03, 1, 2, 3]),
        );

        final result = ctx.readVarbytes(maxLength: 3);

        expect(result.length, equals(3));
      });
    });

    group('assertMagic', () {
      test('succeeds when bytes match', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x00, 0x01, 0x02]),
        );

        // Should not throw
        ctx.assertMagic([0x00, 0x01, 0x02]);
        expect(ctx.isEOF, isTrue);
      });

      test('throws when bytes do not match', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x00, 0x01, 0x02]),
        );

        expect(
            () => ctx.assertMagic([0x00, 0xFF, 0x02]), throwsFormatException);
      });

      test('throws with position and expected/actual values', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0xAB]),
        );

        expect(
          () => ctx.assertMagic([0xCD]),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.message.contains('expected 0xcd') &&
              e.message.contains('got 0xab'))),
        );
      });

      test('handles empty magic bytes', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2, 3]));

        ctx.assertMagic([]);
        expect(ctx.position, equals(0));
      });
    });

    group('deserializeOperation', () {
      test('deserializes OpSHA256', () {
        final ctx = StreamDeserializationContext(Uint8List(0));
        final op = ctx.deserializeOperation(0x08);

        expect(op, isA<OpSHA256>());
      });

      test('deserializes OpRIPEMD160', () {
        final ctx = StreamDeserializationContext(Uint8List(0));
        final op = ctx.deserializeOperation(0x03);

        expect(op, isA<OpRIPEMD160>());
      });

      test('deserializes OpAppend with data', () {
        // varint length 3, then [1, 2, 3]
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x03, 1, 2, 3]),
        );
        final op = ctx.deserializeOperation(0xf0);

        expect(op, isA<OpAppend>());
        expect((op as OpAppend).data, equals(Uint8List.fromList([1, 2, 3])));
      });

      test('deserializes OpPrepend with data', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([0x02, 0xAB, 0xCD]),
        );
        final op = ctx.deserializeOperation(0xf1);

        expect(op, isA<OpPrepend>());
        expect(
            (op as OpPrepend).data, equals(Uint8List.fromList([0xAB, 0xCD])));
      });

      test('throws for unknown operation tag', () {
        final ctx = StreamDeserializationContext(Uint8List(0));

        expect(() => ctx.deserializeOperation(0xFF), throwsFormatException);
      });

      test('throws with hex tag in error message', () {
        final ctx = StreamDeserializationContext(Uint8List(0));

        expect(
          () => ctx.deserializeOperation(0xEE),
          throwsA(predicate(
              (e) => e is FormatException && e.message.contains('0xee'))),
        );
      });
    });

    group('isEOF and position', () {
      test('isEOF is false until all bytes read', () {
        final ctx = StreamDeserializationContext(Uint8List.fromList([1, 2]));

        expect(ctx.isEOF, isFalse);
        ctx.readByte();
        expect(ctx.isEOF, isFalse);
        ctx.readByte();
        expect(ctx.isEOF, isTrue);
      });

      test('position tracks correctly through mixed reads', () {
        final ctx = StreamDeserializationContext(
          Uint8List.fromList([1, 2, 3, 4, 5, 6]),
        );

        expect(ctx.position, equals(0));
        ctx.readByte();
        expect(ctx.position, equals(1));
        ctx.readBytes(2);
        expect(ctx.position, equals(3));
        ctx.readVarint(); // reads 1 byte (value 4)
        expect(ctx.position, equals(4));
      });
    });
  });
}
