import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

void main() {
  test('default implementation preserves text without normalization', () async {
    const text = ' A\r\n\u4e2d\u{1f642}\u0000 ';
    final page = _FallbackPage(PdfPageRawText(text, const []));
    expect(await page.loadTextOnly(), text);
    expect(page.loadCount, 1);
  });

  test('default implementation distinguishes unavailable and empty text', () async {
    expect(await _FallbackPage(null).loadTextOnly(), isNull);
    expect(await _FallbackPage(PdfPageRawText('', const [])).loadTextOnly(), '');
  });

  test('renumbered and rotated proxies preserve the optimized method', () async {
    final page = _TextOnlyPage();
    final proxies = [
      page.withPageNumber(3),
      page.rotatedCW90(),
      page.rotatedCW90().withPageNumber(3),
      page.withPageNumber(3).rotatedCW90(),
    ];
    for (final proxy in proxies) {
      expect(await proxy.loadTextOnly(), 'text only');
    }
    expect(page.textOnlyCount, proxies.length);
    expect(page.loadCount, 0);
  });

  test('default implementation propagates extraction failures', () async {
    await expectLater(_FailingPage().loadTextOnly(), throwsStateError);
  });
}

class _FallbackPage extends PdfPage {
  _FallbackPage(this.rawText);

  final PdfPageRawText? rawText;
  int loadCount = 0;

  @override
  Future<PdfPageRawText?> loadText() async {
    loadCount++;
    return rawText;
  }

  @override
  int get pageNumber => 1;

  @override
  PdfPageRotation get rotation => PdfPageRotation.none;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TextOnlyPage extends _FallbackPage {
  _TextOnlyPage() : super(null);

  int textOnlyCount = 0;

  @override
  Future<String?> loadTextOnly() async {
    textOnlyCount++;
    return 'text only';
  }
}

class _FailingPage extends _FallbackPage {
  _FailingPage() : super(null);

  @override
  Future<PdfPageRawText?> loadText() async => throw StateError('extraction failed');
}
