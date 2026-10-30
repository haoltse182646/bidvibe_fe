import {test,expect} from '@playwright/test';
import {accounts,apiURL} from '../support/config';
import {login,runtimeErrors,attachState} from '../support/ui';
import {state,updateState,freshAccount,get,evidence,scrollFind,waitBusinessResponse} from '../support/business';
import {openBuyerOrder} from '../support/orders';

test('PW-DISPUTE-01: buyer opens a dispute through the UI',async({page,request},info)=>{
 const s=state().admin;test.skip(!s?.paid,'BLOCKED: paid dispute fixture required.');test.skip(!!s.disputeId,'Dispute already opened.');
 const session=await login(page,freshAccount());await openBuyerOrder(page,s.title);
 const open=page.getByRole('button',{name:'Hàng có vấn đề? Mở tranh chấp',exact:true});await scrollFind(page,open);await open.click();
 await page.getByRole('button',{name:'Hàng không đúng mô tả',exact:true}).click();
 const text=page.getByRole('textbox',{name:'Mô tả cụ thể vấn đề bạn gặp phải…',exact:true});await scrollFind(page,text);await text.click();await text.pressSequentially('E2E dispute only: test item does not match its description.',{delay:15});await text.press('Tab');
 const response=await waitBusinessResponse(page,'/api/disputes',()=>page.getByRole('button',{name:'Gửi tranh chấp',exact:true}).click());
 expect(response.status).toBe(201);expect(response.success).toBe(true);
 updateState({admin:{...s,disputeId:String(response.data.id)}});
 const order=await get(request,session.token!,`/api/orders/${s.orderId}`);expect(order.payoutStatus).toBe('disputed');
 await evidence(info,'opened-dispute',{id:String(response.data.id),orderId:s.orderId,payoutStatus:order.payoutStatus});
});

test('PW-REFUND-01: admin refunds the dispute; logged-in buyer receives realtime notification and wallet credit',async({browser,request},info)=>{
 const s=state().admin;test.skip(!s?.disputeId,'BLOCKED: no opened dispute fixture.');test.skip(!!s.refunded,'Refund already executed.');
 const buyerContext=await browser.newContext();const adminContext=await browser.newContext();const buyer=await buyerContext.newPage();const admin=await adminContext.newPage();
 const incoming:any[]=[];buyer.on('websocket',ws=>ws.on('framereceived',frame=>{
  if(typeof frame.payload!=='string'||!frame.payload.startsWith('42'))return;
  try{const [event,data]=JSON.parse(frame.payload.slice(2));if(event==='notification:new')incoming.push(data);}catch{}
 }));
 const errors=runtimeErrors(admin);
 try{
  const bs=await login(buyer,freshAccount());const before=await get(request,bs.token!,'/api/wallet');
  await buyer.getByRole('tab',{name:/Thông báo/}).click();
  const as=await login(admin,accounts.find(a=>a.role==='admin')!);await admin.getByRole('tab',{name:'Tranh chấp',exact:true}).click();
  const tile=admin.getByRole('button',{name:new RegExp(s.title)});await scrollFind(admin,tile);await tile.click();
  const refund=admin.getByRole('button',{name:'Hoàn tiền người mua',exact:true});await scrollFind(admin,refund);await refund.click();
  const resolved=await waitBusinessResponse(admin,`/api/admin/disputes/${s.disputeId}/resolve`,()=>admin.getByRole('button',{name:'Xác nhận',exact:true}).click());
  expect(resolved.status).toBe(200);expect(resolved.success).toBe(true);updateState({admin:{...s,refunded:true}});
  const after=await get(request,bs.token!,'/api/wallet');const dispute=await get(request,as.token!,`/api/admin/disputes`);
  const matching=dispute.disputes.find((d:any)=>String(d.id)===s.disputeId);expect(matching.status).toBe('resolved');expect(after.balance).toBeGreaterThan(before.balance);
  await buyer.bringToFront();
  await expect.poll(()=>incoming.some(n=>n.type==='refund'&&String(n.data?.disputeId)===s.disputeId),{timeout:20_000}).toBe(true);
  const event=incoming.find(n=>n.type==='refund'&&String(n.data?.disputeId)===s.disputeId);
  await expect.poll(()=>buyer.locator('body').ariaSnapshot()).toContain('hoàn');
  updateState({admin:{...state().admin,realtimeRefundReceived:true}});
  await evidence(info,'refund-wallet-and-live-notification',{orderId:s.orderId,disputeId:s.disputeId,before,after,notification:{id:event.id,type:event.type,data:event.data},classification:'WebSocket frame received while buyer remained signed in; no manual reload'});
  await attachState(buyer,info,'buyer-notification-screen');await evidence(info,'admin-runtime-errors',{errors});
  expect(errors,'Admin must return to the dispute queue without a runtime error').toEqual([]);
 }finally{await buyerContext.close();await adminContext.close();}
});
