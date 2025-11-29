/// OpenTimestamps operations
library;

import 'dart:typed_data';

abstract class Operation {
  const Operation();
  Uint8List apply(Uint8List message);
  Uint8List serialize();
}

class OpSHA256 extends Operation {
  const OpSHA256();
  
  @override
  Uint8List apply(Uint8List message) {
    throw UnimplementedError('OpSHA256.apply()');
  }

  @override
  Uint8List serialize() => Uint8List.fromList([0x08]);
}

class OpAppend extends Operation {
  const OpAppend(this.data);
  final Uint8List data;

  @override
  Uint8List apply(Uint8List message) {
    throw UnimplementedError('OpAppend.apply()');
  }

  @override
  Uint8List serialize() {
    throw UnimplementedError('OpAppend.serialize()');
  }
}
