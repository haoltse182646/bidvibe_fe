// Localhost-only fixture time control. No application source is changed and no
// global scheduler/seed/reset is started. Mutations require an exact new fixture
// prefix, matching seller, matching Render record, and a private control key.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const beRoot=process.env.BIDVIBE_BE_ROOT||'C:/Users/haolu/Documents/flutter/bidvibe_be';
const require=createRequire(path.join(beRoot,'package.json'));
require('dotenv').config({path:path.join(beRoot,'.env'),quiet:true});
process.env.DB_POOL_MAX='1';
const {pool}=require(path.join(beRoot,'src/config/db'));
const dev=require(path.join(beRoot,'src/services/dev_service'));
const engine=require(path.join(beRoot,'src/services/auction_engine'));
const broadcast=require(path.join(beRoot,'src/sockets/broadcast'));
const cfg=JSON.parse(fs.readFileSync(path.resolve(process.env.BIDVIBE_CREDENTIALS_FILE||'../e2e-auth-private/auth.local.json'),'utf8'));
const api=process.env.BIDVIBE_API_URL||cfg.BIDVIBE_API_BASE_URL;
const prefix=process.env.BIDVIBE_TEST_PREFIX||'E2E_PW_20261030_';
if(!/^E2E_PW_\d{8}_[a-zA-Z0-9_-]+_$/.test(prefix)&&prefix!=='E2E_PW_20261030_')throw Error('Unsafe fixture prefix');
const runDir=path.resolve(process.env.BIDVIBE_DATA_RUN_DIR||'private-run');
const key=crypto.randomBytes(24).toString('hex');
const allowed=new Set();
fs.mkdirSync(runDir,{recursive:true});
fs.writeFileSync(path.join(runDir,'control.local.json'),JSON.stringify({url:'http://127.0.0.1:8891',key,prefix}));
const server=http.createServer(async(req,res)=>{
 const send=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
 if(req.url==='/health')return send(200,{ready:true,prefix,scope:'Only newly created matching E2E fixtures; no global scheduler'});
 if(req.method!=='POST'||req.headers['x-control-key']!==key)return send(403,{error:'FORBIDDEN'});
 try{
  let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>16384)throw Error('Request too large');}
  const input=JSON.parse(raw);const id=String(input.auctionId||'');if(!/^\d+$/.test(id))throw Error('Invalid auction ID');
  const {rows}=await pool.query('SELECT a.id,a.status,a.ends_at,l.id AS listing_id,l.title,l.seller_id,l.created_at FROM auctions a JOIN listings l ON l.id=a.listing_id WHERE a.id=$1',[id]);
  const a=rows[0];if(!a||!a.title.startsWith(prefix))throw Error('Refusing non-test fixture');
  if(Date.now()-new Date(a.created_at).getTime()>6*3600000)throw Error('Refusing old fixture');
  if(req.url==='/register'){
   if(String(a.seller_id)!==String(input.sellerId)||a.title!==input.title)throw Error('Fixture owner/title mismatch');
   const remote=await fetch(`${api}/api/auctions/${id}`,{headers:{Authorization:`Bearer ${input.token}`},signal:AbortSignal.timeout(20000)});
   const body=await remote.json();if(!body.success||body.data.title!==a.title||String(body.data.listingId)!==String(a.listing_id))throw Error('Local DB does not match API fixture');
   allowed.add(id);return send(200,{registered:true,auctionId:id});
  }
  if(!allowed.has(id))throw Error('Fixture not registered');
  if(req.url==='/end-soon')return send(200,await dev.endAuctionSoon({auctionId:id,seconds:8}));
  if(req.url==='/close-expired')return send(200,{outcome:await engine.closeAuction(id)});
  return send(404,{error:'NOT_FOUND'});
 }catch(error){send(409,{error:error.message});}
});
await pool.query('SELECT 1');
server.listen(8891,'127.0.0.1',()=>console.log('Local test clock ready; only validated new E2E fixtures can be changed.'));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,async()=>{server.close();await broadcast.drain();await pool.end();process.exit();});
