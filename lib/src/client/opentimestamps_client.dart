/// OpenTimestamps client for calendar operations
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/attestation.dart';
import '../core/operations.dart';
import '../core/timestamp.dart';
import '../detached_timestamp_file.dart';
import '../utils/exceptions.dart';

/// Client for interacting with OpenTimestamps calendar servers
class OpenTimestampsClient {
  /// Creates an OpenTimestamps client
  OpenTimestampsClient({
    List<String>? calendarUrls,
    http.Client? httpClient,
  })  : calendarUrls = calendarUrls ??
            [
              'https://alice.btc.calendar.opentimestamps.org',
              'https://bob.btc.calendar.opentimestamps.org',
              'https://finney.calendar.eternitywall.com',
            ],
        _httpClient = httpClient ?? http.Client();

  /// Calendar server URLs
  final List<String> calendarUrls;

  /// HTTP client
  final http.Client _httpClient;

  /// Random number generator for nonces
  final _random = Random.secure();

  /// Stamps a file by submitting it to calendar servers
  ///
  /// Returns the detached timestamp file with pending attestations.
  /// The timestamp will need to be upgraded later once the calendars
  /// have included it in a Bitcoin block.
  Future<DetachedTimestampFile> stamp(DetachedTimestampFile detached) async {
    // Add a random nonce for privacy
    final nonce = Uint8List(16);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }

    final nonceAppended = detached.timestamp.add(OpAppend(nonce));
    final merkleRoot = nonceAppended.add(const OpSHA256());

    // Submit to all calendars
    final results = await Future.wait(
      calendarUrls.map((url) => _submitToCalendar(url, merkleRoot.msg)),
      eagerError: false,
    );

    // Process results
    var successCount = 0;
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result != null) {
        successCount++;
        _processCalendarResponse(merkleRoot, calendarUrls[i], result);
      }
    }

    if (successCount == 0) {
      throw const OpenTimestampsException(
        'Failed to submit to any calendar servers',
      );
    }

    return detached;
  }

  /// Submits a hash to a calendar server
  Future<Uint8List?> _submitToCalendar(
      String calendarUrl, Uint8List hash) async {
    try {
      final url = Uri.parse('$calendarUrl/digest');
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Accept': 'application/octet-stream',
            },
            body: hash,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('Submitting to remote calendar $calendarUrl');
        return response.bodyBytes;
      } else {
        print('Calendar $calendarUrl returned status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Failed to submit to calendar $calendarUrl: $e');
      return null;
    }
  }

  /// Processes the response from a calendar server
  void _processCalendarResponse(
    Timestamp timestamp,
    String calendarUrl,
    Uint8List response,
  ) {
    // The response contains operations to apply to our hash
    // to reach the calendar's merkle tree root, followed by
    // a pending attestation

    // For now, we'll create a simple pending attestation
    // A full implementation would parse the response and build the operation tree
    timestamp.addAttestation(PendingAttestation(calendarUrl));
  }

  /// Upgrades a timestamp by checking calendar servers for Bitcoin attestations
  ///
  /// Returns true if the timestamp was upgraded (new attestations added).
  Future<bool> upgrade(DetachedTimestampFile detached) async {
    var upgraded = false;

    // Find all pending attestations
    final pendingAttestations = _findPendingAttestations(detached.timestamp);

    for (final pending in pendingAttestations) {
      try {
        final wasUpgraded = await _upgradeAttestation(pending);
        if (wasUpgraded) {
          upgraded = true;
        }
      } catch (e) {
        // Continue with other attestations even if one fails
        print('Failed to upgrade attestation ${pending.attestation.uri}: $e');
      }
    }

    return upgraded;
  }

  /// Finds all pending attestations in a timestamp tree
  List<_TimestampAttestation> _findPendingAttestations(Timestamp timestamp) {
    final pending = <_TimestampAttestation>[];

    for (final attestation in timestamp.attestations) {
      if (attestation is PendingAttestation) {
        pending.add(_TimestampAttestation(timestamp, attestation));
      }
    }

    for (final childTimestamp in timestamp.ops.values) {
      pending.addAll(_findPendingAttestations(childTimestamp));
    }

    return pending;
  }

  /// Upgrades a single pending attestation
  Future<bool> _upgradeAttestation(_TimestampAttestation pending) async {
    final url = Uri.parse(
        '${pending.attestation.uri}/timestamp/${_toHex(pending.timestamp.msg)}');

    try {
      final response =
          await _httpClient.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Parse the response and add new operations/attestations
        // This would require parsing the calendar's merkle tree response
        // For now, we'll return false (not yet upgraded)
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Closes the HTTP client
  void close() {
    _httpClient.close();
  }
}

/// Internal class to track a timestamp and its attestation
class _TimestampAttestation {
  _TimestampAttestation(this.timestamp, this.attestation);

  final Timestamp timestamp;
  final PendingAttestation attestation;
}
