import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';

// Run from the runner directory. This wrapper never edits application source.
const mode=process.argv[2]||'auth';
if(!['auth','business','list'].includes(mode))throw Error('Use auth, business or list.');
const configPath=path.resolve(process.env.BIDVIBE_RUN_CONFIG||'runner.local.json');
const config=JSON.parse(fs.readFileSync(configPath,'utf8'));
const env={...process.env};
for(const [key,value] of Object.entries(config))if(typeof value==='string')env[key]=value;
for(const key of ['BIDVIBE_CREDENTIALS_FILE','BIDVIBE_WEB_BUILD_DIR','BIDVIBE_BE_ROOT'])if(env[key])env[key]=path.resolve(env[key]);
if(!fs.existsSync(env.BIDVIBE_CREDENTIALS_FILE||''))throw Error('Set BIDVIBE_CREDENTIALS_FILE in runner.local.json.');
const run=new Date().toISOString().replace(/[:.]/g,'-')+'-'+crypto.randomBytes(3).toString('hex');
env.E2E_RUN_ID=run;
env.BIDVIBE_DATA_RUN_DIR=path.resolve('private-run',run);
env.BIDVIBE_TEST_PREFIX='E2E_PW_'+new Date().toISOString().slice(0,10).replaceAll('-','')+'_'+crypto.randomBytes(4).toString('hex')+'_';
const cli=path.resolve('node_modules/@playwright/test/cli.js');
let clock;
let testChild;
const stop=()=>{testChild?.kill();clock?.kill();};
process.once('SIGINT',()=>{stop();process.exitCode=130;});
process.once('SIGTERM',()=>{stop();process.exitCode=143;});
try{
 if(mode==='business'){
  if(config.BIDVIBE_ALLOW_SHARED_MUTATIONS!=='true')throw Error('Business run writes test data. Set BIDVIBE_ALLOW_SHARED_MUTATIONS to "true" only on an authorized target.');
  if(!fs.existsSync(path.join(env.BIDVIBE_BE_ROOT||'','src/config/db.js')))throw Error('Set BIDVIBE_BE_ROOT to the backend checkout with installed dependencies and its local .env.');
  // Fail early if another clock already owns this port; never reuse it.
  try{await fetch('http://127.0.0.1:8891/health',{signal:AbortSignal.timeout(1000)});throw Error('Port 8891 already has a test clock. Stop the previous run first.');}catch(e){if(String(e.message).startsWith('Port '))throw e;}
  clock=spawn(process.execPath,['scripts/test-clock.mjs'],{env,stdio:'inherit'});
  const deadline=Date.now()+45_000;
  let ready=false;
  while(Date.now()<deadline&&clock.exitCode===null){
   try{const r=await fetch('http://127.0.0.1:8891/health',{signal:AbortSignal.timeout(1000)});const b=await r.json();if(b.prefix===env.BIDVIBE_TEST_PREFIX){ready=true;break;}}catch{}
   await new Promise(resolve=>setTimeout(resolve,300));
  }
  if(!ready)throw Error('Fixture clock did not start. Check BE database connectivity and .env.');
 }
 const args=['test'];
 if(mode==='auth')args.push('tests/01-browser-readiness.spec.ts','tests/02-auth-roles.spec.ts');
 if(mode==='list')args.push('--list');
 args.push(...process.argv.slice(3));
 console.log(`Run ${run}; results in reports/${run}. No automatic retries.`);
 testChild=spawn(process.execPath,[cli,...args],{env,stdio:'inherit'});
 const code=await new Promise((resolve,reject)=>{testChild.once('error',reject);testChild.once('exit',code=>resolve(code??1));});
 process.exitCode=Number(code);
}finally{clock?.kill();}
