import 'dart:io';

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

Future<ProcessResult> _run(List<String> args) =>
    Process.run(Platform.resolvedExecutable, ['bin/ots_verify.dart', ...args]);

void main() {
  const proof = 'test/fixtures/hello-world-bitcoin-path.ots';
  final digest = hexEncode(
    DetachedTimestampFile.deserialize(fixture('hello-world-bitcoin-path.ots'))
        .digest,
  );
  final header = '358391=${hexEncode(block358391Header())}';

  test('exits 0 for a valid proof', () async {
    final r = await _run([proof, digest, header]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('valid: block 358391'));
  });

  test('exits 1 for the wrong digest', () async {
    final r = await _run([proof, '00' * 32, header]);
    expect(r.exitCode, 1);
  });

  test('exits 1 for the original RIPEMD-160 hello-world proof', () async {
    final r = await _run([
      'test/fixtures/hello-world.txt.ots',
      '03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340',
      header,
    ]);
    expect(r.exitCode, 1);
    expect(r.stdout, contains('malformed proof'));
  });

  test('exits 2 for a pending proof', () async {
    final pending = DetachedTimestampFile.deserialize(
      fixture('incomplete.txt.ots'),
    );
    final r = await _run(
        ['test/fixtures/incomplete.txt.ots', hexEncode(pending.digest)]);
    expect(r.exitCode, 2);
  });

  test('exits 64 on bad usage', () async {
    expect((await _run([])).exitCode, 64);
    expect((await _run([proof, digest, 'nonsense'])).exitCode, 64);
  });
}
