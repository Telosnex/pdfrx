// pdfium.json is the one place the PDFium version is pinned. Checks that the
// files which cannot read it (the podspec, Package.swift, the web assets)
// agree with it.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  final pins =
      jsonDecode(File('pdfium.json').readAsStringSync())
          as Map<String, dynamic>;
  final archives = pins['archives'] as Map<String, dynamic>;
  final monorepo = Directory('../pdfium_flutter').existsSync();

  test('pins every archive the hook can download', () {
    for (final name in [
      for (final arch in ['arm', 'arm64', 'x64', 'x86']) 'android-$arch',
      for (final arch in ['arm', 'arm64', 'x64', 'x86']) 'linux-$arch',
      for (final arch in ['arm64', 'x64']) 'mac-$arch',
      for (final arch in ['arm64', 'x64', 'x86']) 'win-$arch',
    ]) {
      expect(
        (archives[name] as Map?)?['sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: name,
      );
    }
  });

  test('the XCFramework is built from this release', () {
    final xcframework = pins['xcframework'] as Map<String, dynamic>?;
    expect(xcframework, isNotNull, reason: 'Build it: doc/updating-pdfium.md');
    expect(xcframework!['release'], pins['release']);
  });

  test('podspec and Package.swift use the pinned XCFramework', () {
    final xcframework = pins['xcframework'] as Map<String, dynamic>;
    final podspec = File(
      '../pdfium_flutter/darwin/pdfium_flutter.podspec',
    ).readAsStringSync();
    final package = File(
      '../pdfium_flutter/darwin/pdfium_flutter/Package.swift',
    ).readAsStringSync();
    expect(podspec, contains('PDFIUM_URL = "${xcframework['url']}"'));
    expect(podspec, contains('PDFIUM_HASH = "${xcframework['sha256']}"'));
    expect(package, contains('url: "${xcframework['url']}"'));
    expect(package, contains('checksum: "${xcframework['sha256']}"'));
  }, skip: monorepo ? false : 'Not in the pdfrx repository');

  test('the web uses the pinned pdfium.wasm', () {
    final wasm = File('../pdfrx/assets/pdfium.wasm').readAsBytesSync();
    expect(
      sha256.convert(wasm).toString(),
      (pins['wasm'] as Map)['sha256'],
    );
  }, skip: monorepo ? false : 'Not in the pdfrx repository');
}
