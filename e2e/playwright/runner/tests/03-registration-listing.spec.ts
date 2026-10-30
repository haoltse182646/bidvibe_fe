import fs from 'node:fs';
import crypto from 'node:crypto';
import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {openApp,login,logout,attachState,runtimeErrors} from '../support/ui';
import {state,updateState,freshPath,runDir,fixturePrefix,waitBusinessResponse,get,evidence,scrollFind} from '../support/business';

test('PW-REG-01: register a fresh bidder through the UI',async({page},info)=>{
 test.skip(fs.existsSync(freshPath),'Fresh account already exists for this run; do not register it twice.');
 const account={key:'FRESH_BIDDER_B',role:'bidder',home:'Khám phá phiên đấu giá',email:`e2e_pw_${Date.now()}@example.com`,password:`Pw_${crypto.randomBytes(10).toString('hex')}!`};
 await openApp(page);
 await page.getByRole('button',{name:'Chưa có tài khoản? Đăng ký',exact:true}).click();
 await expect(page.getByRole('textbox',{name:'Họ và tên',exact:true})).toBeVisible();
 await page.getByRole('textbox',{name:'Họ và tên',exact:true}).fill('E2E Playwright Bidder B');
 await page.getByRole('textbox',{name:'Email',exact:true}).fill(account.email);
 await page.getByRole('textbox',{name:'Mật khẩu',exact:true}).fill(account.password);
 await page.getByRole('textbox',{name:'Nhập lại mật khẩu',exact:true}).fill(account.password);
 const result=await waitBusinessResponse(page,'/api/auth/register',()=>page.getByRole('button',{name:'Tạo tài khoản',exact:true}).click());
 expect(result.status).toBe(201);expect(result.success).toBe(true);
 fs.mkdirSync(runDir,{recursive:true});fs.writeFileSync(freshPath,JSON.stringify(account,null,2));
 await expect(page.getByRole('button',{name:'Đăng xuất',exact:true})).toBeVisible();
 await evidence(info,'registration-result',{httpStatus:result.status,role:'bidder',accountAlias:account.key});
 await logout(page);
});

test('PW-LIST-01: seller uploads a real file and submits a new listing',async({page,request},info)=>{
 test.skip(!!state().listingId,'Listing already created; do not duplicate a mutating scenario.');
 const errors=runtimeErrors(page);
 const seller=accounts.find(a=>a.key==='SELLER')!;
 const session=await login(page,seller);expect(session.token).toBeTruthy();
 await page.getByRole('tab',{name:'Tạo mới',exact:true}).click();
 await attachState(page,info,'seller-create-before-input');
 const title=`${fixturePrefix}${Date.now()}_Main`;
 updateState({title,sellerId:session.id,createdAt:new Date().toISOString()});
 const chooserPromise=page.waitForEvent('filechooser',{timeout:10_000});
 await page.getByRole('button',{name:'',exact:true}).first().click();
 const chooser=await chooserPromise;await chooser.setFiles('assets/e2e-product.png');
 await page.getByRole('textbox',{name:'Ví dụ: Giày da thủ công, size 41',exact:true}).fill(title);
 const price=page.getByRole('textbox',{name:'Nhập giá khởi điểm',exact:true});
 await scrollFind(page,price);await price.click();
 await price.pressSequentially('10000',{delay:100});
 await expect(price).toHaveValue('10000');
 await price.press('Tab');
 const submit=page.getByRole('button',{name:'Gửi để thẩm định',exact:true});await scrollFind(page,submit);
 await expect(submit).toBeEnabled();
 const submitted=await waitBusinessResponse(page,'/api/listings',()=>submit.click());
 expect(submitted.status).toBe(201);expect(submitted.success).toBe(true);
 const listingId=String(submitted.data.id);updateState({listingId});
 await expect.poll(async()=>{
  const data=await get(request,session.token!,`/api/listings/mine?limit=100`);
  return data.listings.find((x:any)=>String(x.id)===listingId)?.status;
 },{timeout:30_000}).toBe('pending_appraisal');
 const data=await get(request,session.token!,`/api/listings/mine?limit=100`);const listing=data.listings.find((x:any)=>String(x.id)===listingId);
 expect(listing.photos.length).toBeGreaterThan(0);updateState({listingSubmitted:true});
 await evidence(info,'submitted-listing',{listingId,title,status:listing.status,photoCount:listing.photos.length,photoInput:'Real browser file chooser via Playwright setFiles'});
 expect(errors).toEqual([]);
});
