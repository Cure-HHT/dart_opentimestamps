# OpenTimestamps for Dart

A pure Dart implementation of the [OpenTimestamps](https://opentimestamps.org/) protocol for creating and verifying Bitcoin blockchain-based timestamps.

[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue)](https://dart.dev/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen.svg)](https://cure-hht.github.io/dart_opentimestamps/)
[![codecov](https://codecov.io/gh/Cure-HHT/dart_opentimestamps/branch/main/graph/badge.svg)](https://codecov.io/gh/Cure-HHT/dart_opentimestamps)

## Features

- ✅ **Complete OTS file format support** - Serialize and deserialize `.ots` timestamp proofs
- ✅ **Cryptographic operations** - SHA-256, append, prepend operations
- ✅ **Calendar client** - Submit timestamps to public OpenTimestamps calendars
- ✅ **Bitcoin attestations** - Support for Bitcoin block header attestations  
- ✅ **Type-safe API** - Leverages Dart's strong typing for reliability
- ✅ **Pure Dart** - Works on all Dart platforms (Flutter, Web, Server, CLI)
- ✅ **100% Test Coverage** - Comprehensive test suite with round-trip verification

## Why OpenTimestamps?

OpenTimestamps provides **trustless** timestamping using the Bitcoin blockchain:

- **No trusted third party** - Unlike TSA (Time-Stamping Authority), you don't need to trust a certificate authority
- **Quantum-resistant** - Hash functions remain secure against quantum computers
- **Free** - Public calendar servers aggregate timestamps at no cost  
- **Permanent** - Proofs last as long as the Bitcoin blockchain exists
- **Verifiable** - Anyone can independently verify timestamps

Perfect for:
- Clinical trial data integrity
- Legal document timestamping
- Software release verification
- Audit trail compliance
- Digital evidence preservation


## How It Works

1. **Submit** - Hash sent to OpenTimestamps calendars
2. **Aggregate** - Calendars combine hashes into Merkle tree
3. **Commit** - Root hash embedded in Bitcoin transaction
4. **Confirm** - Bitcoin network confirms (~60 minutes)
5. **Verify** - Anyone independently verifies against blockchain
## Quick Start


## Configuration

### Calendar Servers

By default, the client uses these public OpenTimestamps calendar servers:
- https://a.pool.opentimestamps.org
- https://b.pool.opentimestamps.org
- https://a.pool.eternitywall.com

You can configure custom calendar servers in three ways:

**1. Constructor parameter (highest priority):**
```dart
final client = OpenTimestampsClient(
  calendarUrls: ["https://my-calendar.example.com"],
);
```

**2. Environment variable:**
```bash
# For Flutter apps
flutter run --dart-define=OPENTIMESTAMP_CALENDAR_URLS=https://cal1.example.com,https://cal2.example.com

# For Dart apps
dart run --define=OPENTIMESTAMP_CALENDAR_URLS=https://cal1.example.com,https://cal2.example.com
```

**3. Default calendars (fallback):**
If neither constructor parameter nor environment variable is set, the default public calendars are used.

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  open_timestamps: ^0.1.0
```

### Basic Usage

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:open_timestamps/open_timestamps.dart';

// Create a timestamp from your data
final message = 'Important document content';
final messageBytes = Uint8List.fromList(utf8.encode(message));
final detached = DetachedTimestampFile.fromBytes(messageBytes);

// Submit to calendar servers  
final client = OpenTimestampsClient();
await client.stamp(detached);

// Save the .ots proof file
final otsBytes = detached.serialize();
await File('document.txt.ots').writeAsBytes(otsBytes);

// Later, verify the timestamp
final otsFile = await File('document.txt.ots').readAsBytes();
final verified = DetachedTimestampFile.deserialize(otsFile);
print(verified.info());
```

### Reading OTS Files

```dart
// Load an existing .ots file
final otsBytes = await File('document.txt.ots').readAsBytes();
final timestamp = DetachedTimestampFile.deserialize(otsBytes);

// Display information
print('File hash: ${timestamp.fileHash.map((b) => b.toRadixString(16)).join()}');
print(timestamp.info());

// Check for attestations
final attestations = timestamp.timestamp.getAllAttestations();
for (final attestation in attestations) {
  if (attestation is BitcoinBlockHeaderAttestation) {
    print('Confirmed in Bitcoin block ${attestation.height}');
  } else if (attestation is PendingAttestation) {
    print('Pending at ${attestation.uri}');
  }
}
```

## API Overview

### Core Classes

- **`DetachedTimestampFile`** - Main entry point for creating and loading timestamps
- **`OpenTimestampsClient`** - Communicates with calendar servers
- **`Timestamp`** - Represents a proof tree with operations and attestations
- **`Operation`** - Cryptographic operations (SHA256, Append, Prepend)
- **`Attestation`** - Proof claims (Bitcoin blocks, pending calendars)

### Operations

Operations transform messages through the proof tree:

```dart
// Hash operations
final sha256 = const OpSHA256();
final hashed = sha256.apply(message);

// Binary operations  
final appended = OpAppend(Uint8List.fromList([0x00, 0x01]));
final prepended = OpPrepend(Uint8List.fromList([0xFF, 0xFE]));
```

### Attestations

Attestations prove when a timestamp existed:

```dart
// Pending attestation (waiting for Bitcoin confirmation)
final pending = PendingAttestation('https://alice.btc.calendar.opentimestamps.org');

// Bitcoin block attestation (confirmed)
final confirmed = BitcoinBlockHeaderAttestation(515107);
```

## Architecture

- **Binary format compatibility** - Interoperable with Python, JavaScript, and Java implementations
- **Merkle tree operations** - Efficient batching of multiple timestamps
- **Modular design** - Clean separation of operations, attestations, and calendar communication

## Testing

Run the test suite:

```bash
dart test
```

Tests include:
- Operation correctness (SHA-256, append, prepend)
- Serialization/deserialization round-trips
- Attestation handling
- Varint encoding/decoding
- Real OTS file compatibility

## Security Considerations

### Hash Function Security

- **SHA-256** - 128-bit quantum security (256-bit classical)
- **Resistant to Grover's algorithm** - Quadratic speedup doesn't break security
- **No custom crypto** - Uses battle-tested `package:crypto`

### Trust Model  

OpenTimestamps requires NO trust in:
- ❌ Calendar servers (they can't forge timestamps)
- ❌ Certificate authorities
- ❌ Timestamp authorities

You only trust:
- ✅ Mathematics (hash functions)
- ✅ Bitcoin blockchain consensus

### Recommended for Clinical Trials

Ideal for **clinical trial data** because:
- Regulatory compliant - Meets FDA 21 CFR Part 11 audit trail requirements
- Long-term integrity - Data provably existed before analysis
- Independent verification - Anyone can verify without special access
- Cost effective - Free compared to commercial TSA services

## Comparison: OpenTimestamps vs TSA

| Feature | OpenTimestamps | TSA (RFC 3161) |
|---------|----------------|----------------|
| Trust required | None (math only) | Certificate authority |
| Cost | Free | $10K-$1M/year enterprise |
| Quantum resistance | Yes (hash functions) | No (RSA/ECDSA broken) |
| Attack difficulty | $5-20B (51% Bitcoin attack) | $100K-$1M (CA compromise) |
| Verification | Anyone, forever | Requires CA trust chain |
| Implementation complexity | ~1000 lines | ~3000+ lines (ASN.1, X.509, CMS) |

For 20+ year clinical trial data retention, **OpenTimestamps is significantly more secure**.

## Contributing

Contributions welcome! This is a Cure-HHT project to support clinical trial data integrity.

### Development Setup

```bash
git clone https://github.com/Cure-HHT/dart_opentimestamps.git
cd dart_opentimestamps
dart pub get
dart test
```

### Roadmap

- [ ] Complete calendar response parsing
- [ ] Bitcoin block verification via block explorers
- [ ] Timestamp upgrade automation
- [ ] CLI tool for command-line usage
- [ ] Flutter example app
- [ ] Litecoin/Ethereum chain support

## License

Apache 2.0 - See [LICENSE](LICENSE) file.

## Credits

- Based on the [OpenTimestamps](https://opentimestamps.org/) protocol by Peter Todd
- Follows the [Java implementation](https://github.com/opentimestamps/java-opentimestamps) architecture
- Created for [Cure HHT](https://curehht.org/) clinical trial data integrity

## Links

- [OpenTimestamps Website](https://opentimestamps.org/)
- [Protocol Specification](https://github.com/opentimestamps/opentimestamps-server/blob/master/doc/merkle-mountain-range.md)
- [Python Reference Implementation](https://github.com/opentimestamps/python-opentimestamps)
- [Cure HHT](https://curehht.org/) - Hereditary Hemorrhagic Telangiectasia research


## Development

### Git Hooks

This project includes git hooks to maintain code quality:

- **pre-commit**: Formats code with `dart format` and runs `dart analyze`
- **pre-push**: Runs all tests before pushing

Install the hooks:

```bash
./hooks/install.sh
```

See [hooks/README.md](hooks/README.md) for more details.

### Running Tests

```bash
# Run all tests
./tool/test.sh

# Run with custom concurrency
./tool/test.sh --concurrency 4
```

### Coverage

This project maintains **100% test coverage**. View the latest coverage report:
- **[Coverage Report](https://cure-hht.github.io/dart_opentimestamps/)** - Detailed line-by-line coverage
- **[Codecov Dashboard](https://codecov.io/gh/Cure-HHT/dart_opentimestamps)** - Coverage trends and analytics

To generate a local coverage report:

```bash
# Generate coverage report
./tool/coverage.sh

# View report
open coverage/html/index.html
```

## Contact

For questions or contributions, contact [mike.bushe@anspar.org](mailto:mike.bushe@anspar.org)
