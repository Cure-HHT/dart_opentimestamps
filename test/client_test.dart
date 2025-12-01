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

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('OpenTimestampsClient', () {
    group('constructor', () {
      test('uses default calendar URLs when none provided', () {
        final client = OpenTimestampsClient();

        expect(client.calendarUrls.length, equals(3));
        expect(client.calendarUrls,
            contains('https://alice.btc.calendar.opentimestamps.org'));
        expect(client.calendarUrls,
            contains('https://bob.btc.calendar.opentimestamps.org'));
        expect(client.calendarUrls,
            contains('https://finney.calendar.eternitywall.com'));

        client.close();
      });

      test('accepts custom calendar URLs', () {
        final customUrls = ['https://custom1.com', 'https://custom2.com'];
        final client = OpenTimestampsClient(calendarUrls: customUrls);

        expect(client.calendarUrls, equals(customUrls));

        client.close();
      });

      test('accepts custom HTTP client', () {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        expect(client.calendarUrls.length, equals(3));

        client.close();
      });
    });

    group('stamp', () {
      test('submits to calendar servers and adds pending attestation',
          () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, equals('/digest'));
          expect(request.method, equals('POST'));
          expect(request.headers['Content-Type'],
              equals('application/octet-stream'));

          // Return some response bytes
          return http.Response.bytes(Uint8List.fromList([0x00]), 200);
        });

        final client = OpenTimestampsClient(
          calendarUrls: ['https://test.calendar.com'],
          httpClient: mockClient,
        );

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        final result = await client.stamp(detached);

        // Should have added attestations
        final attestations = result.timestamp.getAllAttestations();
        expect(attestations, isNotEmpty);

        client.close();
      });

      test('throws when all calendar servers fail', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final client = OpenTimestampsClient(
          calendarUrls: ['https://fail1.com', 'https://fail2.com'],
          httpClient: mockClient,
        );

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        expect(
          () => client.stamp(detached),
          throwsA(isA<OpenTimestampsException>()),
        );

        client.close();
      });

      test('succeeds if at least one calendar responds', () async {
        var requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            return http.Response('Error', 500);
          }
          return http.Response.bytes(Uint8List.fromList([0x00]), 200);
        });

        final client = OpenTimestampsClient(
          calendarUrls: ['https://fail.com', 'https://success.com'],
          httpClient: mockClient,
        );

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        final result = await client.stamp(detached);

        expect(result, isNotNull);
        client.close();
      });

      test('handles network exceptions gracefully', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        final client = OpenTimestampsClient(
          calendarUrls: ['https://error.com'],
          httpClient: mockClient,
        );

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        expect(
          () => client.stamp(detached),
          throwsA(isA<OpenTimestampsException>()),
        );

        client.close();
      });
    });

    group('upgrade', () {
      test('returns false when no pending attestations', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        final upgraded = await client.upgrade(detached);

        expect(upgraded, isFalse);

        client.close();
      });

      test('attempts to upgrade pending attestations', () async {
        final requestUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestUrls.add(request.url.toString());
          return http.Response('', 404); // Not ready yet
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        // Add a pending attestation
        detached.timestamp.addAttestation(
          const PendingAttestation('https://calendar.test'),
        );

        final upgraded = await client.upgrade(detached);

        expect(upgraded, isFalse);
        expect(requestUrls, isNotEmpty);
        expect(requestUrls.first, contains('calendar.test'));
        expect(requestUrls.first, contains('/timestamp/'));

        client.close();
      });

      test('handles upgrade request failures gracefully', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection refused');
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);
        detached.timestamp.addAttestation(
          const PendingAttestation('https://failing.calendar'),
        );

        // Should not throw, just return false
        final upgraded = await client.upgrade(detached);

        expect(upgraded, isFalse);

        client.close();
      });

      test('catches and logs errors from invalid attestation URIs', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        // Add an attestation with an invalid URI that will cause Uri.parse to fail
        // when constructing the upgrade URL
        detached.timestamp.addAttestation(
          const PendingAttestation('http://[invalid'),
        );

        // Should not throw, just log error and return false
        final upgraded = await client.upgrade(detached);

        expect(upgraded, isFalse);

        client.close();
      });

      test('finds pending attestations in nested timestamps', () async {
        var requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response('', 200);
        });

        final client = OpenTimestampsClient(httpClient: mockClient);

        final hash = Uint8List.fromList(List.generate(32, (i) => i));
        final detached = DetachedTimestampFile.fromHash(hash);

        // Add attestation to a nested timestamp
        final child = detached.timestamp.add(const OpSHA256());
        child.addAttestation(
            const PendingAttestation('https://nested.calendar'));

        await client.upgrade(detached);

        expect(requestCount, equals(1));

        client.close();
      });
    });

    group('close', () {
      test('can be called multiple times without error', () {
        final client = OpenTimestampsClient();

        client.close();
        client.close(); // Should not throw
      });
    });
  });
}
