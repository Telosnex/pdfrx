@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx/src/wasm/pdfrx_wasm.dart';

@JS('PdfiumWasmCommunicator')
external set _communicator(JSObject value);

class _TestEntryFunctions extends PdfrxEntryFunctionsWasmImpl {
  @override
  Future<void> init() async {}
}

void main() {
  final commands = <(String, Map<Object?, Object?>)>[];
  var loaded = true;
  var failText = false;

  setUp(() {
    commands.clear();
    loaded = true;
    failText = false;
    _communicator =
        {
              'sendCommand': ((String command, JSAny? parameters, JSAny? transfer) {
                final params = (parameters.dartify() as Map).cast<Object?, Object?>();
                commands.add((command, params));
                return Future<JSAny?>(() {
                  return switch (command) {
                    'loadDocumentFromData' => {
                      'docHandle': 1,
                      'permissions': -1,
                      'securityHandlerRevision': -1,
                      'pages': [
                        {
                          'pageIndex': 0,
                          'width': 100.0,
                          'height': 100.0,
                          'rotation': 0,
                          'isLoaded': loaded,
                          'bbLeft': 0.0,
                          'bbBottom': 0.0,
                        },
                      ],
                    }.jsify(),
                    'loadText' when failText => throw StateError('text failed'),
                    'loadText' => {
                      'fullText': ' A\r\n\u4e2d\u{1f642} ',
                      // Text-only responses intentionally contain no rectangle field.
                      if (params['includeCharRects'] != false)
                        'charRects': [
                          [1.0, 4.0, 3.0, 2.0],
                        ],
                    }.jsify(),
                    'closeDocument' => <String, Object?>{}.jsify(),
                    _ => throw StateError('Unexpected command: $command'),
                  };
                }).toJS;
              }).toJS,
            }.jsify()
            as JSObject;
  });

  Future<PdfDocument> open() => _TestEntryFunctions().openData(Uint8List(0), sourceName: 'test');

  test('text-only sends opt-out and reads a response without rectangles', () async {
    final doc = await open();
    try {
      final page = doc.pages.single;
      expect(await page.loadTextOnly(), ' A\r\n\u4e2d\u{1f642} ');
      expect(commands.last.$1, 'loadText');
      expect(commands.last.$2, {'docHandle': 1, 'pageIndex': 0, 'includeCharRects': false});
      final full = await page.loadText();
      expect(full!.fullText, ' A\r\n\u4e2d\u{1f642} ');
      expect(full.charRects, [const PdfRect(1, 4, 3, 2)]);
      expect(commands.last.$2.containsKey('includeCharRects'), isFalse);
    } finally {
      await doc.dispose();
    }
  });

  test('unloaded and disposed pages make no text request', () async {
    loaded = false;
    final doc = await open();
    final page = doc.pages.single;
    expect(await page.loadTextOnly(), isNull);
    await doc.dispose();
    expect(await page.loadTextOnly(), isNull);
    expect(commands.where((command) => command.$1 == 'loadText'), isEmpty);
  });

  test('worker rejection propagates to text-only caller', () async {
    final doc = await open();
    try {
      failText = true;
      await expectLater(doc.pages.single.loadTextOnly(), throwsA(anything));
    } finally {
      await doc.dispose();
    }
  });
}
