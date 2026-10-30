import {expect, type Page, type TestInfo} from '@playwright/test';
import {apiURL,type Account} from './config';

export async function enableAccessibility(page:Page){
 const placeholder=page.locator('flt-semantics-placeholder');
 if(await placeholder.count()){
  await placeholder.focus();await placeholder.press('Enter');
 }
}
export async function openApp(page:Page){
 await page.bringToFront();
 await page.goto('/');
 await page.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:60_000});
 await enableAccessibility(page);
 await expect(page.getByRole('textbox',{name:'Email',exact:true})).toBeVisible();
}
export async function login(page:Page,account:Account){
 expect(account.email.length>0&&account.password.length>0,'Missing test account configuration').toBeTruthy();
 await openApp(page);
 const email=page.getByRole('textbox',{name:'Email',exact:true});
 await email.click();await email.pressSequentially(account.email,{delay:20});
 const password=page.getByRole('textbox',{name:'Mật khẩu',exact:true});
 await password.click();await password.pressSequentially(account.password,{delay:20});await password.press('Tab');
 const ops=page.getByRole('checkbox',{name:'Đăng nhập nhân viên / quản trị',exact:true});
 if(!['bidder','seller'].includes(account.role)) await ops.check();
 const meResponse=page.waitForResponse(r=>r.url()===`${apiURL}/api/me`&&r.request().method()==='GET',{timeout:45_000});
 await page.getByRole('button',{name:'Đăng nhập',exact:true}).click();
 const response=await meResponse;expect(response.status()).toBe(200);
 const me=await response.json();expect(me.success).toBe(true);
 expect(me.data.role).toBe(account.role);
 expect(me.data.email?.toLowerCase()===account.email.toLowerCase(),'The signed-in identity must match the configured account').toBe(true);
 await expect(page.getByRole('button',{name:'Đăng xuất',exact:true})).toBeVisible();
 await expect.poll(()=>page.locator('body').ariaSnapshot(),{timeout:30_000}).toContain(account.home);
 // Token stays in memory only; never attach the login response or headers.
 const authHeader=response.request().headers()['authorization'];
 return {id:String(me.data.id),role:me.data.role,token:authHeader?.replace(/^Bearer /,'')};
}
export async function logout(page:Page){
 await page.getByRole('button',{name:'Đăng xuất',exact:true}).click();
 await expect(page.getByRole('textbox',{name:'Email',exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'Đăng xuất',exact:true})).toHaveCount(0);
}
export function runtimeErrors(page:Page){
 const errors:string[]=[];
 page.on('pageerror',e=>errors.push(e.stack||e.message));
 page.on('console',m=>{
  const text=m.text();
  if(/EXCEPTION CAUGHT BY|setState\(\) callback argument returned a Future|A RenderFlex overflowed/.test(text))errors.push(text);
 });
 return errors;
}
export async function attachState(page:Page,info:TestInfo,name:string){
 await info.attach(name,{body:await page.locator('body').ariaSnapshot(),contentType:'text/plain'});
}

