// Local end-to-end smoke test. Requires the test server on :8097 and Playwright.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {chromium} = require('playwright');
const origin = 'http://127.0.0.1:8097';
const body = Buffer.from(JSON.stringify({role:'school', school_id:'e2e-school', exp:Math.floor(Date.now()/1000)+3600})).toString('base64url');
const token = body + '.' + crypto.createHmac('sha256', 'mtmi-local-test-secret').update(body).digest('base64url');
const headers = {Authorization:'Bearer '+token, 'Content-Type':'application/json'};
const seed = {palyazo_iskola_neve:'E2E Test School', iskola_cime:'Original address', mtmi_nyilt_napok:'Original days', future_field:'Keep unrendered data'};
execFileSync('psql', ['-h','127.0.0.1','-p','55439','-d','mtmi_concurrency_test','-v','ON_ERROR_STOP=1','-c', `
  INSERT INTO schools(id,name,form_id,created_at,updated_at) VALUES('e2e-school','E2E Test School','e2e-form',now(),now()) ON CONFLICT(id) DO NOTHING;
  INSERT INTO forms(id,data,school_id,submitted,created_at,updated_at) VALUES('e2e-form','${JSON.stringify(seed)}'::jsonb,'e2e-school',0,now(),now())
  ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,submitted=0,updated_at=now();
  UPDATE app_settings SET submission_mode='forced_open',submission_start_at=NULL,submission_end_at=NULL WHERE id=1;
`], {stdio:'pipe'});
async function current() {
  const response = await fetch(origin+'/api/load/e2e-form', {headers});
  assert.equal(response.status, 200);
  return response.json();
}
async function waitData(predicate) {
  for (let i=0; i<100; i++) {
    const data = (await current()).data;
    if (predicate(data)) return data;
    await new Promise(r=>setTimeout(r,100));
  }
  throw new Error('Timed out waiting for saved data');
}
async function edit(page, name, value) {
  await page.evaluate(({name,value}) => {
    const input = document.querySelector('[name="'+name+'"]');
    input.value = value; input.dispatchEvent(new Event('input', {bubbles:true}));
  }, {name,value});
}
(async () => {
  const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  const errors = [];
  async function page(draft) {
    const context = await browser.newContext();
    await context.addInitScript(({token,draft}) => {
      localStorage.setItem('mtmi_school_id','e2e-school');
      localStorage.setItem('mtmi_school_name','E2E Test School');
      localStorage.setItem('mtmi_school_token',token);
      localStorage.setItem('mtmi_session_id','e2e-form');
      if (draft) localStorage.setItem('mtmi_local_draft',JSON.stringify(draft));
    }, {token,draft});
    const p = await context.newPage();
    p.on('pageerror', e=>errors.push(e.message));
    await p.goto(origin+'/kitoltes/e2e-form');
    await p.waitForFunction(() => typeof window.saveForm==='function' && !window.isLoadingForm && !formLoadBlocked);
    return p;
  }
  try {
    const a = await page(), b = await page();
    await edit(a,'iskola_cime','Editor A address');
    assert.equal(await a.evaluate(()=>window.saveForm(true)), true);
    await edit(b,'mtmi_nyilt_napok','Editor B days');
    await b.evaluate(()=>window.saveForm(true));
    const merged = await waitData(d=>d.iskola_cime==='Editor A address' && d.mtmi_nyilt_napok==='Editor B days');
    assert.equal(merged.future_field, seed.future_field);
    console.log('PASS: two editors merge different fields and keep unrendered data');

    await a.evaluate(()=>window.loadForm());
    await edit(a,'iskola_cime','Server choice');
    await a.evaluate(()=>window.saveForm(true));
    await edit(b,'iskola_cime','Local choice');
    const saving = b.evaluate(()=>window.saveForm(true));
    await b.locator('#mtmi-conflict-dialog').waitFor();
    assert.equal(await b.getByRole('button',{name:'Választások alkalmazása'}).isDisabled(), true);
    await b.locator('#mtmi-conflict-dialog input[value="mine"]').check();
    await b.getByRole('button',{name:'Választások alkalmazása'}).click();
    await saving;
    await waitData(d=>d.iskola_cime==='Local choice');
    console.log('PASS: overlapping field requires explicit resolution');

    const draft = {school_id:'e2e-school',session_id:'e2e-form',saved_at:'2026-10-01T10:00:00Z',data:{...seed,iskola_cime:'Old draft address'}};
    const c = await page(draft);
    assert.equal(await c.locator('[name="iskola_cime"]').inputValue(),'Local choice');
    assert.equal((await current()).data.iskola_cime,'Local choice');
    await c.getByRole('button',{name:'Piszkozat összevetése'}).click();
    await c.locator('#mtmi-conflict-dialog').waitFor();
    await c.getByRole('button',{name:'Később egyeztetem'}).click();
    assert.equal((await current()).data.iskola_cime,'Local choice');
    assert.ok(await c.evaluate(()=>localStorage.getItem('mtmi_local_draft')));
    console.log('PASS: old draft never replaces fresh server data automatically; cancelling retains draft');

    let release;
    const gate = new Promise(r=>release=r);
    let requested;
    const requestSeen = new Promise(r=>requested=r);
    await c.route('**/api/save', async route => {
      requested(); await gate; await route.continue();
    });
    await edit(c,'iskola_cime','Sent text');
    const inFlight = c.evaluate(()=>window.saveForm(true));
    await requestSeen;
    await edit(c,'iskola_cime','Typed during save');
    release(); await inFlight;
    await c.unroute('**/api/save');
    assert.equal(await c.locator('[name="iskola_cime"]').inputValue(),'Typed during save');
    await waitData(d=>d.iskola_cime==='Typed during save');
    console.log('PASS: typing during save survives and is saved next');

    const legacy = await fetch(origin+'/api/save',{method:'POST',headers,body:JSON.stringify({session_id:'e2e-form',data:{}})});
    assert.equal(legacy.status,428);
    assert.equal((await current()).data.iskola_cime,'Typed during save');
    assert.deepEqual(errors,[]);
    console.log('PASS: old-client write is rejected; no browser JavaScript errors');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e); process.exitCode=1;});
