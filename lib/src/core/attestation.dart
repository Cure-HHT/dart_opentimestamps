/// OpenTimestamps attestations
library;

import 'dart:typed_data';

abstract class Attestation {
  const Attestation();
  Uint8List serialize();
}

class PendingAttestation extends Attestation {
  const PendingAttestation(this.uri);
  final String uri;

  @override
  Uint8List serialize() {
    throw UnimplementedError('PendingAttestation.serialize()');
  }
}

class BitcoinBlockHeaderAttestation extends Attestation {
  const BitcoinBlockHeaderAttestation(this.height);
  final int height;

  @override
  Uint8List serialize() {
    throw UnimplementedError('BitcoinBlockHeaderAttestation.serialize()');
  }
}
