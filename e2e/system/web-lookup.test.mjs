import test from 'node:test';
import assert from 'node:assert/strict';
import {WebActor} from './web-suite.mjs';

test('An exact rendered fixture row avoids a redundant network refresh',async()=>{
 let refreshed=false;
 const row={count:async()=>1};
 const actor=new WebActor({fixtures:{},expect:()=>({toContainText:async title=>assert.equal(title,'owned title')})});
 actor.page={getByRole:()=>({filter:()=>row})};
 actor.refresh=async()=>{refreshed=true;throw Error('Redundant refresh');};
 assert.equal(await actor.ownRow({type:'flag',id:'123',title:'owned title'}),row);
 assert.equal(refreshed,false);
});

test('Fast row lookup still rejects a matching ID with the wrong fixture title',async()=>{
 const actor=new WebActor({fixtures:{},expect:()=>({toContainText:async()=>{throw Error('Fixture title mismatch');}})});
 actor.page={getByRole:()=>({filter:()=>({count:async()=>1})})};
 await assert.rejects(actor.ownRow({type:'dispute',id:'123',title:'owned title'}),/Fixture title mismatch/);
});
