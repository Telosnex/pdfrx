const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function client() {
  let worker;
  class FakeWorker {
    constructor() { worker = this; this.sent = []; this.terminated = false; }
    postMessage(message) { this.sent.push(message); }
    terminate() { this.terminated = true; }
  }
  const context = vm.createContext({ Worker: FakeWorker, console, pdfiumWasmWorkerUrl: 'worker.js' });
  vm.runInContext(fs.readFileSync('assets/pdfium_client.js', 'utf8'), context);
  return { worker, api: context.PdfiumWasmCommunicator };
}

test('stop rejects pending commands, terminates worker, and is idempotent', async () => {
  const { worker, api } = client();
  const a = api.sendCommand('init');
  const b = api.sendCommand('loadText');
  api.stop();
  api.stop();
  assert.equal(worker.terminated, true);
  await assert.rejects(a, /stopped/);
  await assert.rejects(b, /stopped/);
  await assert.rejects(api.sendCommand('init'), /stopped/);
  assert.equal(worker.sent.length, 2);
});

test('worker crash rejects pending commands', async () => {
  const { worker, api } = client();
  const pending = api.sendCommand('loadText');
  worker.onerror(new Error('boom'));
  await assert.rejects(pending, /failed/);
  assert.equal(worker.terminated, true);
});

test('normal replies work before stop', async () => {
  const { worker, api } = client();
  const pending = api.sendCommand('loadText');
  worker.onmessage({ data: { id: worker.sent[0].id, status: 'success', result: { fullText: 'text' } } });
  assert.deepEqual(await pending, { fullText: 'text' });
  api.stop();
});
