// Run: bun scripts/test-work-web-hotkeys.mjs <disposable-page-CDP-WebSocket-URL>
// The tab's contents are replaced. Use a blank test tab, never an inbox.
import { execFileSync } from 'node:child_process';
const output = execFileSync('hs', ['-c', `local ok, code, slack = pcall(dofile, hs.configdir .. "/scripts/test-work-hotkeys.lua"); print("UNDO_CODE:" .. hs.json.encode({ok=ok, code=code, slack=slack}))`], { encoding: 'utf8' });
const { ok, code, slack } = JSON.parse(output.split('\n').find(line => line.startsWith('UNDO_CODE:')).slice(10));
if (!ok) throw new Error(code);
const ws = new WebSocket(process.argv[2]);
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
let sequence = 0;
function call(method, params) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    ws.onmessage = ({ data }) => {
      const message = JSON.parse(data);
      if (message.id !== id) return;
      if (message.error || message.result.exceptionDetails) reject(new Error(JSON.stringify(message)));
      else resolve(message.result);
    };
    ws.send(JSON.stringify({ id, method, params }));
  });
}
const expression = `(${function (code, slack) {
  if (location.href !== 'about:blank') throw new Error('Use a disposable about:blank tab');
  const run = new Function('location', 'return ' + code);
  const cases = [
    ['visible Undo', '<div role="alert"><span role="link">Undo</span></div>', null, 'mail.google.com', true],
    ['native button', '<div role="status"><button>Undo</button></div>', null, 'mail.google.com', true],
    ['no Undo', '<div role="alert">Saved</div>', null, 'mail.google.com', false],
    ['hidden Undo', '<div role="alert" hidden><span role="link">Undo</span></div>', null, 'mail.google.com', false],
    ['invisible Undo', '<div role="alert" style="visibility:hidden"><span role="link">Undo</span></div>', null, 'mail.google.com', false],
    ['offscreen notification', '<div role="alert" style="position:absolute;top:-10000px"><span role="link">Undo</span></div>', null, 'mail.google.com', false],
    ['disabled Undo', '<div role="alert"><button disabled>Undo</button></div>', null, 'mail.google.com', false],
    ['message-body link', '<main><a href="#">Undo</a></main>', null, 'mail.google.com', false],
    ['search input', '<input><div role="alert"><button>Undo</button></div>', 'input', 'mail.google.com', false],
    ['textarea', '<textarea></textarea><div role="alert"><button>Undo</button></div>', 'textarea', 'mail.google.com', false],
    ['message editor', '<div contenteditable="true">Draft</div><div role="alert"><button>Undo</button></div>', '[contenteditable]', 'mail.google.com', false],
    ['custom textbox', '<div role="textbox" tabindex="0"></div><div role="alert"><button>Undo</button></div>', '[role="textbox"]', 'mail.google.com', false],
    ['browser address bar', '<div role="alert"><button>Undo</button></div>', null, 'mail.google.com', false],
    ['unrelated website', '<div role="alert"><button>Undo</button></div>', null, 'example.com', false],
  ];
  const failures = [];
  for (const [name, html, focus, hostname, want] of cases) {
    document.body.innerHTML = html;
    if (focus) document.querySelector(focus).focus();
    let clicks = 0;
    document.body.onclick = () => clicks++;
    const hasFocus = document.hasFocus;
    if (name === 'browser address bar') document.hasFocus = () => false;
    const consumed = run({ hostname });
    document.hasFocus = hasFocus;
    if (consumed !== want || clicks !== Number(want)) failures.push(name);
  }
  const toggle = new Function('location', 'return ' + slack);
  document.body.innerHTML = '<button data-qa="floating_sidebars_toggle_button" aria-label="Hide sidebars">Toggle</button>';
  const button = document.querySelector('button');
  let toggles = 0;
  button.onclick = () => { toggles++; button.setAttribute('aria-label', toggles % 2 ? 'Show sidebars' : 'Hide sidebars'); };
  if (!toggle({hostname:'app.slack.com'}) || button.getAttribute('aria-label') !== 'Show sidebars') failures.push('hide Slack sidebar');
  if (!toggle({hostname:'app.slack.com'}) || button.getAttribute('aria-label') !== 'Hide sidebars') failures.push('show Slack sidebar');
  if (toggle({hostname:'example.com'}) || toggles !== 2) failures.push('Slack control on another site');
  button.hidden = true;
  if (toggle({hostname:'app.slack.com'}) || toggles !== 2) failures.push('hidden Slack control');
  button.remove();
  if (toggle({hostname:'app.slack.com'})) failures.push('missing Slack control');
  document.body.replaceChildren();
  document.body.onclick = null;
  return { checks: cases.length + 5, failures };
}.toString()})(${JSON.stringify(code)}, ${JSON.stringify(slack)})`;
try {
  await call('Emulation.setFocusEmulationEnabled', { enabled: true });
  const result = (await call('Runtime.evaluate', { expression, returnByValue: true })).result.value;
  if (result.failures.length) throw new Error(result.failures.join(', '));
  console.log(`work-web-hotkeys: ${result.checks} browser checks passed`);
} finally {
  await call('Emulation.setFocusEmulationEnabled', { enabled: false });
  ws.close();
}
