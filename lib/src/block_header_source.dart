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

/// Where Bitcoin block headers for verification come from.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'bounded_http.dart';
import 'codec.dart';
import 'verify.dart';

/// Explorer replies are a block hash or an 80-byte header in hex.
const _maxResponseLength = 1000;

/// Thrown when a block header cannot be obtained or sources disagree.
class BlockHeaderException implements Exception {
  /// Creates the exception.
  const BlockHeaderException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'BlockHeaderException: $message';
}

/// Supplies the 80-byte header of a Bitcoin block by height.
abstract interface class BlockHeaderSource {
  /// The header of the block at [height]; throws [BlockHeaderException].
  Future<Uint8List> headerAt(int height);
}

/// Fetches headers from independent Esplora-API explorers and accepts one
/// only if every explorer returns the same header, whose hash matches the
/// block hash they report. No single explorer is trusted.
///
/// Intended to be called once per completed proof; store the header with
/// the proof so it verifies offline from then on.
class ExplorerBlockHeaderSource implements BlockHeaderSource {
  /// Creates a source over [explorers] (Esplora API base URLs).
  ExplorerBlockHeaderSource({
    http.Client? httpClient,
    this.explorers = defaultExplorers,
    this.timeout = const Duration(seconds: 10),
  })  : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null {
    final hosts = {
      for (final e in explorers) Uri.parse(e).host.toLowerCase(),
    };
    if (hosts.length < 2) {
      throw ArgumentError.value(
        explorers,
        'explorers',
        'need at least two distinct hosts',
      );
    }
  }

  /// Two explorers run by unrelated operators.
  static const defaultExplorers = [
    'https://blockstream.info/api',
    'https://mempool.space/api',
  ];

  /// Explorer API base URLs.
  final List<String> explorers;

  /// Per-request timeout.
  final Duration timeout;

  final http.Client _http;
  final bool _ownsHttp;

  @override
  Future<Uint8List> headerAt(int height) async {
    final headers = await Future.wait(explorers.map((e) => _fetch(e, height)));
    for (final h in headers.skip(1)) {
      if (!bytesEqual(h, headers.first)) {
        throw BlockHeaderException('Explorers disagree on block $height');
      }
    }
    return headers.first;
  }

  Future<Uint8List> _fetch(String explorer, int height) async {
    try {
      final hash = (await _get('$explorer/block-height/$height')).trim();
      final header =
          hexDecode((await _get('$explorer/block/$hash/header')).trim());
      if (header.length != 80) throw const FormatException('not 80 bytes');
      final computed = hexEncode(blockHash(header).reversed.toList());
      if (computed != hash.toLowerCase()) {
        throw const FormatException('header does not hash to block hash');
      }
      return header;
    } on BlockHeaderException {
      rethrow;
    } on Object catch (e) {
      throw BlockHeaderException('$explorer, block $height: $e');
    }
  }

  Future<String> _get(String url) async {
    final response = await sendBounded(
      _http,
      http.Request('GET', Uri.parse(url)),
      maxBytes: _maxResponseLength,
      timeout: timeout,
    );
    if (response.statusCode != 200) {
      throw BlockHeaderException('$url: HTTP ${response.statusCode}');
    }
    return utf8.decode(response.body);
  }

  /// Closes the HTTP client if this source created it.
  void close() {
    if (_ownsHttp) _http.close();
  }
}
