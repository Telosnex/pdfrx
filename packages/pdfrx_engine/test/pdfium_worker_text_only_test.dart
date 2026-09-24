import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Exercises the shipped worker source with instrumented PDFium exports.
/// Requires Node.js, as do the worker's existing metadata tests.
void main() {
  final scenarios = <String, String>{
    'text-only skips rectangle calls, allocation, and response data': r'''
      const result = await loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false });
      assert.equal(result.fullText, 'A\r\n\u4e2d\u{1f642}\0');
      assert.equal('charRects' in result, false);
      assert.equal(calls.box, 0);
      assert.equal(calls.malloc, 0);
      assert.equal(calls.free, 0);
      assert.equal(calls.closeText, 1);
      assert.equal(calls.closePage, 1);
      assert.equal(calls.updateFonts, 1);
    ''',
    'default mode retains rectangles and identical Unicode text': r'''
      const full = await loadText({ docHandle: 1, pageIndex: 0 });
      const text = await loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false });
      assert.equal(full.fullText, text.fullText);
      assert.equal(full.charRects.length, codes.length);
      assert.deepEqual(Array.from(full.charRects[0]), [1, 4, 3, 2]);
      assert.equal(calls.box, codes.length);
      assert.equal(calls.malloc, 1);
      assert.equal(calls.free, 1);
    ''',
    'empty text is successful in both modes': r'''
      codes = [];
      const full = await loadText({ docHandle: 1, pageIndex: 0 });
      const text = await loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false });
      assert.equal(full.fullText, '');
      assert.equal(full.charRects.length, 0);
      assert.equal(text.fullText, '');
      assert.equal('charRects' in text, false);
      assert.equal(calls.closeText, 2);
      assert.equal(calls.closePage, 2);
    ''',
    'page load failure rejects without accessing a null handle': r'''
      Pdfium.wasmExports.FPDF_LoadPage = () => 0;
      Pdfium.wasmExports.FPDFText_LoadPage = () => { throw Error('must not run'); };
      await assert.rejects(loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false }), /Failed to load page/);
      assert.equal(calls.closePage, 0);
    ''',
    'text load failure closes its page': r'''
      Pdfium.wasmExports.FPDFText_LoadPage = () => 0;
      await assert.rejects(loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false }), /Failed to load text page/);
      assert.equal(calls.closeText, 0);
      assert.equal(calls.closePage, 1);
    ''',
    'negative character count releases both handles': r'''
      Pdfium.wasmExports.FPDFText_CountChars = () => -1;
      await assert.rejects(loadText({ docHandle: 1, pageIndex: 0, includeCharRects: false }), /Failed to count/);
      assert.equal(calls.closeText, 1);
      assert.equal(calls.closePage, 1);
      assert.equal(calls.malloc, 0);
    ''',
    'allocation failure releases both handles': r'''
      Pdfium.wasmExports.malloc = () => 0;
      await assert.rejects(loadText({ docHandle: 1, pageIndex: 0 }), /Failed to allocate/);
      assert.equal(calls.closeText, 1);
      assert.equal(calls.closePage, 1);
      assert.equal(calls.free, 0);
    ''',
    'extraction failure releases resources in both modes': r'''
      Pdfium.wasmExports.FPDFText_GetUnicode = () => { throw Error('unicode failed'); };
      for (const includeCharRects of [false, true]) {
        await assert.rejects(loadText({ docHandle: 1, pageIndex: 0, includeCharRects }), /unicode failed/);
      }
      assert.equal(calls.closeText, 2);
      assert.equal(calls.closePage, 2);
      assert.equal(calls.malloc, 1);
      assert.equal(calls.free, 1);
    ''',
    'rectangle reads survive WASM memory growth': r'''
      const original = Pdfium.wasmExports.FPDFText_GetCharBox;
      Pdfium.wasmExports.FPDFText_GetCharBox = (...args) => {
        Pdfium.memory.grow(1);
        original(...args);
      };
      const full = await loadText({ docHandle: 1, pageIndex: 0 });
      assert.equal(full.charRects.length, codes.length);
      for (const rect of full.charRects) assert.deepEqual(Array.from(rect), [1, 4, 3, 2]);
    ''',
  };

  for (final entry in scenarios.entries) {
    test(entry.key, () async {
      final result = await Process.run('node', [
        '-e',
        '''
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = vm.createContext({
  self: { location: { href: 'test' } },
  console, WebAssembly, TextDecoder, TextEncoder, Uint8Array, Float64Array, ArrayBuffer,
  onmessage: null, postMessage() {}, assert,
  fetch() { throw new Error('Unexpected fetch'); },
});
vm.runInContext(fs.readFileSync('../pdfrx/assets/pdfium_worker.js', 'utf8'), context);
vm.runInContext(${jsonEncode('$_setup${entry.value}\n})()')}, context)
  .catch(error => { console.error(error); process.exitCode = 1; });
''',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
  }
}

const _setup = r'''
(async () => {
  const calls = { box: 0, malloc: 0, free: 0, closeText: 0, closePage: 0, updateFonts: 0 };
  let codes = [65, 13, 10, 0x4e2d, 0x1f642, 0];
  _ensurePageAvailable = async () => {};
  _resetMissingFonts = () => {};
  _updateMissingFonts = () => { calls.updateFonts++; };
  Pdfium.memory = new WebAssembly.Memory({ initial: 1 });
  Pdfium.wasmExports = {
    FPDF_LoadPage: () => 2,
    FPDFText_LoadPage: () => 3,
    FPDFText_CountChars: () => codes.length,
    FPDFText_GetUnicode: (_, index) => codes[index],
    FPDFText_GetCharBox: (_, index, left, right, bottom, top) => {
      calls.box++;
      const view = new DataView(Pdfium.memory.buffer);
      view.setFloat64(left, 1, true);
      view.setFloat64(bottom, 2, true);
      view.setFloat64(right, 3, true);
      view.setFloat64(top, 4, true);
    },
    malloc: () => { calls.malloc++; return 32; },
    free: () => { calls.free++; },
    FPDFText_ClosePage: () => { calls.closeText++; },
    FPDF_ClosePage: () => { calls.closePage++; },
  };
''';
