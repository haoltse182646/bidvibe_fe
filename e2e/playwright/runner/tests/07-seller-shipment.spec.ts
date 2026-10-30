import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,runtimeErrors} from '../support/ui';
import {state,updateState,get,evidence,waitBusinessResponse} from '../support/business';

test('PW-SHIP-01: seller marks only the test order as sent to the warehouse',async({page,request},info)=>{
 const s=state();test.skip(!s.paid,'BLOCKED: the test order has not been paid.');test.skip(!!s.sentToWarehouse,'Shipment already submitted.');
 const errors=runtimeErrors(page);await login(page,accounts.find(a=>a.role==='seller')!);
 await page.getByRole('tab',{name:'Gửi kho',exact:true}).click();
 await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain(s.title);
 const send=page.getByRole('button',{name:'Tôi đã gửi hàng đến kho',exact:true});
 expect(await send.count(),'Refusing to choose ambiguously between multiple seller orders').toBe(1);
 const result=await waitBusinessResponse(page,`/api/orders/${s.orderId}/ship-to-warehouse`,()=>send.click());
 expect(result.status).toBe(200);expect(result.success).toBe(true);updateState({sentToWarehouse:true});
 await evidence(info,'seller-shipment',{orderId:s.orderId,response:result.data});expect(errors).toEqual([]);
});
