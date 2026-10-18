import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// What a calendar answers for [commitment]: a path to its pending
/// attestation, as public calendars return it.
Uint8List calendarResponse(Uint8List commitment, String uri) {
  final t = Timestamp(commitment);
  t
      .add(OpPrepend(Uint8List.fromList([0x57, 0xcf, 0xa5, 0xc4])))
      .add(OpAppend(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])))
      .attestations
      .add(PendingAttestation(uri));
  return t.toBytes();
}

void main() {
  final digest = digestOf(0xab);

  group('stamp', () {
    late List<http.Request> requests;

    OpenTimestampsClient clientWith(
      Future<http.Response> Function(http.Request) handler, {
      int minimumCalendars = 2,
    }) {
      requests = [];
      return OpenTimestampsClient(
        httpClient: MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
        minimumCalendars: minimumCalendars,
        random: Random(1),
        timeout: const Duration(milliseconds: 200),
      );
    }

    Future<http.Response> ok(http.Request r) async => http.Response.bytes(
          calendarResponse(r.bodyBytes, 'https://${r.url.host}'),
          200,
        );

    test('submits a nonced commitment to every calendar and merges replies',
        () async {
      final proof = await clientWith(ok).stamp(digest);

      expect(requests, hasLength(3));
      expect(requests.map((r) => r.url.toString()), [
        for (final c in OpenTimestampsClient.defaultCalendars) '$c/digest',
      ]);
      for (final r in requests) {
        expect(r.method, 'POST');
        expect(r.headers['Accept'], 'application/vnd.opentimestamps.v1');
        expect(r.bodyBytes, hasLength(32));
      }
      // All calendars received the same commitment.
      expect(requests.map((r) => r.bodyBytes.toString()).toSet(), hasLength(1));

      final nonceOp = proof.timestamp.ops.keys.single as OpAppend;
      expect(nonceOp.argument, hasLength(16));
      expect(
        requests.first.bodyBytes,
        sha256.convert([...digest, ...nonceOp.argument]).bytes,
      );
      expect(proof.digest, digest);
      expect(proof.pendingCalendars, {
        'https://a.pool.opentimestamps.org',
        'https://b.pool.opentimestamps.org',
        'https://a.pool.eternitywall.com',
      });

      final reparsed = DetachedTimestampFile.deserialize(proof.serialize());
      expect(reparsed.serialize(), proof.serialize());
    });

    test('the nonce hides the digest: two stamps submit different values',
        () async {
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          requests.add(r);
          return ok(r);
        }),
      );
      requests = [];
      await client.stamp(digest);
      await client.stamp(digest);
      expect(requests.first.bodyBytes, isNot(requests.last.bodyBytes));
      expect(requests.first.bodyBytes, isNot(digest));
    });

    test('succeeds when the minimum number of calendars answer', () async {
      final proof = await clientWith((r) => r.url.host.startsWith('b.')
          ? Future.value(http.Response('down', 503))
          : ok(r)).stamp(digest);
      expect(proof.pendingCalendars, hasLength(2));
    });

    test('fails when fewer than the minimum answer', () async {
      final client = clientWith((r) => r.url.host.startsWith('a.pool.o')
          ? ok(r)
          : Future.value(http.Response('down', 503)));
      await expectLater(
        client.stamp(digest),
        throwsA(isA<CalendarException>()
            .having((e) => e.message, 'message', contains('1 of 3'))),
      );
    });

    test('malformed replies, network errors and timeouts count as failures',
        () async {
      final client = clientWith((r) {
        if (r.url.host.startsWith('a.pool.o')) {
          return Future.value(http.Response.bytes([0xff], 200));
        }
        if (r.url.host.startsWith('b.')) {
          throw http.ClientException('connection refused');
        }
        return Completer<http.Response>().future; // never answers
      }, minimumCalendars: 1);
      await expectLater(
          client.stamp(digest), throwsA(isA<CalendarException>()));
    });

    test('a captured-shape reply is merged at the nonced commitment', () async {
      const alice = 'https://alice.btc.calendar.opentimestamps.org';
      final aggregatorNonce = List.generate(16, (i) => 0xa0 + i);
      final time = [0x65, 0x2f, 0x1a, 0x00];
      final calendarNonce = [1, 2, 3, 4, 5, 6, 7, 8];
      // Written out byte by byte, as a.pool.opentimestamps.org answers:
      // append(nonce) sha256 prepend(time) append(nonce) pending(alice).
      final reply = Uint8List.fromList([
        0xf0, 0x10, ...aggregatorNonce, //
        0x08,
        0xf1, 0x04, ...time,
        0xf0, 0x08, ...calendarNonce,
        0x00, ...PendingAttestation.tagBytes,
        alice.length + 1, alice.length, ...alice.codeUnits,
      ]);
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response.bytes(reply, 200);
        }),
        calendars: const ['https://a.pool.opentimestamps.org'],
        minimumCalendars: 1,
      );
      requests = [];
      final proof = await client.stamp(digest);

      final nonceOp = proof.timestamp.ops.keys.single as OpAppend;
      final commitment = proof.timestamp.ops[nonceOp]!.ops[const OpSHA256()]!;
      expect(commitment.msg, requests.single.bodyBytes);
      final pendingNode = commitment
          .ops[OpAppend(Uint8List.fromList(aggregatorNonce))]!
          .ops[const OpSHA256()]!
          .ops[OpPrepend(Uint8List.fromList(time))]!
          .ops[OpAppend(Uint8List.fromList(calendarNonce))]!;
      expect(pendingNode.attestations, {PendingAttestation(alice)});
      expect(
        pendingNode.msg,
        [
          ...time,
          ...sha256.convert([...commitment.msg, ...aggregatorNonce]).bytes,
          ...calendarNonce,
        ],
      );
      // The reply sits verbatim behind the file header and nonce step.
      expect(
        proof.serialize(),
        [
          ...hexDecode('004f70656e54696d657374616d7073000050726f6f6600bf89e2e8'
              '84e89294'),
          0x01, 0x08, ...digest, //
          0xf0, 0x10, ...nonceOp.argument,
          0x08, ...reply,
        ],
      );
    });

    test('a reply with no pending or Bitcoin attestation is not counted',
        () async {
      final unknownOnly = hexDecode('00' '0102030405060708' '00');
      final client = clientWith(
        (r) async => r.url.host.startsWith('a.pool.o')
            ? http.Response.bytes(unknownOnly, 200)
            : http.Response('down', 503),
        minimumCalendars: 1,
      );
      await expectLater(
        client.stamp(digest),
        throwsA(isA<CalendarException>().having(
            (e) => e.message, 'message', contains('no pending or Bitcoin'))),
      );
    });

    test('does not follow a redirect; a 3xx reply is a failure', () async {
      final follows = <bool>[];
      final client = clientWith((r) async {
        follows.add(r.followRedirects);
        return http.Response('', 302,
            headers: {'location': 'http://evil.example.com/digest'});
      }, minimumCalendars: 1);
      await expectLater(
          client.stamp(digest), throwsA(isA<CalendarException>()));
      expect(follows, [false, false, false]);
    });

    test('an oversized or stalled reply is cut off and its download cancelled',
        () async {
      var cancelled = 0;
      final client = OpenTimestampsClient(
        httpClient: MockClient.streaming((r, _) async {
          final controller = StreamController<List<int>>(
            onCancel: () => cancelled++,
          );
          if (r.url.host == 'a.pool.opentimestamps.org') {
            // Endless body: far past the response bound.
            Timer.periodic(const Duration(milliseconds: 1), (t) {
              if (controller.isClosed || cancelled > 0 && t.tick > 50) {
                t.cancel();
                return;
              }
              if (controller.hasListener) controller.add(Uint8List(4096));
            });
          } else {
            // Starts, then never finishes.
            controller.add([0x00]);
          }
          return http.StreamedResponse(controller.stream, 200);
        }),
        minimumCalendars: 1,
        random: Random(1),
        timeout: const Duration(milliseconds: 200),
      );
      await expectLater(
          client.stamp(digest), throwsA(isA<CalendarException>()));
      expect(cancelled, 3);
    });

    test('a reply deeper than the depth left below the commitment is refused',
        () async {
      // The commitment is the root's grandchild, so a reply may add at
      // most 253 ops before the proof would exceed 256 nested nodes.
      Uint8List chain(int ops) => Uint8List.fromList([
            ...List.filled(ops, 0x08),
            ...hexDecode('00${'83dfe30d2ef90c8e'}'),
            ...(() {
              final uri = 'https://a.pool.opentimestamps.org'.codeUnits;
              return [uri.length + 1, uri.length, ...uri];
            })(),
          ]);

      OpenTimestampsClient replying(int ops) => OpenTimestampsClient(
            httpClient: MockClient((_) async => http.Response.bytes(
                  chain(ops),
                  200,
                )),
            calendars: const ['https://a.pool.opentimestamps.org'],
            minimumCalendars: 1,
            random: Random(1),
          );

      final proof = await replying(253).stamp(digest);
      expect(
        DetachedTimestampFile.deserialize(proof.serialize()).serialize(),
        proof.serialize(),
      );
      await expectLater(
          replying(254).stamp(digest), throwsA(isA<CalendarException>()));
    });

    test('rejects a digest that is not 32 bytes', () {
      expect(() => clientWith(ok).stamp(Uint8List(31)), throwsArgumentError);
    });

    test('rejects an unsatisfiable minimum', () {
      expect(
          () => OpenTimestampsClient(minimumCalendars: 4), throwsArgumentError);
      expect(
          () => OpenTimestampsClient(minimumCalendars: 0), throwsArgumentError);
    });
  });

  group('upgrade', () {
    const calendar = 'https://alice.btc.calendar.opentimestamps.org';

    test('asks the calendar for the pending commitment; 404 stays pending',
        () async {
      final proof =
          DetachedTimestampFile.deserialize(fixture('incomplete.txt.ots'));
      final before = proof.serialize();
      final urls = <Uri>[];
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          urls.add(r.url);
          expect(r.method, 'GET');
          expect(r.headers['Accept'], 'application/vnd.opentimestamps.v1');
          return http.Response('Not found', 404);
        }),
      );
      expect(await client.upgrade(proof), isFalse);
      final pendingMsg = proof.timestamp
          .nodes()
          .firstWhere((n) => n.attestations.isNotEmpty)
          .msg;
      expect(urls.single.toString(),
          '$calendar/timestamp/${hexEncode(pendingMsg)}');
      expect(proof.serialize(), before);
    });

    test('merges a Bitcoin proof and drops the pending attestation', () async {
      final proof =
          DetachedTimestampFile.deserialize(fixture('incomplete.txt.ots'));
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          final msg = hexDecode(r.url.pathSegments.last);
          final t = Timestamp(msg);
          t.add(const OpSHA256()).attestations.add(
                const BitcoinBlockHeaderAttestation(800000),
              );
          return http.Response.bytes(t.toBytes(), 200);
        }),
      );
      expect(await client.upgrade(proof), isTrue);
      expect(proof.isComplete, isTrue);
      expect(proof.bitcoinHeights, {800000});
      expect(proof.pendingCalendars, isEmpty);
      expect(DetachedTimestampFile.deserialize(proof.serialize()).serialize(),
          proof.serialize());

      // Complete proofs have nothing left to ask.
      expect(await client.upgrade(proof), isFalse);
    });

    test('a real Bitcoin path from the calendar verifies after upgrade',
        () async {
      final complete = fixture('hello-world-bitcoin-path.ots');
      final head = DetachedTimestampFile.deserialize(complete).digest;
      final proof = DetachedTimestampFile(head);
      proof.timestamp.attestations.add(PendingAttestation(calendar));
      final urls = <Uri>[];
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          urls.add(r.url);
          // What the calendar serves: the tree below the commitment.
          return http.Response.bytes(complete.sublist(65), 200);
        }),
      );

      expect(await client.upgrade(proof), isTrue);
      expect(urls.single.toString(), '$calendar/timestamp/${hexEncode(head)}');
      expect(proof.pendingCalendars, isEmpty);
      expect(proof.serialize(), complete);
      expect(
        verifyTimestamp(proof.serialize(), head, {358391: block358391Header()}),
        isA<VerificationValid>().having((r) => r.height, 'height', 358391),
      );
    });

    test('a pending attestation already anchored below is dropped unasked',
        () async {
      final proof = DetachedTimestampFile.deserialize(
          fixture('hello-world-bitcoin-path.ots'));
      proof.timestamp.attestations.add(PendingAttestation(calendar));
      var calls = 0;
      final client = OpenTimestampsClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('', 404);
        }),
      );
      expect(await client.upgrade(proof), isTrue);
      expect(calls, 0);
      expect(proof.pendingCalendars, isEmpty);
    });

    test('a reply without a Bitcoin attestation keeps the pending one',
        () async {
      final proof =
          DetachedTimestampFile.deserialize(fixture('incomplete.txt.ots'));
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          final t = Timestamp(hexDecode(r.url.pathSegments.last));
          t
              .add(const OpSHA256())
              .attestations
              .add(PendingAttestation(calendar));
          return http.Response.bytes(t.toBytes(), 200);
        }),
      );
      expect(await client.upgrade(proof), isTrue);
      expect(proof.isComplete, isFalse);
      expect(proof.pendingCalendars, {calendar});
    });

    test('network errors and malformed replies leave the proof unchanged',
        () async {
      for (final handler in <MockClientHandler>[
        (_) => throw http.ClientException('offline'),
        (_) async => http.Response.bytes([1, 2, 3], 200),
      ]) {
        final proof =
            DetachedTimestampFile.deserialize(fixture('two-calendars.txt.ots'));
        final before = proof.serialize();
        final client = OpenTimestampsClient(httpClient: MockClient(handler));
        expect(await client.upgrade(proof), isFalse);
        expect(proof.serialize(), before);
      }
    });

    test('an upgrade deeper than the depth left below the node is refused',
        () async {
      final proof = DetachedTimestampFile(digest);
      final node = proof.timestamp.add(const OpSHA256());
      node.attestations.add(PendingAttestation(calendar));
      final before = proof.serialize();
      // The pending node is the root's child: a reply may add at most 254
      // ops; this one adds 255.
      final reply = Uint8List.fromList(
          [...List.filled(255, 0x08), ...hexDecode('000588960d73d719010101')]);
      final follows = <bool>[];
      final client = OpenTimestampsClient(
        httpClient: MockClient((r) async {
          follows.add(r.followRedirects);
          return http.Response.bytes(reply, 200);
        }),
      );
      expect(await client.upgrade(proof), isFalse);
      expect(follows, [false]);
      expect(proof.serialize(), before);
    });

    test('never contacts a calendar outside upgradeHosts', () async {
      final proof = DetachedTimestampFile(digest);
      proof.timestamp.add(const OpSHA256()).attestations.addAll([
        PendingAttestation('https://evil.example.com'),
        PendingAttestation('http://alice.btc.calendar.opentimestamps.org'),
        PendingAttestation('https://calendar.opentimestamps.org.evil.com'),
      ]);
      var calls = 0;
      final client = OpenTimestampsClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('', 404);
        }),
      );
      expect(await client.upgrade(proof), isFalse);
      expect(calls, 0);
    });
  });
}
