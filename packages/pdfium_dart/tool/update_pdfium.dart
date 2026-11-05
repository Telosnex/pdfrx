// Updates PDFium on every platform to a bblanchon/pdfium-binaries release.
//
//   cd packages/pdfium_dart && dart tool/update_pdfium.dart 8138
//
// Downloads each archive pdfrx uses, checks it against the SHA-256
// digest GitHub reports for the release asset, and writes pdfium.json. It
// also installs the release's pdfium.wasm in packages/pdfrx/assets/ and keeps
// the Apple archives in .dart_tool/pdfium_archives/ for
// packages/pdfium_flutter/tool/build_xcframework.sh.
//
// The XCFramework is then built and published separately; see
// doc/updating-pdfium.md.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Every archive pdfrx uses: the hook's targets, the web build, and the
/// inputs of the XCFramework.
const archives = [
  'android-arm', 'android-arm64', 'android-x64', 'android-x86', //
  'linux-arm', 'linux-arm64', 'linux-x64', 'linux-x86', //
  'mac-arm64', 'mac-x64', //
  'win-arm64', 'win-x64', 'win-x86', //
  'ios-catalyst-arm64', 'ios-catalyst-x64', 'ios-device-arm64', //
  'ios-simulator-arm64', 'ios-simulator-x64', //
  'wasm',
];

Future<void> main(List<String> args) async {
  if (args.length != 1 || int.tryParse(args.single) == null) {
    stderr.writeln('Usage: dart tool/update_pdfium.dart <chromium build>');
    exitCode = 64;
    return;
  }
  if (!File('pubspec.yaml').readAsStringSync().contains('name: pdfium_dart')) {
    throw StateError('Run this tool from packages/pdfium_dart.');
  }
  final release = 'chromium/${args.single}';
  final client = http.Client();
  try {
    final digests = await _assetDigests(client, release);
    final archiveDir = Directory('.dart_tool/pdfium_archives/${args.single}')
      ..createSync(recursive: true);
    final pins = <String, Object>{};
    for (final name in archives) {
      final file = 'pdfium-$name.tgz';
      final expected = digests[file];
      if (expected == null) throw StateError('$release has no $file.');
      final bytes = await _download(
        client,
        Uri.parse(
          'https://github.com/bblanchon/pdfium-binaries/releases/download/'
          '$release/$file',
        ),
      );
      final actual = sha256.convert(bytes).toString();
      if ('sha256:$actual' != expected) {
        throw StateError('$file: SHA-256 $actual, GitHub reports $expected.');
      }
      File('${archiveDir.path}/$file').writeAsBytesSync(bytes);
      pins[name] = {'sha256': actual};
      stdout.writeln('ok $file');
    }

    final version = _version(archiveDir, 'mac-arm64');
    final wasm = _member(archiveDir, 'wasm', 'lib/pdfium.wasm');
    File('../pdfrx/assets/pdfium.wasm').writeAsBytesSync(wasm);

    final pinFile = File('pdfium.json');
    final old = pinFile.existsSync()
        ? jsonDecode(pinFile.readAsStringSync()) as Map<String, Object?>
        : const <String, Object?>{};
    final xcframework = old['xcframework'] as Map<String, Object?>?;
    pinFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        '_comment': 'PDFium for every platform, from bblanchon/pdfium-binaries. '
            'Update with tool/update_pdfium.dart: see doc/updating-pdfium.md.',
        'release': release,
        'version': version,
        'archives': pins,
        'wasm': {'sha256': sha256.convert(wasm).toString()},
        // Kept only while it was built from this release.
        if (xcframework != null && xcframework['release'] == release)
          'xcframework': xcframework,
      })}\n',
    );
    stdout.writeln('''
Wrote pdfium.json for $release ($version) and packages/pdfrx/assets/pdfium.wasm.
Next:
  1. dart tool/ffigen.dart --force
  2. Build and publish the XCFramework (doc/updating-pdfium.md), then put its
     URL and SHA-256 in pdfium.json, the podspec and Package.swift.''');
  } finally {
    client.close();
  }
}

Future<Map<String, String>> _assetDigests(
  http.Client client,
  String release,
) async {
  final token = Platform.environment['GITHUB_TOKEN'];
  final response = await client.get(
    Uri.parse(
      'https://api.github.com/repos/bblanchon/pdfium-binaries/releases/tags/'
      '${Uri.encodeComponent(release)}',
    ),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    throw StateError('GitHub API: HTTP ${response.statusCode} for $release.');
  }
  final assets = (jsonDecode(response.body) as Map)['assets'] as List;
  return {
    for (final asset in assets.cast<Map>())
      if (asset['digest'] is String)
        asset['name'] as String: asset['digest'] as String,
  };
}

Future<List<int>> _download(http.Client client, Uri uri) async {
  final response = await client.get(uri);
  if (response.statusCode != 200) {
    throw StateError('HTTP ${response.statusCode}: $uri');
  }
  return response.bodyBytes;
}

List<int> _member(Directory dir, String archive, String path) {
  final bytes = File('${dir.path}/pdfium-$archive.tgz').readAsBytesSync();
  final file = TarDecoder()
      .decodeBytes(GZipDecoder().decodeBytes(bytes))
      .findFile(path);
  if (file == null) throw StateError('pdfium-$archive.tgz has no $path.');
  return file.content as List<int>;
}

String _version(Directory dir, String archive) {
  final fields = {
    for (final line in utf8.decode(_member(dir, archive, 'VERSION')).split('\n'))
      if (line.contains('=')) line.split('=')[0]: line.split('=')[1].trim(),
  };
  return [fields['MAJOR'], fields['MINOR'], fields['BUILD'], fields['PATCH']]
      .join('.');
}
