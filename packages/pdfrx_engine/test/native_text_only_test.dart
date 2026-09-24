import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => pdfrxInitialize());

  test('native text-only equals loadText on all pages', () async {
    final doc = await PdfDocument.openFile('../pdfrx/example/viewer/assets/hello.pdf');
    try {
      for (final page in doc.pages) {
        expect(await page.loadTextOnly(), (await page.loadText())?.fullText);
      }
    } finally {
      await doc.dispose();
    }
  });

  test('native text-only returns null for disposed documents', () async {
    final doc = await PdfDocument.openFile('../pdfrx/example/viewer/assets/hello.pdf');
    final page = doc.pages.first;
    await doc.dispose();
    expect(await page.loadTextOnly(), isNull);
  });

  test('native text-only preserves Unicode from multi-page fixture', () async {
    final pdf = await File('../pdfrx/test/assets/multipage40.pdf').readAsBytes();
    final doc = await PdfDocument.openData(pdf);
    try {
      for (final page in doc.pages) {
        expect(await page.loadTextOnly(), (await page.loadText())?.fullText);
      }
    } finally {
      await doc.dispose();
    }
  });
}
