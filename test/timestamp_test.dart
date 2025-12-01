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

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

void main() {
  group('Timestamp', () {
    test('creates with message', () {
      final msg = Uint8List.fromList([1, 2, 3, 4]);
      final timestamp = Timestamp(msg);

      expect(timestamp.msg, equals(msg));
      expect(timestamp.attestations, isEmpty);
      expect(timestamp.ops, isEmpty);
    });

    test('add creates new timestamp with operation result', () {
      final msg = Uint8List.fromList([1, 2, 3]);
      final timestamp = Timestamp(msg);

      final appendData = Uint8List.fromList([4, 5]);
      final newTimestamp = timestamp.add(OpAppend(appendData));

      expect(newTimestamp.msg, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
      expect(timestamp.ops.length, equals(1));
    });

    test('add returns existing timestamp for duplicate operation', () {
      final msg = Uint8List.fromList([1, 2, 3]);
      final timestamp = Timestamp(msg);

      final appendData = Uint8List.fromList([4, 5]);
      final newTimestamp1 = timestamp.add(OpAppend(appendData));
      final newTimestamp2 = timestamp.add(OpAppend(appendData));

      expect(identical(newTimestamp1, newTimestamp2), isTrue);
      expect(timestamp.ops.length, equals(1));
    });

    test('addAttestation adds attestation to list', () {
      final timestamp = Timestamp(Uint8List(32));

      timestamp.addAttestation(const PendingAttestation('https://example.com'));

      expect(timestamp.attestations.length, equals(1));
      expect(timestamp.attestations.first, isA<PendingAttestation>());
    });

    test('addAttestation allows multiple attestations', () {
      final timestamp = Timestamp(Uint8List(32));

      timestamp.addAttestation(const PendingAttestation('https://a.com'));
      timestamp.addAttestation(const PendingAttestation('https://b.com'));
      timestamp.addAttestation(const BitcoinBlockHeaderAttestation(500000));

      expect(timestamp.attestations.length, equals(3));
    });

    test('getAllAttestations returns empty list for no attestations', () {
      final timestamp = Timestamp(Uint8List(32));

      expect(timestamp.getAllAttestations(), isEmpty);
    });

    test('getAllAttestations returns attestations from single node', () {
      final timestamp = Timestamp(Uint8List(32));
      timestamp.addAttestation(const PendingAttestation('https://a.com'));

      final all = timestamp.getAllAttestations();

      expect(all.length, equals(1));
    });

    test('getAllAttestations collects from entire tree', () {
      final root = Timestamp(Uint8List.fromList([1, 2, 3]));
      root.addAttestation(const PendingAttestation('root'));

      final child1 = root.add(const OpSHA256());
      child1.addAttestation(const PendingAttestation('child1'));

      final child2 = root.add(OpAppend(Uint8List.fromList([4, 5])));
      child2.addAttestation(const BitcoinBlockHeaderAttestation(12345));

      final grandchild = child1.add(const OpSHA256());
      grandchild.addAttestation(const PendingAttestation('grandchild'));

      final all = root.getAllAttestations();

      expect(all.length, equals(4));
    });
  });

  group('Timestamp.strTree', () {
    test('empty timestamp shows no attestations message', () {
      final timestamp = Timestamp(Uint8List(32));

      final tree = timestamp.strTree();

      expect(tree, contains('(no attestations)'));
    });

    test('shows attestations with verify prefix', () {
      final timestamp = Timestamp(Uint8List(32));
      timestamp.addAttestation(const PendingAttestation('https://example.com'));

      final tree = timestamp.strTree();

      expect(tree, contains('verify'));
      expect(tree, contains('PendingAttestation'));
    });

    test('shows operations in tree', () {
      final timestamp = Timestamp(Uint8List.fromList([1, 2, 3]));
      final child = timestamp.add(const OpSHA256());
      child.addAttestation(const BitcoinBlockHeaderAttestation(100));

      final tree = timestamp.strTree();

      expect(tree, contains('sha256'));
      expect(tree, contains('BitcoinBlockHeaderAttestation'));
    });

    test('respects indent parameter', () {
      final timestamp = Timestamp(Uint8List(32));

      final tree = timestamp.strTree(indent: 4);

      expect(tree, startsWith('    '));
    });

    test('shows multiple operations sorted by tag', () {
      final timestamp = Timestamp(Uint8List.fromList([1, 2, 3]));

      // Add operations - they should be sorted by tag in output
      timestamp.add(OpPrepend(Uint8List.fromList([0]))); // tag 0xf1
      timestamp.add(const OpSHA256()); // tag 0x08
      timestamp.add(OpAppend(Uint8List.fromList([4]))); // tag 0xf0

      final tree = timestamp.strTree();

      // SHA256 (0x08) should come before append (0xf0) and prepend (0xf1)
      final sha256Pos = tree.indexOf('sha256');
      final appendPos = tree.indexOf('append');
      final prependPos = tree.indexOf('prepend');

      expect(sha256Pos, lessThan(appendPos));
      expect(appendPos, lessThan(prependPos));
    });

    test('nested operations show increasing indentation', () {
      final timestamp = Timestamp(Uint8List.fromList([1, 2, 3]));
      final child = timestamp.add(const OpSHA256());
      child.add(const OpSHA256());

      final tree = timestamp.strTree();

      // Should have nested structure
      expect(tree, contains('sha256'));
    });
  });

  group('Timestamp.toString', () {
    test('returns strTree output', () {
      final timestamp = Timestamp(Uint8List(32));
      timestamp.addAttestation(const PendingAttestation('test'));

      expect(timestamp.toString(), equals(timestamp.strTree()));
    });
  });
}
