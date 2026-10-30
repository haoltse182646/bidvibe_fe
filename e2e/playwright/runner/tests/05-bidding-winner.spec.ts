import fs from 'node:fs';
import {test,expect,type Page} from '@playwright/test';
import {accounts,apiURL} from '../support/config';
import {login,attachState,runtimeErrors} from '../support/ui';
import {state,updateState,freshAccount,get,evidence,scrollFind,waitBusinessResponse,clock,controlPath} from '../support/business';

async function topup(page:Page,amount:number){
 await page.bringToFront();
 await page.getByRole('tab',{name:'Ví',exact:true}).click();
 const field=page.getByRole('textbox',{name:/^Số tiền \(VND\)/});await scrollFind(page,field);await expect(field).toBeEnabled();
 await field.click();await field.pressSequentially(String(amount),{delay:60});await field.press('Tab');
 const submit=page.getByRole('button',{name:'Nạp tiền',exact:true});await scrollFind(page,submit);await submit.click();
 const result=await waitBusinessResponse(page,'/api/wallet/topup',()=>page.getByRole('button',{name:'Xác nhận',exact:true}).click());
 expect(result.status).toBe(201);expect(result.success).toBe(true);return result.data;
}
async function openAuction(page:Page,title:string){
 await page.bringToFront();
 await page.getByRole('tab',{name:'Khám phá',exact:true}).click();
 const search=page.getByRole('textbox',{name:'Tìm theo tên sản phẩm',exact:true});await scrollFind(page,search,-1);await search.fill(title);
 await page.getByRole('button',{name:'Tìm kiếm',exact:true}).click();
 const open=page.getByRole('button',{name:'Xem chi tiết phiên',exact:true});await scrollFind(page,open);await open.click();
 await expect(page.getByRole('heading',{name:new RegExp('Phiên #')})).toBeVisible();
}
async function join(page:Page,id:string){
 await page.bringToFront();
 const join=page.getByRole('button',{name:'Đặt cọc tham gia',exact:true});await scrollFind(page,join);await join.click();
 const response=await waitBusinessResponse(page,`/api/auctions/${id}/join`,()=>page.getByRole('button',{name:'Xác nhận đặt cọc',exact:true}).click());
 expect(response.status).toBe(201);expect(response.success).toBe(true);return response.data;
}
async function bid(page:Page){
 await page.bringToFront();
 const minimum=page.getByRole('button',{name:'Dùng giá tối thiểu',exact:true});await scrollFind(page,minimum);await expect(minimum).toBeEnabled();await minimum.click();
 await page.getByRole('button',{name:'Đặt giá',exact:true}).click();
 const result=await waitBusinessResponse(page,'/api/bids',()=>page.getByRole('button',{name:'Xác nhận đặt giá',exact:true}).click());
 expect(result.status).toBe(201);expect(result.success).toBe(true);return result.data;
}

test('PW-BID-01: two isolated bidders top up, deposit, compete in real time, and receive the correct winner',async({browser,request},info)=>{
 test.setTimeout(180_000);
 const s=state();test.skip(!s.auctionId,'BLOCKED: a new approved auction is required.');test.skip(!!s.orderId,'Order already generated; do not repeat this mutating journey.');
 test.skip(!fs.existsSync(controlPath),'BLOCKED: user-authorized fixture clock is unavailable.');
 const ca=await browser.newContext({viewport:{width:1440,height:1100}});const cb=await browser.newContext({viewport:{width:1440,height:1100}});
 const a=await ca.newPage();const b=await cb.newPage();const errorsA=runtimeErrors(a);const errorsB=runtimeErrors(b);
 a.setDefaultTimeout(20_000);b.setDefaultTimeout(20_000);
 try{
  const sa=await login(a,accounts.find(x=>x.key==='BIDDER_A')!);const sb=await login(b,freshAccount());
  const beforeA=await get(request,sa.token!,'/api/wallet');const beforeB=await get(request,sb.token!,'/api/wallet');
  expect(beforeA.joinBlockedUntil).toBeNull();expect(beforeB.joinBlockedUntil).toBeNull();
  await test.step('Top up through the UI; no real payment gateway',async()=>{
   await topup(a,10000);await topup(b,200000);
   const wa=await get(request,sa.token!,'/api/wallet');const wb=await get(request,sb.token!,'/api/wallet');
   expect(wa.balance).toBe(beforeA.balance+10000);expect(wb.balance).toBe(beforeB.balance+200000);
   await evidence(info,'wallet-topups',{a:{before:beforeA,after:wa},b:{before:beforeB,after:wb}});
  });
  await ca.tracing.start({screenshots:true,snapshots:true,sources:true});await cb.tracing.start({screenshots:true,snapshots:true,sources:true});
  await openAuction(a,s.title);await openAuction(b,s.title);
  await test.step('Both bidders place deposits through UI confirmations',async()=>{
   const ja=await join(a,s.auctionId);const jb=await join(b,s.auctionId);
   const da=await get(request,sa.token!,`/api/auctions/${s.auctionId}`);const db=await get(request,sb.token!,`/api/auctions/${s.auctionId}`);
   expect(da.joined).toBe(true);expect(db.joined).toBe(true);
   const wa=await get(request,sa.token!,'/api/wallet');const wb=await get(request,sb.token!,'/api/wallet');
   expect(wa.held).toBe(beforeA.held+ja.deposit);expect(wb.held).toBe(beforeB.held+jb.deposit);
   updateState({depositsPlaced:true});await evidence(info,'deposits',{a:ja,b:jb,walletA:wa,walletB:wb});
  });
  await test.step('Bidder B outbids A; A receives the update without reloading',async()=>{
   const first=await bid(a);expect(first.currentPrice).toBe(60000);
   await expect.poll(()=>a.locator('body').ariaSnapshot()).toContain('Bạn đang dẫn đầu');
   const updateA=a.waitForResponse(r=>r.url()===`${apiURL}/api/auctions/${s.auctionId}`&&r.request().method()==='GET');
   const second=await bid(b);expect(second.currentPrice).toBe(110000);
   const refreshed=await (await updateA).json();expect(refreshed.data.currentPrice).toBe(110000);expect(refreshed.data.leading).toBe(false);
   await a.bringToFront();
   await expect.poll(()=>a.locator('body').ariaSnapshot()).toContain('160.000');
   const db=await get(request,sb.token!,`/api/auctions/${s.auctionId}`);expect(db.leading).toBe(true);expect(db.bidCount).toBe(2);
   updateState({bidsPlaced:true,winnerId:sb.id});await evidence(info,'competing-bids',{auctionId:s.auctionId,firstPrice:first.currentPrice,secondPrice:second.currentPrice,bidCount:db.bidCount,aLeading:false,bLeading:db.leading});
  });
  await test.step('TEST DATA CONTROL: shorten only this new E2E auction, then run normal close logic',async()=>{
   await clock(request,'/register',{auctionId:s.auctionId,sellerId:s.sellerId,title:s.title,token:sa.token});
   const timing=await clock(request,'/end-soon',{auctionId:s.auctionId});await evidence(info,'fixture-time-adjustment',{...timing,classification:'Test data preparation, not a user UI action'});
   await expect.poll(async()=>{
    await clock(request,'/close-expired',{auctionId:s.auctionId});return(await get(request,sb.token!,`/api/auctions/${s.auctionId}`)).status;
   },{timeout:45_000,intervals:[1000,2000,3000]}).toBe('ended');
  });
  const ended=await get(request,sb.token!,`/api/auctions/${s.auctionId}`);expect(String(ended.winnerId)).toBe(sb.id);expect(ended.won).toBe(true);
  const orders=await get(request,sb.token!,'/api/orders/mine');const order=orders.orders.find((o:any)=>String(o.auctionId)===String(s.auctionId));expect(order).toBeTruthy();
  updateState({orderId:String(order.id),winnerId:sb.id,winnerAccountAlias:'FRESH_BIDDER_B',auctionEnded:true});
  await evidence(info,'winner-order',{auctionId:s.auctionId,winnerId:sb.id,orderId:String(order.id),paymentStatus:order.paymentStatus});
  await a.mouse.wheel(0,-6000);await b.mouse.wheel(0,-6000);
  await b.bringToFront();
  await expect.poll(()=>b.locator('body').ariaSnapshot()).toContain('Bạn đã thắng phiên này');
  const wa=await get(request,sa.token!,'/api/wallet');expect(wa.held).toBe(beforeA.held);
  await evidence(info,'loser-deposit-refund',{beforeHeld:beforeA.held,afterHeld:wa.held});
  expect(errorsA,'Bidder A runtime errors').toEqual([]);expect(errorsB,'Bidder B runtime errors').toEqual([]);
 }finally{
  await ca.tracing.stop({path:info.outputPath('bidder-a-trace.zip')}).catch(()=>{});await cb.tracing.stop({path:info.outputPath('bidder-b-trace.zip')}).catch(()=>{});
  for(const [name,context]of[['bidder-a',ca],['bidder-b',cb]] as const){const file=info.outputPath(`${name}-trace.zip`);if(fs.existsSync(file))await info.attach(`${name}-trace-private`,{path:file,contentType:'application/zip'});await context.close();}
 }
});
