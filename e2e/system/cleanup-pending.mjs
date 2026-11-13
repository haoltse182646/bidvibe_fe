import fs from 'node:fs';import path from 'node:path';import{fileURLToPath}from 'node:url';import{createRequire}from 'node:module';
import{backendServices,closeBackend}from './fixtures.mjs';import{applyCleanup,validateScope}from './cleanup-core.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));const config=JSON.parse(fs.readFileSync(path.join(here,'runner.local.json'),'utf8'));if(config.allowSharedDatabaseMutations!==true)throw Error('Database mutation permission is required');for(const k of ['backendRoot','credentialsFile'])config[k]=path.resolve(here,config[k]);
const credentials=JSON.parse(fs.readFileSync(config.credentialsFile,'utf8'));const protectedEmails=Object.entries(credentials).filter(([k])=>/EMAIL$/.test(k)).map(([,v])=>v);const base=path.join(here,'private-run');const results=[];
try{
 if(fs.existsSync(base))for(const entry of fs.readdirSync(base,{withFileTypes:true})){
  if(!entry.isDirectory()||entry.isSymbolicLink()||!/^\d{4}-\d{2}-\d{2}T[0-9TZ-]+-[a-f0-9]{6}$/.test(entry.name))continue;
  const dir=path.join(base,entry.name),file=path.join(dir,'cleanup-scope.private.json');if(!fs.existsSync(file))continue;
  const reportFile=path.join(here,'reports',entry.name,'results.json');const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile,'utf8')):null;
  if(report?.cleanup?.status==='PASS'||report?.cleanupRecovery?.status==='PASS'||report?.cleanup?.status==='RETAINED'){results.push({runId:entry.name,status:'SKIP',reason:'Already cleaned or intentionally retained'});continue;}
  const scope=JSON.parse(fs.readFileSync(file,'utf8'));if(scope.mode!=='run')throw Error('Recovery cannot run a historical/global cleanup');validateScope(scope);
  if(!report?.finishedAt&&Date.now()-Date.parse(scope.startedAt)<86400000){results.push({runId:entry.name,status:'SKIP',reason:'Possibly active or recently interrupted; do not race the runner'});continue;}
  try{scope.protectedEmails=[...new Set([...(scope.protectedEmails||[]),...protectedEmails])];const{pool}=backendServices(config.backendRoot);const require=createRequire(path.join(config.backendRoot,'package.json'));const result=await applyCleanup({pool,walletService:require(path.join(config.backendRoot,'src/services/wallet_service')),scope,backupDirectory:path.join(dir,'cleanup-backups')});const{backupFile,...safe}=result;if(report){report.cleanupRecovery={...safe,backupStored:true,recovered:true};fs.writeFileSync(reportFile,JSON.stringify(report,null,2));fs.writeFileSync(path.join(here,'reports',entry.name,'cleanup-recovery.json'),JSON.stringify(report.cleanupRecovery,null,2));}results.push({runId:entry.name,...safe});}catch(e){results.push({runId:entry.name,status:'FAIL',error:e.message});process.exitCode=1;}
 }
 console.log(JSON.stringify({results},null,2));
}finally{await closeBackend();}
