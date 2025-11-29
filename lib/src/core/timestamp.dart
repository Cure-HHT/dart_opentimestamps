/// OpenTimestamps timestamp structure
library;

import 'dart:typed_data';

class Timestamp {
  Timestamp();

  static Timestamp fromBytes(Uint8List bytes) {
    throw UnimplementedError('Timestamp.fromBytes()');
  }

  Uint8List toBytes() {
    throw UnimplementedError('Timestamp.toBytes()');
  }
}
