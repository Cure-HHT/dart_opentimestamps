/// OpenTimestamps client
library;

import 'dart:typed_data';
import '../verification/verification_result.dart';

class OpenTimestampsClient {
  OpenTimestampsClient();

  Future<Uint8List> stamp(Uint8List hash) async {
    throw UnimplementedError('stamp()');
  }

  Future<Uint8List?> upgrade(Uint8List incompleteProof) async {
    throw UnimplementedError('upgrade()');
  }

  Future<VerificationResult> verify(
    Uint8List dataHash,
    Uint8List proof,
  ) async {
    throw UnimplementedError('verify()');
  }

  void close() {}
}
