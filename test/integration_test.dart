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

@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:test/test.dart';

/// Integration tests that connect to real OpenTimestamps calendar servers.
///
/// These tests require network access and interact with production calendar
/// servers. They are tagged with 'integration' so they can be run separately:
///
/// ```bash
/// dart test --tags integration
/// ```
///
/// To exclude them from regular test runs:
/// ```bash
/// dart test --exclude-tags integration
/// ```
void main() {
  group('Integration Tests - Real Calendar Servers', () {
    late OpenTimestampsClient client;

    setUp(() {
      client = OpenTimestampsClient();
    });

    tearDown(() {
      client.close();
    });

    test('stamp creates pending attestation from real servers', () async {
      // Create a unique message to timestamp
      final message = 'Test timestamp ${DateTime.now().toIso8601String()}';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      // Submit to real calendar servers
      final stamped = await client.stamp(detached);

      // Verify we got pending attestations
      final attestations = stamped.timestamp.getAllAttestations();
      expect(attestations, isNotEmpty,
          reason: 'Should have attestations from calendar servers');

      // All attestations should be pending (Bitcoin inclusion takes time)
      for (final attestation in attestations) {
        expect(attestation, isA<PendingAttestation>(),
            reason: 'New timestamps should have pending attestations');
      }

      // Verify timestamp structure
      expect(stamped.fileHash.length, equals(32),
          reason: 'SHA-256 hash should be 32 bytes');
      expect(stamped.fileHashOp, equals(const OpSHA256()));

      // Print info for debugging
      print('Submitted timestamp to ${attestations.length} calendar(s)');
      for (final attestation in attestations.whereType<PendingAttestation>()) {
        print('  - ${attestation.uri}');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('stamp from hash works with real servers', () async {
      // Create a pre-computed hash
      final hash = Uint8List.fromList(List.generate(32, (i) => (i * 7) % 256));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Submit to real calendar servers
      final stamped = await client.stamp(detached);

      // Verify we got pending attestations
      final attestations = stamped.timestamp.getAllAttestations();
      expect(attestations, isNotEmpty);

      print(
          'Submitted pre-computed hash to ${attestations.length} calendar(s)');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('serialization round-trip after stamping', () async {
      // Create and stamp a message
      final message =
          'Serialization test ${DateTime.now().millisecondsSinceEpoch}';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      final stamped = await client.stamp(detached);

      // Serialize to OTS format
      final serialized = stamped.serialize();
      expect(serialized, isNotEmpty);

      // Deserialize and verify
      final deserialized = DetachedTimestampFile.deserialize(serialized);

      // Hashes should match
      expect(deserialized.fileHash, equals(stamped.fileHash));

      // Attestations should be preserved
      final originalAttestations = stamped.timestamp.getAllAttestations();
      final deserializedAttestations =
          deserialized.timestamp.getAllAttestations();
      expect(
          deserializedAttestations.length, equals(originalAttestations.length));

      print('Serialized OTS file: ${serialized.length} bytes');
      print('Attestations preserved: ${deserializedAttestations.length}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('upgrade returns false for fresh timestamp', () async {
      // Create and stamp a message
      final message = 'Upgrade test ${DateTime.now().millisecondsSinceEpoch}';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      final stamped = await client.stamp(detached);

      // Try to upgrade immediately - should return false since
      // Bitcoin block inclusion takes at least 10+ minutes
      final upgraded = await client.upgrade(stamped);

      // Fresh timestamps won't be confirmed yet
      expect(upgraded, isFalse,
          reason: 'Fresh timestamps cannot be upgraded immediately');

      print(
          'Upgrade attempt returned: $upgraded (expected false for fresh timestamp)');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('info() produces readable output', () async {
      final message = 'Info test message';
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final detached = DetachedTimestampFile.fromBytes(messageBytes);

      final stamped = await client.stamp(detached);

      final info = stamped.info();

      // Should contain hash information
      expect(info, contains('sha256'));
      expect(info, contains('hash:'));

      // Should contain timestamp tree info
      expect(info, contains('Timestamp:'));

      // Should mention pending attestations
      expect(info, contains('PendingAttestation'));

      print('Timestamp info:\n$info');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('multiple stamps use different nonces', () async {
      // Create the same message
      final message = 'Nonce test message';
      final messageBytes = Uint8List.fromList(utf8.encode(message));

      // Stamp twice
      final detached1 = DetachedTimestampFile.fromBytes(messageBytes);
      final stamped1 = await client.stamp(detached1);

      final detached2 = DetachedTimestampFile.fromBytes(messageBytes);
      final stamped2 = await client.stamp(detached2);

      // File hashes should be the same (same input)
      expect(stamped1.fileHash, equals(stamped2.fileHash));

      // But the timestamp trees should differ (different nonces)
      // The operations applied should include different append data
      final tree1 = stamped1.timestamp.strTree();
      final tree2 = stamped2.timestamp.strTree();

      // Trees should have similar structure but different nonce values
      expect(tree1, isNot(equals(tree2)),
          reason: 'Different nonces should produce different timestamp trees');

      print('First timestamp tree:\n$tree1');
      print('Second timestamp tree:\n$tree2');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Integration Tests - Calendar Server Resilience', () {
    test('succeeds with subset of working calendars', () async {
      // Use a mix of valid and invalid calendar URLs
      final client = OpenTimestampsClient(
        calendarUrls: [
          'https://invalid.calendar.fake.example.com', // Invalid
          'https://alice.btc.calendar.opentimestamps.org', // Valid
          'https://another.fake.calendar.example.com', // Invalid
        ],
      );

      try {
        final message =
            'Resilience test ${DateTime.now().millisecondsSinceEpoch}';
        final messageBytes = Uint8List.fromList(utf8.encode(message));
        final detached = DetachedTimestampFile.fromBytes(messageBytes);

        // Should succeed because at least one calendar works
        final stamped = await client.stamp(detached);

        final attestations = stamped.timestamp.getAllAttestations();
        expect(attestations, isNotEmpty);

        print('Successfully stamped despite some invalid calendars');
        print('Got ${attestations.length} attestation(s)');
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('fails when all calendars are invalid', () async {
      final client = OpenTimestampsClient(
        calendarUrls: [
          'https://invalid1.fake.example.com',
          'https://invalid2.fake.example.com',
        ],
      );

      try {
        final message = 'All fail test';
        final messageBytes = Uint8List.fromList(utf8.encode(message));
        final detached = DetachedTimestampFile.fromBytes(messageBytes);

        // Should throw because no calendars work
        expect(
          () => client.stamp(detached),
          throwsA(isA<OpenTimestampsException>()),
        );
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Integration Tests - Known Timestamp Verification', () {
    test('can deserialize and inspect real OTS format', () {
      // This is a minimal valid OTS file structure for testing deserialization
      // In a real scenario, you would load an actual .ots file
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      final detached = DetachedTimestampFile.fromHash(hash);

      // Add a simulated attestation structure
      final child = detached.timestamp.add(const OpSHA256());
      child.addAttestation(const PendingAttestation('https://test.calendar'));

      // Serialize and deserialize
      final serialized = detached.serialize();
      final deserialized = DetachedTimestampFile.deserialize(serialized);

      // Verify structure
      expect(deserialized.fileHash, equals(hash));

      final attestations = deserialized.timestamp.getAllAttestations();
      expect(attestations.length, equals(1));
      expect(attestations.first, isA<PendingAttestation>());
    });
  });
}
