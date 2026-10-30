import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,runtimeErrors,attachState} from '../support/ui';
import {state,updateState,get,evidence,scrollFind,waitBusinessResponse} from '../support/business';

test('PW-REPORT-01: bidder reports only the new admin test auction through the UI',async({page},info)=>{
 const s=state().admin;test.skip(!s?.auctionId,'BLOCKED: admin fixture unavailable.');test.skip(!!s.reported,'Report already submitted.');
 await login(page,accounts.find(a=>a.key==='BIDDER_A')!);
 await page.getByRole('textbox',{name:'Tìm theo tên sản phẩm',exact:true}).fill(s.title);await page.getByRole('button',{name:'Tìm kiếm',exact:true}).click();
 const open=page.getByRole('button',{name:'Xem chi tiết phiên',exact:true});await scrollFind(page,open);await open.click();
 await page.getByRole('button',{name:'Báo cáo phiên',exact:true}).click();
 const reason=page.getByRole('textbox',{name:/^Lý do báo cáo/});await reason.click();await reason.pressSequentially('E2E moderation scenario',{delay:25});await reason.press('Tab');
 const send=page.getByRole('button',{name:'Gửi báo cáo',exact:true});await scrollFind(page,send);await send.click();
 const response=await waitBusinessResponse(page,`/api/auctions/${s.auctionId}/report`,()=>page.getByRole('button',{name:'Xác nhận gửi',exact:true}).click());
 expect(response.status).toBe(201);expect(response.success).toBe(true);updateState({admin:{...s,reported:true}});
 await evidence(info,'report-created',{auctionId:s.auctionId,...response.data});
 await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('Báo cáo đã được ghi nhận');
});

for(const action of [{key:'pause',label:'Tạm dừng phiên',status:'paused'},{key:'verify',label:'Yêu cầu xác minh',status:'verified'},{key:'safe',label:'Đánh dấu an toàn',status:'safe'}]){
 test(`PW-MOD-${action.key}: admin ${action.key} action and queue refresh`,async({page,request},info)=>{
  const s=state().admin;test.skip(!s?.reported,'BLOCKED: no test report submitted.');
  const errors=runtimeErrors(page);const session=await login(page,accounts.find(a=>a.role==='admin')!);
  const flags=await get(request,session.token!,'/api/admin/flags?limit=100');const flag=flags.flags.find((f:any)=>String(f.auctionId||f.auction?.id)===s.auctionId);
  test.skip(!flag,'BLOCKED: fixture flag not found.');test.skip(flag.status==='safe','Already resolved.');
  updateState({admin:{...s,flagId:String(flag.id)}});
  await page.getByRole('tab',{name:'Cờ',exact:true}).click();
  const item=page.getByRole('button',{name:new RegExp(s.title)});await scrollFind(page,item);await item.click();
  const button=page.getByRole('button',{name:action.label,exact:true});await scrollFind(page,button);
  const r=await waitBusinessResponse(page,`/api/admin/flags/${flag.id}/action`,()=>button.click());expect(r.status).toBe(200);expect(r.success).toBe(true);
  const detail=await get(request,session.token!,`/api/auctions/${s.auctionId}`);
  if(action.key==='pause')expect(detail.paused).toBe(true);else expect(detail.paused).toBe(false);
  updateState({admin:{...state().admin,moderationAction:action.key}});
  await evidence(info,'moderation-result',{action:action.key,flagId:String(flag.id),flagStatus:r.data.status,auctionId:s.auctionId,paused:detail.paused});
  await attachState(page,info,'admin-after-action');expect(errors,'Admin queue refresh must not throw').toEqual([]);
 });
}
