import fs from 'node:fs';
import path from 'node:path';
import {expect,type APIRequestContext,type Page,type TestInfo} from '@playwright/test';
import {apiURL,type Account} from './config';
export const runDir=path.resolve(process.env.BIDVIBE_DATA_RUN_DIR||'private-run');
export const fixturePrefix=process.env.BIDVIBE_TEST_PREFIX||'E2E_PW_20261030_';
export const controlPath=path.join(runDir,'control.local.json');
export const statePath=path.join(runDir,'business-state.json');
export function state():Record<string,any>{return fs.existsSync(statePath)?JSON.parse(fs.readFileSync(statePath,'utf8')):{};}
export function updateState(value:Record<string,any>){fs.mkdirSync(runDir,{recursive:true});fs.writeFileSync(statePath,JSON.stringify({...state(),...value},null,2));}
export const freshPath=path.join(runDir,'fresh-bidder.local.json');
export function freshAccount():Account{return JSON.parse(fs.readFileSync(freshPath,'utf8'));}
export async function get(request:APIRequestContext,token:string,endpoint:string){
 const r=await request.get(apiURL+endpoint,{headers:{Authorization:`Bearer ${token}`}});
 const b=await r.json();expect(r.ok(),`${endpoint}: HTTP ${r.status()} ${b.error?.code||''}`).toBe(true);expect(b.success).toBe(true);return b.data;
}
export async function waitBusinessResponse(page:Page,endpoint:string,action:()=>Promise<unknown>,method='POST'){
 const [response]=await Promise.all([
  page.waitForResponse(r=>r.url()===apiURL+endpoint&&r.request().method()===method,{timeout:45_000}),action()
 ]);const body=await response.json();
 return {status:response.status(),...body};
}
export async function evidence(info:TestInfo,name:string,value:any){await info.attach(name,{body:JSON.stringify(value,null,2),contentType:'application/json'});}
export async function scrollFind(page:Page,locator:ReturnType<Page['getByRole']>,direction=1){
 // Flutter lazy lists only create semantic nodes near the viewport. Wheel the
 // real scroll area until the public locator exists, then use normal clicks.
 for(let n=0;n<24&&!(await locator.count());n++){
  await page.mouse.move(1100,600);await page.mouse.wheel(0,direction*550);await page.waitForTimeout(120);
 }
 await expect(locator.first()).toBeVisible();await locator.first().scrollIntoViewIfNeeded();
}
export async function clock(request:APIRequestContext,endpoint:string,input:any){
 const control=JSON.parse(fs.readFileSync(controlPath,'utf8'));
 const response=await request.post(control.url+endpoint,{headers:{'x-control-key':control.key},data:input});
 const result=await response.json();expect(response.ok(),`Test clock: ${result.error||''}`).toBe(true);return result;
}
