// Contacts the public calendars once. Runs only with OTS_LIVE=1, so the
// default test run never touches the network.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a real stamp parses every calendar reply',
    () async {
      final random = Random.secure();
      final digest =
          Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
      final client = OpenTimestampsClient();
      try {
        final proof = await client.stamp(digest);
        expect(proof.pendingCalendars.length, greaterThanOrEqualTo(2));
        expect(
          verifyTimestamp(proof.serialize(), digest, {}),
          isA<VerificationPending>(),
        );
        printOnFailure(proof.pendingCalendars.join('\n'));
      } finally {
        client.close();
      }
    },
    skip: Platform.environment['OTS_LIVE'] == '1' ? false : 'set OTS_LIVE=1',
  );
}
