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

/// Get a SHA-256 hash-chain head witnessed by Bitcoin via OpenTimestamps:
/// stamp the 32-byte digest, upgrade the proof once a calendar has
/// committed it to a block, and verify the stored proof offline.
library dart_opentimestamps;

export 'src/attestation.dart';
export 'src/block_header_source.dart';
export 'src/client.dart';
export 'src/codec.dart' show hexDecode, hexEncode;
export 'src/detached_timestamp_file.dart';
export 'src/op.dart';
export 'src/timestamp.dart';
export 'src/verify.dart';
