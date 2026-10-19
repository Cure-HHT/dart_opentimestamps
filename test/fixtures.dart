import 'dart:io';
import 'dart:typed_data';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';

/// Bytes of `test/fixtures/<name>`.
Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

/// The real header of Bitcoin block 358391.
Uint8List block358391Header() => hexDecode(
      File('test/fixtures/block-358391.header.hex').readAsStringSync().trim(),
    );

/// A 32-byte digest filled with [b].
Uint8List digestOf(int b) => Uint8List(32)..fillRange(0, 32, b);
