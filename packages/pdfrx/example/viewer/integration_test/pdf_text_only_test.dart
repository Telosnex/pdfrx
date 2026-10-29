import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:telosnex_web_test/telosnex_web_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  installWebTestSupport(binding);
  pdfTextOnlyTests();
}

/// Text extraction of the fork: loadTextOnly returns the same text as
/// loadText without building the character rectangles. Also called by
/// all.dart, the entry point of the web and iOS runs.
void pdfTextOnlyTests() {
  testWidgets('extracts the text of an asset PDF without character rectangles', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openAsset('assets/hello.pdf');
    addTearDown(document.dispose);

    expect(document.pages.length, greaterThan(0));
    for (final page in document.pages) {
      final text = await page.loadTextOnly();
      expect(text, isNotNull, reason: 'page ${page.pageNumber}');
      expect(text!.trim(), isNotEmpty, reason: 'page ${page.pageNumber}');

      final raw = await page.loadText();
      expect(raw, isNotNull, reason: 'page ${page.pageNumber}');
      expect(text, raw!.fullText, reason: 'page ${page.pageNumber}');
      expect(raw.charRects, isNotEmpty, reason: 'page ${page.pageNumber}');
    }
  });
}
