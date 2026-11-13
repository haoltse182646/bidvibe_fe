import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const plan=JSON.parse(fs.readFileSync(new URL('./mobile-plan.json',import.meta.url),'utf8'));
const source=fs.readFileSync(new URL('../../integration_test/android_business_e2e_test.dart',import.meta.url),'utf8');
test('Android business plan has unique IDs and excludes counted auth/registration/setup cases',()=>{
 assert.ok(plan.length>=60);
 assert.equal(new Set(plan.map(c=>c.id)).size,plan.length);
 assert.ok(plan.every(c=>!/^A-(AUTH|REG|SETUP)/.test(c.id)&&c.title&&c.classification));
});
test('Every planned Android business ID is implemented, including generated role and state cases',()=>{
 const ids=[...source.matchAll(/_scenario\(\s*'([^'$]+)'/g)].map(m=>m[1]);
 for(const suffix of ['EMPTY','ZERO','NEGATIVE','DECIMAL','OVERMAX'])ids.push('A-WALLET-'+suffix);
 for(let n=1;n<=5;n++)ids.push('A-WH-'+n);
 for(const suffix of ['OVERVIEW','FLAGS','DISPUTES','REPORT','ACCOUNTS'])ids.push('A-ADMIN-'+suffix);
 for(const suffix of ['pause','verify','safe'])ids.push('A-MOD-'+suffix);
 for(const suffix of ['BIDDER','SELLER','APPRAISER','WAREHOUSE'])ids.push('A-RBAC-'+suffix);
 assert.deepEqual(ids.sort(),plan.map(c=>c.id).sort());
});
test('Native runner derives expected business count from the plan rather than legacy 34',()=>{
 const runner=fs.readFileSync(new URL('./mobile-run.mjs',import.meta.url),'utf8');
 assert.ok(runner.includes("'mobile-plan.json'"));
 assert.ok(!runner.includes(':34;'));
 assert.ok(source.includes('setUpAll(() async'));
});
test('The main purchase journey runs first in the same order shown by the dashboard',()=>{
 const match=source.match(/const _mainFlow = <String>\[([\s\S]*?)\];/);
 assert.ok(match,'Native main-flow order must be declared');
 const ids=[...match[1].matchAll(/'([^']+)'/g)].map(m=>m[1]);
 assert.equal(ids.length,16);
 assert.deepEqual(plan.slice(0,16).map(c=>c.id),ids);
 assert.ok(plan.slice(0,16).every(c=>c.phase==='main-flow'));
 assert.ok(plan.slice(16).every(c=>c.phase==='additional-cases'));
 assert.ok(source.includes('_registerScenarios();'));
});
