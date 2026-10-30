import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login} from '../support/ui';
import {state,evidence,scrollFind,waitBusinessResponse,get} from '../support/business';
test('PW-BLOCK-01: previously restricted bidder receives the correct reason when joining',async({page,request},info)=>{
 const s=state().admin;test.skip(!s?.auctionId,'BLOCKED: active moderation fixture required.');
 const session=await login(page,accounts.find(a=>a.key==='BIDDER_B')!);
 const wallet=await get(request,session.token!,'/api/wallet');
 test.skip(!wallet.joinBlockedUntil||new Date(wallet.joinBlockedUntil).getTime()<=Date.now(),'NOT COVERED: supplied bidder has no active JOIN_BLOCKED restriction.');
 await page.getByRole('textbox',{name:'Tìm theo tên sản phẩm',exact:true}).fill(s.title);await page.getByRole('button',{name:'Tìm kiếm',exact:true}).click();
 const open=page.getByRole('button',{name:'Xem chi tiết phiên',exact:true});await scrollFind(page,open);await open.click();
 const join=page.getByRole('button',{name:'Đặt cọc tham gia',exact:true});await scrollFind(page,join);await join.click();
 const rejected=await waitBusinessResponse(page,`/api/auctions/${s.auctionId}/join`,()=>page.getByRole('button',{name:'Xác nhận đặt cọc',exact:true}).click());
 expect(rejected.status).toBe(403);expect(rejected.error.code).toBe('JOIN_BLOCKED');
 await evidence(info,'known-business-rejection',{httpStatus:rejected.status,code:rejected.error.code,message:rejected.error.message});
 await expect.poll(()=>page.locator('body').ariaSnapshot(),{timeout:5000}).toContain(rejected.error.message);
});
