import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {fileURLToPath} from 'node:url';import path from 'node:path';
import {ConnectedBridge} from './connected-bridge.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
test('Connected plan declares exactly 47 unique IDs implemented by the native suite',()=>{
 const plan=JSON.parse(fs.readFileSync(path.join(here,'connected-plan.json'),'utf8'));assert.equal(plan.length,47);assert.equal(new Set(plan.map(c=>c[0])).size,47);
 const source=fs.readFileSync(path.resolve(here,'../../integration_test/mobile_web_e2e_test.dart'),'utf8');
 const ids=[...source.matchAll(/_scenario\(\s*'([^'$]+)'/g)].map(m=>m[1]);for(let n=9;n<=13;n++)ids.push('X-S'+String(n).padStart(2,'0'));assert.deepEqual(ids.sort(),plan.map(c=>c[0]).sort());
});
test('Unknown connected branch cannot create or mutate fixtures',async()=>{let calls=0;const bridge=new ConnectedBridge({fixtures:{auction:()=>{calls++;}},actor:async()=>({})});await assert.rejects(bridge.branch('foreign-order'),/Unknown connected branch/);assert.equal(calls,0);});
test('A client cannot terminate an unregistered branch',async()=>{let calls=0;const bridge=new ConnectedBridge({fixtures:{request:()=>{calls++;}},actor:async()=>({})});await assert.rejects(bridge.execute({op:'terminate',kind:'foreign'}),/Owned branch missing/);assert.equal(calls,0);});
test('A client cannot suspend an account before this run registers its buyer',async()=>{let calls=0;const bridge=new ConnectedBridge({fixtures:{request:()=>{calls++;}},actor:async()=>({})});await assert.rejects(bridge.execute({op:'suspend-buyer',accountId:'1'}),/Buyer not registered/);assert.equal(calls,0);});
