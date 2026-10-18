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

/// Talks to OpenTimestamps calendars: submit a digest, fetch upgrades.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'attestation.dart';
import 'codec.dart';
import 'detached_timestamp_file.dart';
import 'op.dart';
import 'timestamp.dart';

const _accept = {'Accept': 'application/vnd.opentimestamps.v1'};
const _maxResponseLength = 10000;

/// Thrown when too few calendars accepted a submission.
class CalendarException implements Exception {
  /// Creates the exception.
  const CalendarException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'CalendarException: $message';
}

/// A client for public OpenTimestamps calendars.
///
/// The client never retries and never polls; callers decide when to call
/// [stamp] and [upgrade], so they control how often calendars are hit.
class OpenTimestampsClient {
  /// Creates a client.
  ///
  /// [minimumCalendars] of the [calendars] must accept a submission for
  /// [stamp] to succeed. [upgradeHosts] lists the host suffixes [upgrade]
  /// will contact; a proof naming any other calendar is not followed, so
  /// a crafted proof cannot make the client fetch arbitrary URLs.
  OpenTimestampsClient({
    http.Client? httpClient,
    this.calendars = defaultCalendars,
    this.minimumCalendars = 2,
    this.upgradeHosts = defaultUpgradeHosts,
    this.timeout = const Duration(seconds: 10),
    Random? random,
  })  : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null,
        _random = random ?? Random.secure() {
    if (minimumCalendars < 1 || minimumCalendars > calendars.length) {
      throw ArgumentError.value(minimumCalendars, 'minimumCalendars');
    }
  }

  /// Public aggregation calendars run by independent operators.
  static const defaultCalendars = [
    'https://a.pool.opentimestamps.org',
    'https://b.pool.opentimestamps.org',
    'https://a.pool.eternitywall.com',
  ];

  /// Host suffixes of the calendars the default pools hand proofs to.
  static const defaultUpgradeHosts = [
    'calendar.opentimestamps.org',
    'calendar.eternitywall.com',
    'calendar.catallaxy.com',
  ];

  /// Calendar base URLs submissions go to.
  final List<String> calendars;

  /// How many calendars must accept a submission.
  final int minimumCalendars;

  /// Host suffixes [upgrade] may contact (over HTTPS only).
  final List<String> upgradeHosts;

  /// Per-request timeout.
  final Duration timeout;

  final http.Client _http;
  final bool _ownsHttp;
  final Random _random;

  /// Submits [digest] (32 bytes) to every calendar in parallel and returns
  /// a proof holding each answering calendar's pending attestation.
  ///
  /// A random nonce is appended before submission so calendars learn
  /// nothing about [digest]. Throws [CalendarException] if fewer than
  /// [minimumCalendars] answered.
  Future<DetachedTimestampFile> stamp(Uint8List digest) async {
    final proof = DetachedTimestampFile(digest);
    final nonce = Uint8List.fromList(
      List.generate(16, (_) => _random.nextInt(256)),
    );
    final commitment = proof.timestamp.add(OpAppend(nonce)).add(
          const OpSHA256(),
        );

    final responses = await Future.wait(
      calendars.map((url) => _submit(url, commitment.msg)),
    );
    final failures = <String>[];
    for (var i = 0; i < calendars.length; i++) {
      final response = responses[i];
      if (response is Timestamp) {
        commitment.merge(response);
      } else {
        failures.add('${calendars[i]}: $response');
      }
    }
    final accepted = calendars.length - failures.length;
    if (accepted < minimumCalendars) {
      throw CalendarException(
        '$accepted of ${calendars.length} calendars accepted the digest '
        '(need $minimumCalendars): ${failures.join('; ')}',
      );
    }
    return proof;
  }

  /// Returns the parsed [Timestamp] or a failure description.
  Future<Object> _submit(String calendar, Uint8List msg) async {
    try {
      final response = await _http
          .post(Uri.parse('$calendar/digest'), headers: _accept, body: msg)
          .timeout(timeout);
      if (response.statusCode != 200) return 'HTTP ${response.statusCode}';
      final timestamp = _parse(response.bodyBytes, msg);
      // A reply that can never lead to Bitcoin is not an acceptance.
      if (!timestamp.allAttestations().any((e) =>
          e.$2 is PendingAttestation ||
          e.$2 is BitcoinBlockHeaderAttestation)) {
        return 'no pending or Bitcoin attestation in reply';
      }
      return timestamp;
    } on Object catch (e) {
      return e.toString();
    }
  }

  /// Asks each pending calendar in [proof] for its Bitcoin proof and
  /// merges what it returns. Returns whether [proof] changed.
  ///
  /// A calendar that has not committed yet (HTTP 404), cannot be reached,
  /// or is not in [upgradeHosts] is left pending. Once a Bitcoin
  /// attestation sits beneath a pending one, the pending one is dropped.
  Future<bool> upgrade(DetachedTimestampFile proof) async {
    var changed = false;
    final pending = [
      for (final node in proof.timestamp.nodes())
        for (final a in node.attestations)
          if (a is PendingAttestation) (node, a),
    ];
    for (final (node, attestation) in pending) {
      // Already anchored beneath this node: nothing to ask the calendar.
      if (_hasBitcoinBelow(node)) {
        changed |= node.attestations.remove(attestation);
        continue;
      }
      final uri = Uri.tryParse(attestation.uri);
      if (uri == null || !_mayUpgradeFrom(uri)) continue;
      final upgraded = await _fetch(uri, node.msg);
      if (upgraded == null) continue;
      final before = node.toBytes();
      node.merge(upgraded);
      if (_hasBitcoinBelow(node)) node.attestations.remove(attestation);
      changed |= !bytesEqual(before, node.toBytes());
    }
    return changed;
  }

  bool _mayUpgradeFrom(Uri uri) =>
      uri.scheme == 'https' &&
      upgradeHosts.any((h) => uri.host == h || uri.host.endsWith('.$h'));

  Future<Timestamp?> _fetch(Uri calendar, Uint8List msg) async {
    try {
      final response = await _http
          .get(
            calendar.replace(
              path: '${calendar.path}/timestamp/${hexEncode(msg)}',
            ),
            headers: _accept,
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return _parse(response.bodyBytes, msg);
    } on Object {
      return null;
    }
  }

  Timestamp _parse(Uint8List body, Uint8List msg) {
    if (body.length > _maxResponseLength) {
      throw const FormatException('Calendar response too large');
    }
    return Timestamp.fromBytes(body, msg);
  }

  static bool _hasBitcoinBelow(Timestamp node) => node.ops.values.any(
        (child) => child
            .allAttestations()
            .any((e) => e.$2 is BitcoinBlockHeaderAttestation),
      );

  /// Closes the HTTP client if this client created it.
  void close() {
    if (_ownsHttp) _http.close();
  }
}
