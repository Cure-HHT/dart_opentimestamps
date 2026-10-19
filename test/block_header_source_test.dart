import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const _hash =
    '000000000000000003e892881a8cdcdc117c06d444057c98b6f04a9ee75a2319';

void main() {
  final headerHex = hexEncode(block358391Header());

  ExplorerBlockHeaderSource sourceWith(
    String Function(Uri url) headerFor, {
    String hash = _hash,
  }) =>
      ExplorerBlockHeaderSource(
        httpClient: MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/block-height/358391')) {
            return http.Response(hash, 200);
          }
          if (path.endsWith('/block/$hash/header')) {
            return http.Response(headerFor(r.url), 200);
          }
          return http.Response('not found', 404);
        }),
      );

  test('returns the header when both explorers agree', () async {
    final urls = <String>[];
    final header = await sourceWith((url) {
      urls.add(url.host);
      return '$headerHex\n';
    }).headerAt(358391);
    expect(hexEncode(header), headerHex);
    expect(urls.toSet(), {'blockstream.info', 'mempool.space'});
  });

  test('rejects explorers that disagree', () async {
    final forged = headerHex.replaceRange(0, 2, '03');
    await expectLater(
      sourceWith((url) => url.host == 'mempool.space' ? forged : headerHex)
          .headerAt(358391),
      throwsA(isA<BlockHeaderException>()),
    );
  });

  test('rejects a header that does not hash to the reported block', () async {
    await expectLater(
      sourceWith((_) => headerHex, hash: '00' * 32).headerAt(358391),
      throwsA(isA<BlockHeaderException>()),
    );
  });

  test('rejects HTTP errors and malformed headers', () async {
    await expectLater(
      sourceWith((_) => headerHex).headerAt(1),
      throwsA(isA<BlockHeaderException>()),
    );
    await expectLater(
      sourceWith((_) => 'zz').headerAt(358391),
      throwsA(isA<BlockHeaderException>()),
    );
  });

  test('requires at least two explorers on distinct hosts', () {
    expect(
      () => ExplorerBlockHeaderSource(explorers: ['https://x']),
      throwsArgumentError,
    );
    expect(
      () => ExplorerBlockHeaderSource(explorers: [
        'https://blockstream.info/api',
        'https://BLOCKSTREAM.info/api/',
      ]),
      throwsArgumentError,
    );
  });

  test('does not follow redirects and rejects an oversized reply', () async {
    final follows = <bool>[];
    final source = ExplorerBlockHeaderSource(
      httpClient: MockClient((r) async {
        follows.add(r.followRedirects);
        return r.url.host == 'mempool.space'
            ? http.Response('', 302, headers: {'location': 'http://x/'})
            : http.Response('0' * 5000, 200);
      }),
    );
    await expectLater(
      source.headerAt(358391),
      throwsA(isA<BlockHeaderException>()),
    );
    expect(follows, everyElement(isFalse));
    expect(follows, isNotEmpty);
  });
}
