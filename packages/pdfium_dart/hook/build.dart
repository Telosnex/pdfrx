import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import '../lib/src/proxy_http_client.dart';

const _assetName = 'libpdfium';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    // Process-wide PDFium gate: a tiny dylib whose statics are shared across
    // Flutter engines in one OS process. Built on every platform, including iOS
    // (where libpdfium itself comes from pdfium_flutter's XCFramework).
    await CBuilder.library(
      name: 'pdfrx_pdfium_gate',
      packageName: input.packageName,
      assetName: 'src/pdfrx_pdfium_gate.dart',
      sources: ['src/pdfrx_pdfium_gate.c'],
    ).run(input: input, output: output);

    if (input.config.code.targetOS == OS.iOS) return;

    // The PDFium release and each archive's SHA-256, shared with
    // tool/ffigen.dart and the web and Apple builds.
    final pinFile = input.packageRoot.resolve('pdfium.json');
    output.dependencies.add(pinFile);
    final pins = jsonDecode(
      await File.fromUri(pinFile).readAsString(),
    ) as Map<String, Object?>;
    final release = pins['release'] as String;
    final target = _PdfiumTarget.fromCodeConfig(input.config.code);
    final archiveName = '${target.archivePlatform}-${target.archiveArch}';
    final archivePin =
        (pins['archives'] as Map<String, Object?>)[archiveName]
            as Map<String, Object?>?;
    if (archivePin == null) {
      throw UnsupportedError('pdfium.json pins no PDFium for $archiveName.');
    }
    final outputSubdir = release.replaceAll('/', '_');
    final outputFile = input.outputDirectoryShared.resolve(
      '$outputSubdir/${target.archivePlatform}-${target.archiveArch}/${target.libraryFileName}',
    );

    await _downloadPdfium(
      outputFile: outputFile,
      target: target,
      pdfiumRelease: release,
      sha256Hex: archivePin['sha256'] as String,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: outputFile,
      ),
    );
  });
}

Future<void> _downloadPdfium({
  required Uri outputFile,
  required _PdfiumTarget target,
  required String pdfiumRelease,
  required String sha256Hex,
}) async {
  final output = File.fromUri(outputFile);
  if (await output.exists()) return;

  final archiveName =
      'pdfium-${target.archivePlatform}-${target.archiveArch}.tgz';
  final archiveUri = Uri.parse(
    'https://github.com/bblanchon/pdfium-binaries/releases/download/'
    '${pdfiumRelease.replaceAll('/', '%2F')}/$archiveName',
  );

  final response = await getPdfiumArchiveWithApiFallback(archiveUri);
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to download PDFium: HTTP ${response.statusCode} $archiveUri',
    );
  }

  final actual = sha256.convert(response.bodyBytes).toString();
  if (actual != sha256Hex) {
    throw Exception(
      'PDFium archive $archiveUri has SHA-256 $actual; pdfium.json pins '
      '$sha256Hex.',
    );
  }

  final archive = TarDecoder().decodeBytes(
    GZipDecoder().decodeBytes(response.bodyBytes),
  );
  final member = archive.findFile(target.archiveLibraryPath);
  if (member == null) {
    throw Exception(
      'PDFium archive $archiveUri does not contain ${target.archiveLibraryPath}.',
    );
  }

  await output.parent.create(recursive: true);
  await output.writeAsBytes(member.content as List<int>);
}

final class _PdfiumTarget {
  const _PdfiumTarget({
    required this.archivePlatform,
    required this.archiveArch,
    required this.archiveLibraryPath,
    required this.libraryFileName,
  });

  final String archivePlatform;
  final String archiveArch;
  final String archiveLibraryPath;
  final String libraryFileName;

  static _PdfiumTarget fromCodeConfig(CodeConfig config) {
    final arch = switch (config.targetArchitecture) {
      Architecture.ia32 => 'x86',
      Architecture.x64 => 'x64',
      Architecture.arm => 'arm',
      Architecture.arm64 => 'arm64',
      _ => throw UnsupportedError(
        'Unsupported PDFium architecture: ${config.targetArchitecture}',
      ),
    };

    return switch (config.targetOS) {
      OS.android => _PdfiumTarget(
        archivePlatform: 'android',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.so',
        libraryFileName: 'libpdfium.so',
      ),
      OS.windows => _PdfiumTarget(
        archivePlatform: 'win',
        archiveArch: arch,
        archiveLibraryPath: 'bin/pdfium.dll',
        libraryFileName: 'pdfium.dll',
      ),
      OS.linux => _PdfiumTarget(
        archivePlatform: 'linux',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.so',
        libraryFileName: 'libpdfium.so',
      ),
      OS.macOS => _PdfiumTarget(
        archivePlatform: 'mac',
        archiveArch: arch,
        archiveLibraryPath: 'lib/libpdfium.dylib',
        libraryFileName: 'libpdfium_dart.dylib',
      ),
      _ => throw UnsupportedError(
        'Unsupported PDFium platform: ${config.targetOS}',
      ),
    };
  }
}
