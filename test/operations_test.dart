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

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:test/test.dart';

void main() {
  group('OpSHA256', () {
    test('produces correct hash for empty message', () {
      const op = OpSHA256();
      final message = Uint8List(0);

      final result = op.apply(message);

      // SHA256 of empty string
      final expected =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final actual =
          result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      expect(actual, equals(expected));
    });

    test('produces correct hash for non-empty message', () {
      const op = OpSHA256();
      final message = Uint8List.fromList([0x61, 0x62, 0x63]); // "abc"

      final result = op.apply(message);

      final expected =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      final actual =
          result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      expect(actual, equals(expected));
    });

    test('tag is 0x08', () {
      const op = OpSHA256();
      expect(op.tag, equals(0x08));
    });

    test('serialize returns single byte with tag', () {
      const op = OpSHA256();
      final serialized = op.serialize();

      expect(serialized.length, equals(1));
      expect(serialized[0], equals(0x08));
    });

    test('toString returns "sha256"', () {
      const op = OpSHA256();
      expect(op.toString(), equals('sha256'));
    });

    test('equality works correctly', () {
      const op1 = OpSHA256();
      const op2 = OpSHA256();

      expect(op1, equals(op2));
      expect(op1.hashCode, equals(op2.hashCode));
    });

    test('is not equal to other operation types', () {
      const sha = OpSHA256();
      final append = OpAppend(Uint8List(0));

      expect(sha, isNot(equals(append)));
    });
  });

  group('OpAppend', () {
    test('appends data correctly', () {
      final message =
          Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"
      final appendData = Uint8List.fromList([0x21]); // "!"

      final op = OpAppend(appendData);
      final result = op.apply(message);

      expect(result,
          equals(Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21])));
      expect(String.fromCharCodes(result), equals('Hello!'));
    });

    test('appends empty data', () {
      final message = Uint8List.fromList([1, 2, 3]);
      final op = OpAppend(Uint8List(0));

      final result = op.apply(message);

      expect(result, equals(message));
    });

    test('appends to empty message', () {
      final message = Uint8List(0);
      final appendData = Uint8List.fromList([1, 2, 3]);
      final op = OpAppend(appendData);

      final result = op.apply(message);

      expect(result, equals(appendData));
    });

    test('tag is 0xf0', () {
      final op = OpAppend(Uint8List(0));
      expect(op.tag, equals(0xf0));
    });

    test('serialize includes tag, length varint, and data', () {
      final op = OpAppend(Uint8List.fromList([1, 2, 3]));
      final serialized = op.serialize();

      expect(serialized[0], equals(0xf0)); // tag
      expect(serialized[1], equals(3)); // length varint
      expect(serialized.sublist(2), equals([1, 2, 3])); // data
    });

    test('serialize handles larger data with multi-byte varint', () {
      final data = Uint8List.fromList(List.filled(200, 0xAB));
      final op = OpAppend(data);
      final serialized = op.serialize();

      expect(serialized[0], equals(0xf0));
      // 200 = [0xc8, 0x01] in varint
      expect(serialized[1], equals(0xc8));
      expect(serialized[2], equals(0x01));
    });

    test('toString shows hex data', () {
      final op = OpAppend(Uint8List.fromList([0xAB, 0xCD]));
      expect(op.toString(), equals('append abcd'));
    });

    test('equality based on data content', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2, 3]);
      final data3 = Uint8List.fromList([4, 5, 6]);

      expect(OpAppend(data1), equals(OpAppend(data2)));
      expect(OpAppend(data1), isNot(equals(OpAppend(data3))));
    });

    test('not equal to OpPrepend with same data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      expect(OpAppend(data), isNot(equals(OpPrepend(data))));
    });

    test('hashCode is based on data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final op1 = OpAppend(data);
      final op2 = OpAppend(data);

      expect(op1.hashCode, equals(op2.hashCode));
    });

    test('different length data is not equal', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2]);

      expect(OpAppend(data1), isNot(equals(OpAppend(data2))));
    });
  });

  group('OpPrepend', () {
    test('prepends data correctly', () {
      final message =
          Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"
      final prependData = Uint8List.fromList([0x3e, 0x20]); // "> "

      final op = OpPrepend(prependData);
      final result = op.apply(message);

      expect(
          result,
          equals(
              Uint8List.fromList([0x3e, 0x20, 0x48, 0x65, 0x6c, 0x6c, 0x6f])));
      expect(String.fromCharCodes(result), equals('> Hello'));
    });

    test('prepends empty data', () {
      final message = Uint8List.fromList([1, 2, 3]);
      final op = OpPrepend(Uint8List(0));

      final result = op.apply(message);

      expect(result, equals(message));
    });

    test('prepends to empty message', () {
      final message = Uint8List(0);
      final prependData = Uint8List.fromList([1, 2, 3]);
      final op = OpPrepend(prependData);

      final result = op.apply(message);

      expect(result, equals(prependData));
    });

    test('tag is 0xf1', () {
      final op = OpPrepend(Uint8List(0));
      expect(op.tag, equals(0xf1));
    });

    test('serialize includes tag, length varint, and data', () {
      final op = OpPrepend(Uint8List.fromList([0xAB, 0xCD]));
      final serialized = op.serialize();

      expect(serialized[0], equals(0xf1)); // tag
      expect(serialized[1], equals(2)); // length varint
      expect(serialized.sublist(2), equals([0xAB, 0xCD])); // data
    });

    test('toString shows hex data', () {
      final op = OpPrepend(Uint8List.fromList([0x12, 0x34]));
      expect(op.toString(), equals('prepend 1234'));
    });

    test('equality based on data content', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2, 3]);
      final data3 = Uint8List.fromList([4, 5, 6]);

      expect(OpPrepend(data1), equals(OpPrepend(data2)));
      expect(OpPrepend(data1), isNot(equals(OpPrepend(data3))));
    });

    test('hashCode is based on data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final op = OpPrepend(data);

      expect(op.hashCode, equals(data.hashCode));
    });
  });

  group('OpRIPEMD160', () {
    test('tag is 0x03', () {
      const op = OpRIPEMD160();
      expect(op.tag, equals(0x03));
    });

    test('apply throws UnimplementedError', () {
      const op = OpRIPEMD160();
      final message = Uint8List.fromList([1, 2, 3]);

      expect(() => op.apply(message), throwsUnimplementedError);
    });

    test('serialize returns single byte with tag', () {
      const op = OpRIPEMD160();
      final serialized = op.serialize();

      expect(serialized.length, equals(1));
      expect(serialized[0], equals(0x03));
    });

    test('toString returns "ripemd160"', () {
      const op = OpRIPEMD160();
      expect(op.toString(), equals('ripemd160'));
    });

    test('equality works correctly', () {
      const op1 = OpRIPEMD160();
      const op2 = OpRIPEMD160();

      expect(op1, equals(op2));
      expect(op1.hashCode, equals(op2.hashCode));
    });

    test('is not equal to other operation types', () {
      const ripemd = OpRIPEMD160();
      const sha = OpSHA256();

      expect(ripemd, isNot(equals(sha)));
    });
  });

  group('Varint encoding/decoding', () {
    test('encodes and decodes value 0', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0x00]));
      expect(ctx.readVarint(), equals(0));
    });

    test('encodes and decodes small values', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0x05]));
      expect(ctx.readVarint(), equals(5));
    });

    test('encodes and decodes value 127 (max single byte)', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0x7f]));
      expect(ctx.readVarint(), equals(127));
    });

    test('encodes and decodes value 128 (first two-byte)', () {
      final ctx =
          StreamDeserializationContext(Uint8List.fromList([0x80, 0x01]));
      expect(ctx.readVarint(), equals(128));
    });

    test('encodes and decodes 16-bit values', () {
      final ctx =
          StreamDeserializationContext(Uint8List.fromList([0xac, 0x02]));
      expect(ctx.readVarint(), equals(300));
    });

    test('encodes and decodes larger values', () {
      // 16384 = [0x80, 0x80, 0x01]
      final ctx =
          StreamDeserializationContext(Uint8List.fromList([0x80, 0x80, 0x01]));
      expect(ctx.readVarint(), equals(16384));
    });
  });

  group('Operation type discrimination', () {
    test('operations of different types are not equal', () {
      const sha = OpSHA256();
      const ripemd = OpRIPEMD160();
      final append = OpAppend(Uint8List(0));
      final prepend = OpPrepend(Uint8List(0));

      expect(sha, isNot(equals(ripemd)));
      expect(sha, isNot(equals(append)));
      expect(sha, isNot(equals(prepend)));
      expect(append, isNot(equals(prepend)));
    });
  });

  group('encodeVarint', () {
    test('encodes value 0', () {
      final result = encodeVarint(0);
      expect(result, equals(Uint8List.fromList([0x00])));
    });

    test('encodes single-byte values', () {
      expect(encodeVarint(1), equals(Uint8List.fromList([0x01])));
      expect(encodeVarint(127), equals(Uint8List.fromList([0x7f])));
    });

    test('encodes two-byte values', () {
      expect(encodeVarint(128), equals(Uint8List.fromList([0x80, 0x01])));
      expect(encodeVarint(300), equals(Uint8List.fromList([0xac, 0x02])));
    });

    test('encodes larger values', () {
      expect(
          encodeVarint(16384), equals(Uint8List.fromList([0x80, 0x80, 0x01])));
    });

    test('throws ArgumentError for negative value', () {
      expect(
        () => encodeVarint(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for large negative value', () {
      expect(
        () => encodeVarint(-100),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('decodeVarint', () {
    test('decodes single-byte value', () {
      final bytes = Uint8List.fromList([0x05]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(5));
      expect(consumed, equals(1));
    });

    test('decodes value 127 (max single byte)', () {
      final bytes = Uint8List.fromList([0x7f]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(127));
      expect(consumed, equals(1));
    });

    test('decodes two-byte varint', () {
      final bytes = Uint8List.fromList([0x80, 0x01]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(128));
      expect(consumed, equals(2));
    });

    test('decodes value 300', () {
      final bytes = Uint8List.fromList([0xac, 0x02]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(300));
      expect(consumed, equals(2));
    });

    test('decodes from offset', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x05]);
      final (value, consumed) = decodeVarint(bytes, 2);

      expect(value, equals(5));
      expect(consumed, equals(1));
    });

    test('throws on incomplete varint', () {
      final bytes = Uint8List.fromList([0x80]); // Needs more bytes

      expect(() => decodeVarint(bytes, 0), throwsFormatException);
    });

    test('throws on varint too large', () {
      // Create a varint with too many continuation bytes (>64 bits)
      final bytes = Uint8List.fromList(
          [0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01]);

      expect(
        () => decodeVarint(bytes, 0),
        throwsA(predicate(
            (e) => e is FormatException && e.message.contains('too large'))),
      );
    });

    test('decodes zero', () {
      final bytes = Uint8List.fromList([0x00]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(0));
      expect(consumed, equals(1));
    });

    test('decodes larger value 16384', () {
      final bytes = Uint8List.fromList([0x80, 0x80, 0x01]);
      final (value, consumed) = decodeVarint(bytes, 0);

      expect(value, equals(16384));
      expect(consumed, equals(3));
    });
  });
}
