import {test,expect} from '@playwright/test';
import {login,runtimeErrors} from '../support/ui';
import {state,updateState,freshAccount,get,evidence,waitBusinessResponse} from '../support/business';
import {openBuyerOrder} from '../support/orders';
test('PW-DELIVERY-01: buyer confirms receipt and verifies final order/payout status',async({page,request},info)=>{
 const s=state();test.skip(s.warehouseStage!=='delivered','BLOCKED: test order has not been marked delivered.');
 const errors=runtimeErrors(page);const session=await login(page,freshAccount());
 const before=await get(request,session.token!,`/api/orders/${s.orderId}`);
 await openBuyerOrder(page,s.title);await page.getByRole('button',{name:'Đã nhận hàng',exact:true}).click();
 const result=await waitBusinessResponse(page,`/api/orders/${s.orderId}/confirm-delivery`,()=>page.getByRole('button',{name:'Đã nhận hàng',exact:true}).last().click());
 expect(result.status).toBe(200);expect(result.success).toBe(true);
 const after=await get(request,session.token!,`/api/orders/${s.orderId}`);
 expect(after.payoutStatus).toBe('released');updateState({receiptConfirmed:true});
 await evidence(info,'buyer-receipt',{orderId:s.orderId,before:{paymentStatus:before.paymentStatus,payoutStatus:before.payoutStatus},after:{paymentStatus:after.paymentStatus,payoutStatus:after.payoutStatus,deliveredConfirmedAt:after.deliveredConfirmedAt}});
 expect(errors).toEqual([]);
});
