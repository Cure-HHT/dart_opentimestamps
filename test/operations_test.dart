import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_opentimestamps/open_timestamps.dart';

void main() {
  group('Operations', () {
    test('OpSHA256 produces correct hash', () {
      final op = const OpSHA256();
      final message = Uint8List(0); // Empty message
      
      final result = op.apply(message);
      
      // SHA256 of empty string
      final expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final actual = result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      
      expect(actual, equals(expected));
    });

    test('OpAppend appends data correctly', () {
      final message = Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"
      final appendData = Uint8List.fromList([0x21]); // "!"
      
      final op = OpAppend(appendData);
      final result = op.apply(message);
      
      expect(result, equals(Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21])));
      expect(String.fromCharCodes(result), equals('Hello!'));
    });

    test('OpPrepend prepends data correctly', () {
      final message = Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"
      final prependData = Uint8List.fromList([0x3e, 0x20]); // "> "
      
      final op = OpPrepend(prependData);
      final result = op.apply(message);
      
      expect(result, equals(Uint8List.fromList([0x3e, 0x20, 0x48, 0x65, 0x6c, 0x6c, 0x6f])));
      expect(String.fromCharCodes(result), equals('> Hello'));
    });

    test('Operations are equal based on data', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([1, 2, 3]);
      final data3 = Uint8List.fromList([4, 5, 6]);
      
      expect(OpAppend(data1), equals(OpAppend(data2)));
      expect(OpAppend(data1), isNot(equals(OpAppend(data3))));
      expect(OpAppend(data1), isNot(equals(OpPrepend(data1))));
    });

    test('OpSHA256 operations are equal', () {
      expect(const OpSHA256(), equals(const OpSHA256()));
    });
  });

  group('Varint encoding/decoding', () {
    test('Encodes and decodes small values', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0x05]));
      expect(ctx.readVarint(), equals(5));
    });

    test('Encodes and decodes larger values', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0x80, 0x01]));
      expect(ctx.readVarint(), equals(128));
    });

    test('Encodes and decodes 16-bit values', () {
      final ctx = StreamDeserializationContext(Uint8List.fromList([0xac, 0x02]));
      expect(ctx.readVarint(), equals(300));
    });
  });
}
