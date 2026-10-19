# dart_opentimestamps

Gets one SHA-256 digest - the head of an append-only hash chain -
witnessed by Bitcoin through public [OpenTimestamps](https://opentimestamps.org/)
calendars, and verifies the resulting proof offline.

[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

## Start here

After cloning, run once:

```sh
./tools/setup-repo.sh          # activate this clone's git hooks
./tools/setup-repo.sh --check  # verify the clone is set up (reports via exit status)
./tool/test.sh                 # run the tests
```

## Related repositories

- `hht_workflows` - shared CI checks every repo runs
- `hht_admin` - org infrastructure and the authoritative `HHT-OPS-*` spec

## Purpose and scope

An event log that chains each entry's SHA-256 hash into the next is already
tamper-evident against partial edits, but not against someone who rewrites
the whole chain. Stamping the chain head with an outside witness closes that
gap: the head commits to every earlier entry, so one proof shows the whole
log existed, unchanged, no later than a given Bitcoin block.

This package does only that:

1. **Stamp** a 32-byte digest at two or more calendars (a random nonce is
   added first, so calendars learn nothing about the digest).
2. **Upgrade** the proof hours later, once a calendar has committed it to a
   Bitcoin block.
3. **Store** the proof as a standard `.ots` file, readable by any
   OpenTimestamps tool (`ots verify -d <digest-hex> proof.ots`).
4. **Verify** it offline against the 80-byte header of the attested block.

It does not hash files, and supports only the operations public calendars
emit for Bitcoin paths (SHA-256, append, prepend). Proofs using anything
else, including old RIPEMD-160 paths, are rejected. It knows nothing about
any particular event log: its input is a digest.

## Usage

```dart
import 'package:dart_opentimestamps/dart_opentimestamps.dart';

final client = OpenTimestampsClient();
final proof = await client.stamp(chainHead);   // 32 bytes
store(proof.serialize());

// Later, and only until proof.isComplete:
if (await client.upgrade(proof)) store(proof.serialize());

// Once complete, fetch each attested header once and keep it with the
// proof; ExplorerBlockHeaderSource requires blockstream.info and
// mempool.space to agree.
final source = ExplorerBlockHeaderSource();
final headers = {
  for (final h in proof.bitcoinHeights) h: await source.headerAt(h),
};

// Any time, with no network:
switch (verifyTimestamp(proofBytes, chainHead, headers)) {
  case VerificationValid(:final height, :final blockTime): ...
  case VerificationPending(): ...
  case VerificationInvalid(:final reason): ...
}
```

The client never retries or polls; the caller decides how often to stamp
and upgrade, and should keep both rare (public calendars are a shared,
free service).

Independent check from the command line:

```sh
dart run dart_opentimestamps:ots_verify proof.ots <digest-hex> <height>=<header-hex>
```

## What a valid result means

The attested message equals the merkle root in the supplied header and the
header carries real proof of work, so the digest existed no later than that
block's time. Proof of work alone does not prove the header is on the
Bitcoin main chain; that comes from where the header was obtained (two
independent explorers here, or any Bitcoin node, which a reviewer can use to
re-check the stored header).

## Testing

```sh
./tool/test.sh                    # unit tests; never touch the network
OTS_LIVE=1 dart test test/live_test.dart  # one real submission
```

The reference vectors in `test/fixtures/` come from
`opentimestamps-client`; see its README.

## License

Apache 2.0 - see [LICENSE](LICENSE).

## Credits

- [OpenTimestamps](https://opentimestamps.org/) by Peter Todd; the format
  follows [python-opentimestamps](https://github.com/opentimestamps/python-opentimestamps).
- A joint creation of [Anspar Foundation](https://anspar.org) and
  [Mindful Software](https://mindfulsoftware.com) for
  [Cure HHT](https://curehht.org/).
