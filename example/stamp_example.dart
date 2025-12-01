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

import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_opentimestamps/dart_opentimestamps.dart';

void main() async {
  print('OpenTimestamps Dart Example\n');

  // Example 1: Create a timestamp from bytes
  final message = 'Hello World!\n';
  final messageBytes = Uint8List.fromList(utf8.encode(message));

  final detached = DetachedTimestampFile.fromBytes(messageBytes);

  print('--- File Information ---');
  print(detached.info());

  // Example 2: Create a timestamp from a pre-computed hash
  final hashHex =
      '03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340';
  final hash = Uint8List.fromList(
    List.generate(
      hashHex.length ~/ 2,
      (i) => int.parse(hashHex.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );

  final detachedFromHash = DetachedTimestampFile.fromHash(hash);

  print('\n--- From Hash ---');
  print(detachedFromHash.info());

  // Example 3: Build a timestamp tree manually
  print('\n--- Building Timestamp Tree ---');

  final timestamp = detached.timestamp;

  // Add a nonce (random bytes appended for privacy)
  final nonce = Uint8List.fromList([
    0xc0,
    0x41,
    0x58,
    0xb1,
    0x83,
    0xa3,
    0x78,
    0xf3,
    0xd0,
    0x51,
    0xd5,
    0x59,
    0x79,
    0xa9,
    0x18,
    0xd8,
  ]);

  final nonceAppended = timestamp.add(OpAppend(nonce));
  final sha256After = nonceAppended.add(const OpSHA256());

  // Add a pending attestation
  sha256After.addAttestation(
    const PendingAttestation('https://alice.btc.calendar.opentimestamps.org'),
  );

  print('Timestamp with nonce and attestation:');
  print(timestamp.strTree());

  // Example 4: Serialize to OTS format
  print('\n--- Serialization ---');
  final otsBytes = detached.serialize();
  print('OTS file size: ${otsBytes.length} bytes');
  print(
      'First 32 bytes (hex): ${otsBytes.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  print('\n--- Operations Demo ---');

  // Demonstrate operation application
  final msg = Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"

  print('Original: ${String.fromCharCodes(msg)}');

  final appendOp = OpAppend(Uint8List.fromList([0x21])); // "!"
  final appended = appendOp.apply(msg);
  print('After append: ${String.fromCharCodes(appended)}');

  final prependOp = OpPrepend(Uint8List.fromList([0x3e, 0x20])); // "> "
  final prepended = prependOp.apply(msg);
  print('After prepend: ${String.fromCharCodes(prepended)}');

  final sha256Op = const OpSHA256();
  final hashed = sha256Op.apply(msg);
  print(
      'After SHA256: ${hashed.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  print('\n✓ Example completed successfully!');
}
