const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

// Run the actual entry point against browser doubles; no provider or microphone access.
function loadApp({ decodeError = false, fetchError = false } = {}) {
  const revoked = [];
  const charts = [];
  const source = fs.readFileSync(path.join(__dirname, "../js/app.js"), "utf8")
    .replace(/^import .*$/gm, "");
  class AudioContext {
    decodeAudioData() {
      return decodeError ? Promise.reject(new Error("bad audio")) : Promise.resolve({});
    }
    createBufferSource() {
      return { connect() {}, start() {} };
    }
  }
  class Chart {
    constructor() {
      this.destroyed = false;
      charts.push(this);
    }
    destroy() { this.destroyed = true; }
  }
  const context = vm.createContext({
    AudioContext, Chart, Blob, Uint8Array,
    atob: value => Buffer.from(value, "base64").toString("binary"),
    URL: { createObjectURL: () => "blob:test", revokeObjectURL: url => revoked.push(url) },
    fetch: () => fetchError
      ? Promise.reject(new Error("fetch failed"))
      : Promise.resolve({ arrayBuffer: () => Promise.resolve(new ArrayBuffer(1)) }),
    console: { log() {}, error() {} },
    document: {
      getElementsByClassName: () => [],
      querySelector: () => ({ getAttribute: () => "csrf" }),
      addEventListener() {},
    },
    window: { addEventListener() {} },
    Socket: class {},
    LiveSocket: class { connect() {} },
    topbar: { config() {} },
  });
  vm.runInContext(source, context);
  return { context, revoked, charts };
}

for (const [name, options] of [
  ["successful playback", {}],
  ["audio decoding failure", { decodeError: true }],
  ["blob fetch failure", { fetchError: true }],
]) {
  test(`releases the audio blob URL after ${name}`, async () => {
    const { context, revoked } = loadApp(options);
    vm.runInContext('fetchAndDecodeAudio("YQ==")', context);
    // Let the complete fetch/decode promise chain settle.
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(revoked, ["blob:test"]);
  });
}
