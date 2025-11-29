# OpenTimestamps for Dart

A pure Dart implementation of the [OpenTimestamps](https://opentimestamps.org/) protocol for creating and verifying Bitcoin blockchain-based timestamps.

[![pub package](https://img.shields.io/pub/v/open_timestamps.svg)](https://pub.dev/packages/open_timestamps)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## What is OpenTimestamps?

OpenTimestamps proves data existed at a specific point in time using the Bitcoin blockchain. 
Unlike traditional timestamping authorities (TSAs), OpenTimestamps provides:

- **$5-20B attack cost** vs ~$100K for traditional TSAs
- **Zero cost** - Free calendar servers aggregate timestamps  
- **Mathematically impossible backdating** - Protected by Bitcoin's proof-of-work
- **No single point of failure** - Distributed verification

## Features

- 📝 **Create timestamps** - Submit data hashes to OpenTimestamps calendar servers
- ✅ **Verify timestamps** - Verify `.ots` proof files against Bitcoin blockchain
- 🔄 **Upgrade proofs** - Upgrade pending proofs to complete Bitcoin-attested proofs
- 🔗 **Bitcoin verification** - Verify timestamps anchored in Bitcoin blocks
- 🚀 **Pure Dart** - Works on all Dart platforms (Flutter, Web, CLI, Server)

## Installation

```yaml
dependencies:
  open_timestamps: ^0.1.0
```

## Quick Start

### Create a Timestamp

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:open_timestamps/open_timestamps.dart';

void main() async {
  final data = File('document.pdf').readAsBytesSync();
  final hash = sha256.convert(data).bytes;
  
  final client = OpenTimestampsClient();
  final proof = await client.stamp(Uint8List.fromList(hash));
  
  File('document.pdf.ots').writeAsBytesSync(proof);
  print('Timestamp created! (~60 min for Bitcoin confirmation)');
}
```

### Verify a Timestamp

```dart
void main() async {
  final data = File('document.pdf').readAsBytesSync();
  final hash = sha256.convert(data).bytes;
  final proof = File('document.pdf.ots').readAsBytesSync();
  
  final client = OpenTimestampsClient();
  final result = await client.verify(Uint8List.fromList(hash), proof);
  
  if (result.isValid) {
    print('✓ Valid timestamp from ${result.attestedTime}');
    print('  Bitcoin block: ${result.bitcoinBlockHeight}');
  }
}
```

## Use Cases

- **Clinical Trial Compliance** - FDA 21 CFR Part 11 audit trails
- **Software Release Verification** - Prove when builds were created
- **IP Protection** - Establish proof of creation for patents/designs
- **Audit Logs** - Tamper-evident compliance records

## How It Works

1. **Submit** - Hash sent to OpenTimestamps calendars
2. **Aggregate** - Calendars combine hashes into Merkle tree
3. **Commit** - Root hash embedded in Bitcoin transaction
4. **Confirm** - Bitcoin network confirms (~60 minutes)
5. **Verify** - Anyone independently verifies against blockchain

## Contributing

Contributions welcome!

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0 - See [LICENSE](LICENSE)

## Credits

Based on [OpenTimestamps](https://opentimestamps.org/) specification.  
Maintained by [The Cure HHT Foundation](https://curehht.org/).
