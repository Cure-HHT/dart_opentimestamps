import 'dart:math';
import 'dart:typed_data';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  final proof = fixture('hello-world-bitcoin-path.ots');
  final digest = DetachedTimestampFile.deserialize(proof).digest;
  final headers = {358391: block358391Header()};

  Matcher invalidBecause(String reason) => isA<VerificationInvalid>()
      .having((r) => r.reason, 'reason', contains(reason));

  test('a real Bitcoin proof verifies against the real block header', () {
    final result = verifyTimestamp(proof, digest, headers);
    expect(
      result,
      isA<VerificationValid>().having((r) => r.height, 'height', 358391).having(
          (r) => r.blockTime,
          'blockTime',
          DateTime.utc(2015, 5, 28, 15, 41, 18)),
    );
  });

  test('a different expected digest is invalid', () {
    expect(verifyTimestamp(proof, digestOf(0), headers),
        invalidBecause('different digest'));
  });

  test('a tampered digest no longer reaches the merkle root', () {
    final tampered = Uint8List.fromList(proof);
    tampered[33] ^= 1; // first digest byte, after magic, version, hash op
    final tamperedDigest = DetachedTimestampFile.deserialize(tampered).digest;
    expect(verifyTimestamp(tampered, tamperedDigest, headers),
        invalidBecause('merkle root'));
  });

  test('a header for another block is invalid', () {
    final other = Uint8List.fromList(block358391Header())..[40] ^= 1;
    expect(verifyTimestamp(proof, digest, {358391: other}),
        invalidBecause('merkle root'));
  });

  test('a header without valid proof of work is invalid', () {
    final badNonce = Uint8List.fromList(block358391Header())..[79] ^= 1;
    expect(verifyTimestamp(proof, digest, {358391: badNonce}),
        invalidBecause('proof of work'));
  });

  test('a header claiming an easier-than-allowed target is invalid', () {
    final easy = Uint8List.fromList(block358391Header())
      ..setRange(72, 76, [0xff, 0xff, 0x00, 0x1e]); // nBits 0x1e00ffff
    expect(verifyTimestamp(proof, digest, {358391: easy}),
        invalidBecause('difficulty'));
  });

  test('a missing or short header is invalid', () {
    expect(
        verifyTimestamp(proof, digest, {}), invalidBecause('no block header'));
    expect(verifyTimestamp(proof, digest, {358391: Uint8List(79)}),
        invalidBecause('80 bytes'));
  });

  test('an incomplete proof is pending', () {
    final incomplete = fixture('incomplete.txt.ots');
    final d = DetachedTimestampFile.deserialize(incomplete).digest;
    expect(
      verifyTimestamp(incomplete, d, {}),
      isA<VerificationPending>().having((r) => r.calendars, 'calendars',
          {'https://alice.btc.calendar.opentimestamps.org'}),
    );
  });

  test('a proof with only unknown attestations is invalid', () {
    final p = DetachedTimestampFile(digestOf(1));
    p.timestamp.attestations.add(UnknownAttestation(
        Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]), Uint8List(0)));
    expect(verifyTimestamp(p.serialize(), digestOf(1), {}),
        invalidBecause('no Bitcoin or pending'));
  });

  test('malformed input is invalid and never throws', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List(100),
      Uint8List.sublistView(proof, 0, proof.length - 3),
      fixture('hello-world.txt.ots'), // unsupported RIPEMD-160 op
    ]) {
      expect(verifyTimestamp(bytes, digest, headers),
          invalidBecause('malformed proof'));
    }
  });

  test('random corruption of real proofs never throws', () {
    final random = Random(469);
    final seeds = [
      proof,
      for (final n in ['incomplete', 'two-calendars', 'merkle1'])
        fixture('$n.txt.ots'),
    ];
    for (var i = 0; i < 20000; i++) {
      final bytes = Uint8List.fromList(seeds[i % seeds.length]);
      for (var k = random.nextInt(4); k >= 0; k--) {
        bytes[random.nextInt(bytes.length)] = random.nextInt(256);
      }
      final cut = random.nextInt(8) == 0 ? random.nextInt(bytes.length) : null;
      final input = Uint8List.sublistView(bytes, 0, cut);
      final result = verifyTimestamp(input, digest, headers);
      if (result is VerificationValid) expect(input, proof);
    }
  });

  test('blockHash and blockTime read the header', () {
    final header = block358391Header();
    expect(hexEncode(blockHash(header).reversed.toList()),
        '000000000000000003e892881a8cdcdc117c06d444057c98b6f04a9ee75a2319');
    expect(blockTime(header), DateTime.utc(2015, 5, 28, 15, 41, 18));
  });
}
