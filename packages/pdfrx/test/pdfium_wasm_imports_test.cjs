// Every import of assets/pdfium.wasm must exist in pdfium_worker.js, which
// supplies them by hand instead of using Emscripten's generated loader.
// Otherwise a PDFium update fails only in the browser, with a LinkError.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const assets = path.join(__dirname, '..', 'assets');

function workerContext() {
  const context = {
    self: { location: { href: 'test' } },
    console: { log() {}, warn() {}, error() {} },
    TextDecoder,
    TextEncoder,
    Uint8Array,
    Float32Array,
    ArrayBuffer,
    onmessage: null,
    postMessage() {},
    fetch() {
      throw new Error('Unexpected fetch');
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(assets, 'pdfium_worker.js'), 'utf8'), context);
  return context;
}

test('pdfium_worker.js supplies every import of pdfium.wasm', () => {
  const module = new WebAssembly.Module(fs.readFileSync(path.join(assets, 'pdfium.wasm')));
  const imports = vm.runInContext(
    '({ env: emEnv, wasi_snapshot_preview1: wasi })',
    workerContext(),
  );
  const missing = WebAssembly.Module.imports(module)
    .filter(({ module, name, kind }) => kind !== 'function' || typeof imports[module]?.[name] !== 'function')
    .map(({ module, name, kind }) => `${module}.${name} (${kind})`);
  assert.deepEqual(missing, []);
});

test('pdfium.wasm is the one pdfium.json pins', () => {
  const pins = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', '..', 'pdfium_dart', 'pdfium.json'), 'utf8'),
  );
  const hash = require('node:crypto')
    .createHash('sha256')
    .update(fs.readFileSync(path.join(assets, 'pdfium.wasm')))
    .digest('hex');
  assert.equal(hash, pins.wasm.sha256);
});
