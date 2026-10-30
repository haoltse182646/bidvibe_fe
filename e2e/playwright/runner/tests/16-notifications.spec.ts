import {test,expect} from '@playwright/test';
import {login,runtimeErrors} from '../support/ui';
import {state,freshAccount,get,evidence,scrollFind} from '../support/business';
test('PW-NOTIFY-01: buyer loads saved shipping notifications and opens the correct order',async({page,request},info)=>{
 const s=state();test.skip(!s.receiptConfirmed,'BLOCKED: delivered/completed test order required.');
 const errors=runtimeErrors(page);const session=await login(page,freshAccount());
 const result=await get(request,session.token!,'/api/notifications?limit=100');
 const notes=(result.notifications||result.items).filter((n:any)=>String(n.data?.orderId)===String(s.orderId));
 expect(notes.filter((n:any)=>n.type==='order').length).toBeGreaterThanOrEqual(3);
 await page.getByRole('tab',{name:/Thông báo/}).click();
 const note=page.getByRole('button',{name:new RegExp(s.title)}).first();await scrollFind(page,note);await note.click();
 await expect(page.getByRole('heading',{name:`Đơn hàng #${s.orderId}`,exact:true})).toBeVisible();
 await evidence(info,'saved-shipping-notifications',{orderId:s.orderId,notifications:notes.map((n:any)=>({id:n.id,type:n.type,title:n.title,data:n.data})),classification:'Persisted notification history and correct UI navigation; realtime delivery tested separately during refund'});
 expect(errors).toEqual([]);
});
