# Test fixtures

`hello-world.txt`, `incomplete.txt`, `two-calendars.txt`, `merkle1.txt` and
their `.ots` proofs are copied unmodified from the `examples/` directory of
[opentimestamps-client](https://github.com/opentimestamps/opentimestamps-client)
(LGPL-3.0), the reference implementation.

`hello-world.txt.ots` is a complete proof (Bitcoin block 358391), but its
first step is a RIPEMD-160 op, which this library deliberately does not
support (public calendars only emit SHA-256, append and prepend). The tests
assert it is rejected cleanly.

`hello-world-bitcoin-path.ots` is derived from it so the real Bitcoin path
can still be verified: the RIPEMD-160, prepend, append and double-SHA-256
steps were applied (with Python's `hashlib`) to reach the 32-byte
transaction id, and the remaining bytes of the original proof - the merkle
path to block 358391 - were kept unchanged behind a new header naming that
transaction id as the digest.

`block-358391.header.hex` is the 80-byte header of Bitcoin block 358391
(hash `000000000000000003e892881a8cdcdc117c06d444057c98b6f04a9ee75a2319`),
fetched from both blockstream.info and mempool.space, which agreed.
