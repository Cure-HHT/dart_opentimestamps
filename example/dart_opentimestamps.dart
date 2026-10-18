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

/// Stamps a hash-chain head, upgrades the proof and verifies it.
library;

import 'package:dart_opentimestamps/dart_opentimestamps.dart';

Future<void> main() async {
  // The newest event's hash; it commits to every earlier event.
  final head = hexDecode(
    '03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340',
  );

  final client = OpenTimestampsClient();
  final headers = ExplorerBlockHeaderSource();
  try {
    // Once: submit to the calendars and store proof.serialize().
    final proof = await client.stamp(head);

    // Hours later (calendars commit to Bitcoin in batches), and only
    // until it is complete:
    await client.upgrade(proof);

    // Once complete, fetch each attested header once and store it with
    // the proof; from then on verification needs no network.
    final byHeight = {
      for (final h in proof.bitcoinHeights) h: await headers.headerAt(h),
    };
    final result = verifyTimestamp(proof.serialize(), head, byHeight);
    print(result);
  } finally {
    client.close();
    headers.close();
  }
}
