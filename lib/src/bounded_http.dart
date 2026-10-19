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

/// HTTP requests to untrusted servers: no redirects, bounded bodies.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A response whose body was read within a size bound.
class BoundedResponse {
  /// Creates the response.
  const BoundedResponse(this.statusCode, this.body);

  /// The HTTP status code. A redirect is returned as its 3xx code, never
  /// followed.
  final int statusCode;

  /// The response body.
  final Uint8List body;
}

/// Sends [request] without following redirects and reads at most
/// [maxBytes] of its body.
///
/// The whole exchange, body included, must finish within [timeout]. On a
/// timeout or an oversized body the download is cancelled and the future
/// fails, so a server cannot make the caller buffer an unbounded body or
/// keep a request open past its deadline.
Future<BoundedResponse> sendBounded(
  http.Client client,
  http.BaseRequest request, {
  required int maxBytes,
  required Duration timeout,
}) {
  request.followRedirects = false;
  final completer = Completer<BoundedResponse>();
  StreamSubscription<List<int>>? subscription;

  void fail(Object error) {
    subscription?.cancel();
    if (!completer.isCompleted) completer.completeError(error);
  }

  final timer = Timer(
    timeout,
    () => fail(TimeoutException('Request timed out', timeout)),
  );

  client.send(request).then((response) {
    if (completer.isCompleted) {
      response.stream.listen(null).cancel();
      return;
    }
    final bytes = BytesBuilder(copy: false);
    subscription = response.stream.listen(
      (chunk) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) {
          fail(FormatException('Response exceeds $maxBytes bytes'));
        }
      },
      onError: fail,
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(
            BoundedResponse(response.statusCode, bytes.takeBytes()),
          );
        }
      },
      cancelOnError: true,
    );
  }, onError: fail);

  return completer.future.whenComplete(timer.cancel);
}
