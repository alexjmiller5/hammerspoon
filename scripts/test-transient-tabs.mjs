import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
const source = fs.readFileSync(new URL("../profiles/work/transientTabs.js", import.meta.url), "utf8");
const rules = [
 { id: "cli", host: "localhost", pathPrefix: "/", contains: ["Signed in to Example CLI", "You can close this window"] },
 { id: "handoff", host: "auth.example.com", pathPrefix: "/app/auth/complete/", contains: ["You can now close this browser window"] },
 { id: "proxy", host: "proxy.example.com", pathPrefix: "/api/v1/check_auth", contains: [] },
];
function observe(url, text, ready = "complete", configured = rules) {
 return vm.runInNewContext(source, { location: { href: url }, document: { readyState: ready, body: { innerText: text } }, rules: configured, URL, JSON });
}
const success = "Signed in to Example CLI\nYou can close this window";
assert.deepEqual(JSON.parse(observe("http://localhost:54321/?state=SECRET&code=PRIVATE", success)), [{rule:"cli",status:"success"}]);
assert.equal(observe("http://localhost:54321", "ERR_CONNECTION_REFUSED").includes("success"), false);
assert.equal(observe("http://localhost:54321", success, "loading").includes("success"), false);
assert.equal(observe("http://localhost:54321", "Signed in to Example CLI").includes("success"), false);
assert.equal(observe("http://localhost.evil.test:54321", success), "[]");
assert.equal(observe("https://auth.example.com.evil.test/app/auth/complete/x", success), "[]");
assert.equal(observe("https://auth.example.com/app/auth/login", success), "[]");
assert.equal(observe("https://auth.example.com/app/auth/complete/x", "You can now close this browser window").includes("success"), true);
assert.equal(observe("https://proxy.example.com/api/v1/check_auth?landing=true", "anything").includes("success"), false);
assert.equal(observe("chrome-error://chromewebdata/", success), "[]");
assert.equal(observe("file:///tmp/page", success), "[]");
assert.equal(observe("http://localhost:54321", success, "complete", []), "[]");
assert.equal(observe("http://localhost:54321/?code=PRIVATE", success).includes("PRIVATE"), false);
console.log("Transient tab classifier: 13 checks passed");
