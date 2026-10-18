# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0] - 2026-10-18

Narrowed to one job: getting a SHA-256 hash-chain head witnessed by
Bitcoin, upgrading the proof, and verifying it offline. Breaking.

### Fixed
- `.ots` files now follow the real OpenTimestamps format (digest without a
  length prefix, `0xff`-prefixed branches, canonical ordering, attestation
  payloads as varbytes), so proofs round-trip byte-identically with the
  reference implementation's vectors and are readable by other tools.
- `stamp` now parses and merges each calendar's reply instead of recording
  a bare pending attestation, and requires `minimumCalendars` (default 2)
  to answer.
- `upgrade` fetches `{calendar}/timestamp/{commitment}` and merges the
  reply; pending attestations are dropped once a Bitcoin one exists below.

### Added
- `verifyTimestamp`: offline verification against 80-byte block headers
  (merkle root, proof of work, block time); never throws.
- `BlockHeaderSource` and `ExplorerBlockHeaderSource`, which requires two
  independent explorers to agree.
- `ots_verify` command-line verifier.

### Removed
- File hashing, SHA-1, RIPEMD-160, Keccak, hexlify, reverse and other ops
  public Bitcoin calendars do not emit; Litecoin and other attestation
  types (kept only as opaque unknown attestations); `print` logging; the
  `meta` dependency and mockito.

## [0.9.0] - 2025-12-01

### Added
- Initial project structure
- Core OpenTimestamps protocol implementation
- Calendar client for submitting timestamps
- Proof file parser and serializer
- Timestamp verification against Bitcoin blockchain
- Support for upgrade operations
- Apache 2.0 license headers on all source files
- 100% test coverage

## [0.1.0] - 2024-11-30

### Added
- Initial release
- Apache 2.0 license
- Project structure and documentation
