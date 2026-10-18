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

/// Verifies an `.ots` proof offline against supplied block headers.
///
///     dart run dart_opentimestamps:ots_verify <proof.ots> <digest-hex> \
///         <height>=<header-hex>...
///
/// Exit status: 0 valid, 1 invalid, 2 pending, 64 usage error.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'usage: ots_verify <proof.ots> <digest-hex> <height>=<header-hex>...',
    );
    exit(64);
  }
  final Uint8List proof;
  final Uint8List digest;
  final headers = <int, Uint8List>{};
  try {
    proof = File(args[0]).readAsBytesSync();
    digest = hexDecode(args[1]);
    for (final arg in args.skip(2)) {
      final eq = arg.indexOf('=');
      if (eq < 0) throw FormatException('expected <height>=<header-hex>', arg);
      headers[int.parse(arg.substring(0, eq))] =
          hexDecode(arg.substring(eq + 1));
    }
  } on Exception catch (e) {
    stderr.writeln(e);
    exit(64);
  }
  final result = verifyTimestamp(proof, digest, headers);
  stdout.writeln(result);
  exit(switch (result) {
    VerificationValid() => 0,
    VerificationInvalid() => 1,
    VerificationPending() => 2,
  });
}
