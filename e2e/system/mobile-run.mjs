import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import http from 'node:http';
import {spawn,execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const exec=promisify(execFile);
const here=path.dirname(fileURLToPath(import.meta.url));
const config=JSON.parse(fs.readFileSync(path.join(here,'runner.local.json'),'utf8'));
const root=path.resolve(here,config.frontendRoot||'../..');
const credentials=JSON.parse(fs.readFileSync(path.resolve(here,config.credentialsFile),'utf8'));
const mode=process.argv[2]||'business';
if(!['auth','business','connected'].includes(mode))throw Error('Unknown mobile mode.');
if(config.allowSharedDatabaseMutations!==true)throw Error('Set allowSharedDatabaseMutations=true only for the authorized database.');
const suite=mode==='connected'?'connected':'mobile';
const hubURL=process.env.BIDVIBE_SYSTEM_HUB_URL;
const hubKey=process.env.BIDVIBE_SYSTEM_HUB_KEY;
async function hub(endpoint,body){if(!hubURL)return {};const r=await fetch(hubURL+endpoint,{method:'POST',headers:{'Content-Type':'application/json','x-system-key':hubKey},body:JSON.stringify(body),signal:AbortSignal.timeout(85000)});const b=await r.json();if(!r.ok)throw Error(b.error||'System coordinator error');return b;}
const api=String(credentials.BIDVIBE_API_BASE_URL||'').replace(/\/+$/,'');
if(api!=='https://bidvibe-be.onrender.com')throw Error('This suite currently targets the agreed Render API.');
const device=config.deviceId||'emulator-5554';
if(!/^emulator-\d+$/.test(device))throw Error('Select an Android emulator ID in runner.local.json.');
const sdk=config.androidSdk||process.env.ANDROID_SDK_ROOT||process.env.ANDROID_HOME||path.join(process.env.LOCALAPPDATA||'','Android','Sdk');
const adb=config.adbCommand||path.join(sdk,'platform-tools',process.platform==='win32'?'adb.exe':'adb');
const flutter=config.flutterCommand||'flutter';
const runId=new Date().toISOString().replace(/[:.]/g,'-')+'-'+crypto.randomBytes(3).toString('hex');
const runDir=path.join(here,'private-run',runId);
fs.mkdirSync(path.join(runDir,'screenshots'),{recursive:true});
const prefix=process.env.BIDVIBE_SYSTEM_PREFIX||'E2E_ANDROID_'+new Date().toISOString().slice(0,10).replaceAll('-','')+'_'+crypto.randomBytes(5).toString('hex');
const key=crypto.randomBytes(24).toString('hex');
const freshEmail='e2e_android_'+Date.now()+'@example.com';
const freshPassword='Android_'+crypto.randomBytes(10).toString('hex')+'!';
const competitorEmail='e2e_android_a_'+Date.now()+'@example.com';
const competitorPassword='Android_'+crypto.randomBytes(10).toString('hex')+'!';
const restricted=process.env.BIDVIBE_SYSTEM_RESTRICTED_FILE?JSON.parse(fs.readFileSync(process.env.BIDVIBE_SYSTEM_RESTRICTED_FILE,'utf8')):{};
const defines={...credentials,...restricted,BIDVIBE_API_BASE_URL:api,BIDVIBE_ALLOW_DEPLOYED_AUTH_TEST:true,E2E_ANDROID_ALLOW_BUSINESS:true,E2E_ANDROID_PREFIX:prefix,E2E_ANDROID_CONTROL_URL:'http://127.0.0.1:8892',E2E_ANDROID_CONTROL_KEY:key,E2E_ANDROID_BUYER_EMAIL:freshEmail,E2E_ANDROID_BUYER_PASSWORD:freshPassword,E2E_ANDROID_COMPETITOR_EMAIL:competitorEmail,E2E_ANDROID_COMPETITOR_PASSWORD:competitorPassword};
const definesFile=path.join(runDir,'defines.local.json');
fs.writeFileSync(definesFile,JSON.stringify(defines,null,2));
const sourceName=mode==='connected'?'mobile_web_e2e_test.dart':'android_business_e2e_test.dart';
const sourceBytes=fs.readFileSync(path.join(root,'integration_test',sourceName));
fs.writeFileSync(path.join(runDir,'test-source.dart'),sourceBytes);
const sourceSHA256=crypto.createHash('sha256').update(sourceBytes).digest('hex');
const secrets=[key,freshEmail,freshPassword,competitorEmail,competitorPassword,...Object.entries(defines).filter(([k])=>/EMAIL|PASSWORD/.test(k)).map(([,v])=>String(v))].filter(Boolean);
const clean=value=>{let s=String(value);for(const secret of secrets)s=s.split(secret).join('[redacted]');return s.replace(/Bearer\s+[A-Za-z0-9._-]+/gi,'Bearer [redacted]').replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,'[redacted-token]');};
const events=[];const logs=[];
let child,server,pool,broadcast,interrupted=false,reverseAdded=false;
let exitCode=1;

function flutterRun(args){
 return new Promise((resolve,reject)=>{
  const env={...process.env,BIDVIBE_ANDROID_FLUTTER:flutter,BIDVIBE_ANDROID_FLUTTER_ARGS:JSON.stringify(args)};
  child=process.platform==='win32'
   ?spawn('powershell.exe',['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(here,'invoke-flutter.ps1')],{cwd:root,env,stdio:['ignore','pipe','pipe'],windowsHide:true})
   :spawn(flutter,args,{cwd:root,env,stdio:['ignore','pipe','pipe']});
  for(const stream of [child.stdout,child.stderr]){
   let pending='';
   stream.on('data',data=>{pending+=data.toString();const lines=pending.split(/\r?\n/);pending=lines.pop();for(const line of lines){const safe=clean(line);logs.push(safe);process.stdout.write(safe+'\n');const match=safe.match(/\b([AX]-[A-Za-z0-9_-]+):\s*(.*)$/);if(match)hub('/runner-event',{suite,id:match[1],title:match[2],status:'RUNNING'}).catch(error=>process.stderr.write(clean(error.message)+'\n'));}});
   stream.on('end',()=>{if(pending){const safe=clean(pending);logs.push(safe);process.stdout.write(safe+'\n');}});
  }
  child.once('error',reject);child.once('exit',code=>resolve(code??1));
 });
}

async function deviceReady(){
 let ready=false;
 try{ready=(await exec(adb,['-s',device,'get-state'])).stdout.trim()==='device';}catch{}
 if(!ready&&config.launchEmulatorId){
  console.log('Starting the configured emulator...');
  const code=await flutterRun(['emulators','--launch',config.launchEmulatorId]);
  if(code!==0)throw Error('Emulator launch failed.');
 }
 const end=Date.now()+180_000;
 while(Date.now()<end){
  try{if((await exec(adb,['-s',device,'shell','getprop','sys.boot_completed'],{timeout:5000})).stdout.trim()==='1')return;}catch{}
  await new Promise(r=>setTimeout(r,1000));
 }
 throw Error('Emulator is not ready. Start it and check flutter devices.');
}

async function startControl(){
 const require=createRequire(path.join(path.resolve(config.backendRoot),'package.json'));
 require('dotenv').config({path:path.join(config.backendRoot,'.env'),quiet:true});
 process.env.DB_POOL_MAX='1';
 pool=require(path.join(config.backendRoot,'src/config/db')).pool;
 const dev=require(path.join(config.backendRoot,'src/services/dev_service'));
 const engine=require(path.join(config.backendRoot,'src/services/auction_engine'));
 broadcast=require(path.join(config.backendRoot,'src/sockets/broadcast'));
 await pool.query('SELECT 1');
 const allowed=new Set();
 server=http.createServer(async(req,res)=>{
  const send=(code,body)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
  if(req.method!=='POST'||req.headers['x-control-key']!==key)return send(403,{error:'FORBIDDEN'});
  try{
   let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>65536)throw Error('Request too large');}
   const input=JSON.parse(raw);
   if(req.url==='/checkpoint'){
    if(!/^[AX]-[A-Za-z0-9_-]+$/.test(input.id)||!['RUNNING','PASS','FAIL','SKIP'].includes(input.status))throw Error('Invalid checkpoint');
    const event=JSON.parse(clean(JSON.stringify({...input,at:new Date().toISOString()})));
    if(config.captureScreenshots!==false&&['PASS','FAIL'].includes(input.status)){
     try{const {stdout}=await exec(adb,['-s',device,'exec-out','screencap','-p'],{encoding:'buffer',maxBuffer:12*1024*1024,timeout:10000});const name=input.id+'-'+input.status+'.png';fs.writeFileSync(path.join(runDir,'screenshots',name),stdout);event.screenshot='screenshots/'+name;}catch(error){event.screenshotError=clean(error.message);}
    }
    events.push(event);fs.writeFileSync(path.join(runDir,'checkpoints.json'),JSON.stringify(events,null,2));
    await hub('/runner-event',{...event,suite,title:event.evidence?.description||event.id,...(event.screenshot?{screenshotAbsolute:path.join(runDir,event.screenshot)}:{})});
    return send(200,{recorded:true});
   }
   if(req.url==='/connected-command'){if(suite!=='connected')throw Error('Connected command unavailable in mobile mode');return send(200,await hub('/connected-command',{...input,suite}));}
   const id=String(input.auctionId||'');if(!/^\d+$/.test(id))throw Error('Invalid auction id');
   const {rows}=await pool.query('SELECT a.id,l.id AS listing_id,l.title,l.seller_id,l.created_at FROM auctions a JOIN listings l ON l.id=a.listing_id WHERE a.id=$1',[id]);
   const a=rows[0];if(!a||!a.title.startsWith(prefix+'_'))throw Error('Refusing unrelated fixture');
   if(Date.now()-new Date(a.created_at).getTime()>6*3600000)throw Error('Refusing old fixture');
   if(req.url==='/register'){
    if(String(a.seller_id)!==String(input.sellerId)||a.title!==input.title)throw Error('Owner/title mismatch');
    const r=await fetch(api+'/api/auctions/'+id,{headers:{Authorization:'Bearer '+input.token},signal:AbortSignal.timeout(25000)});const b=await r.json();
    if(!b.success||b.data.title!==a.title||String(b.data.listingId)!==String(a.listing_id))throw Error('API and local DB do not match');
    await hub('/register-fixture',{auctionId:id,listingId:String(a.listing_id),sellerId:String(a.seller_id),title:a.title});
    allowed.add(id);return send(200,{registered:true});
   }
   if(!allowed.has(id))throw Error('Fixture not registered');
   if(req.url==='/web-action')return send(200,await hub('/execute-web',{...input,suite}));
   if(req.url==='/end-soon')return send(200,await dev.endAuctionSoon({auctionId:id,seconds:8}));
   if(req.url==='/close-expired')return send(200,{outcome:await engine.closeAuction(id)});
   return send(404,{error:'NOT_FOUND'});
  }catch(error){send(409,{error:clean(error.message)});}
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(8892,'127.0.0.1',resolve);});
 await exec(adb,['-s',device,'reverse','tcp:8892','tcp:8892']);
 reverseAdded=true;
}

function report(){
 const latest=new Map(events.map(e=>[e.id,e]));const rows=[...latest.values()];
 const counts={passed:rows.filter(e=>e.status==='PASS').length,failed:rows.filter(e=>e.status==='FAIL').length,skipped:rows.filter(e=>e.status==='SKIP').length};
 const expectedCases=mode==='auth'?6:mode==='connected'?JSON.parse(fs.readFileSync(path.join(here,'connected-plan.json'),'utf8')).length:34;
 const result={runId,mode,device,prefix,api,sourceSHA256,exitCode,interrupted,counts,expectedCases,notReported:Math.max(0,expectedCases-rows.length),allCasesPassed:exitCode===0&&rows.length===expectedCases&&counts.failed===0&&counts.skipped===0,events:rows};
 fs.writeFileSync(path.join(runDir,'results.json'),JSON.stringify(result,null,2));
 fs.writeFileSync(path.join(runDir,'execution.log'),logs.join('\n'));
 const md=['# BidVibe Android E2E Report','',`Run: ${runId}`,`Device: ${device}`,`API: ${api}`,'',`Recorded outcomes: ${counts.passed} PASS / ${counts.failed} FAIL / ${counts.skipped} SKIP. Flutter exit code: ${exitCode}.`,'','These are Android integration tests, not the Playwright web suite. Each A-* ID is a testWidgets case. PASS is not inferred for missing or blocked cases.','', '| Case | Result | Evidence | Screenshot |','|---|---|---|---|',...rows.map(e=>`| ${e.id} | ${e.status} | ${clean(JSON.stringify(e.evidence)).replaceAll('|','/').replaceAll('\n',' ')} | ${e.screenshot?'[image]('+e.screenshot+')':''} |`),'','Coverage notes: UI roles run sequentially on one emulator. External bid/refund actors use authenticated APIs to trigger real Socket.IO updates while the Android buyer remains logged in. The first dispute refund is exercised through Admin Android UI. Image bytes are injected through the existing PhotoPicker callback; native gallery selection is not tested. Fixture expiry and the secondary/third paid orders are explicit API setup, not UI payment coverage. QR and delivery are simulated application operations, not real banking/logistics.','', 'Raw logs, screenshots and defines.local.json remain private. Do not commit private-run or distribute the test APK containing compiled test credentials.',''];
 fs.writeFileSync(path.join(runDir,'REPORT.md'),md.join('\n'));
 const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
 fs.writeFileSync(path.join(runDir,'REPORT.html'),'<!doctype html><meta charset="utf-8"><title>Android E2E</title><style>body{font:15px system-ui;margin:36px;color:#18243c}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:10px;vertical-align:top}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style><h1>BidVibe Android E2E</h1><p>'+escape(runId)+' — '+escape(JSON.stringify(counts))+'</p><p>Flutter exit code: '+exitCode+'. Missing cases are not PASS.</p><table><tr><th>Case</th><th>Status</th><th>Evidence</th><th>Screenshot</th></tr>'+rows.map(e=>'<tr><td>'+escape(e.id)+'</td><td>'+escape(e.status)+'</td><td><pre>'+escape(JSON.stringify(e.evidence,null,2))+'</pre></td><td>'+(e.screenshot?'<a href="'+escape(e.screenshot)+'">View</a>':'')+'</td></tr>').join('')+'</table><p>See REPORT.md for API setup and native gallery limitations.</p>');
 console.log('Android report: '+path.join(runDir,'REPORT.html'));
}

process.once('SIGINT',()=>{interrupted=true;child?.kill();});
process.once('SIGTERM',()=>{interrupted=true;child?.kill();});
try{
 console.log('Android E2E run '+runId+'; mode '+mode+'. Source is built from '+root);
 await deviceReady();
 await hub('/register-identities',{suite,prefix,emails:[freshEmail,competitorEmail]});
 await startControl();
 const args=['test','integration_test/'+sourceName,'-d',device,'--dart-define-from-file='+definesFile,'--reporter','expanded'];
 if(mode==='auth')args.push('--name','^A-AUTH-');
 exitCode=await flutterRun(args);
}catch(error){logs.push(clean(error.stack||error.message));console.error(clean(error.message));exitCode=1;}
finally{
 if(reverseAdded)try{await exec(adb,['-s',device,'reverse','--remove','tcp:8892']);}catch{}
 if(server)await new Promise(resolve=>server.close(resolve));
 try{await broadcast?.drain();}catch{}
 try{await pool?.end();}catch{}
 report();process.exitCode=exitCode;
}
