import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,attachState,runtimeErrors} from '../support/ui';
import {state,updateState,get,evidence,scrollFind,waitBusinessResponse} from '../support/business';

const steps=[
 {id:'PW-WH-01',action:'receive',before:'in_transit_to_warehouse',after:'inspecting',button:'Xác nhận kho đã nhận hàng'},
 {id:'PW-WH-02',action:'inspect',before:'inspecting',after:'inspected',button:'Lưu kết quả kiểm định'},
 {id:'PW-WH-03',action:'pack',before:'inspected',after:'packed',button:'Xác nhận đóng gói'},
 {id:'PW-WH-04',action:'ship',before:'packed',after:'shipped',button:'Gửi cho đơn vị vận chuyển'},
 {id:'PW-WH-05',action:'deliver',before:'shipped',after:'delivered',button:'Xác nhận đã giao'},
];
for(const step of steps){
 test(`${step.id}: warehouse ${step.action} updates the order without a misleading UI error`,async({page,request},info)=>{
  const s=state();test.skip(!s.sentToWarehouse,'BLOCKED: seller has not sent this test order to the warehouse.');
  const errors=runtimeErrors(page);const session=await login(page,accounts.find(a=>a.role==='warehouse')!);
  const before=await get(request,session.token!,`/api/warehouse/orders?limit=100`);
  const order=before.orders.find((o:any)=>String(o.id)===String(s.orderId));
  test.skip(!order||order.stage!==step.before,`BLOCKED/already executed: expected ${step.before}, observed ${order?.stage}`);
  const tile=page.getByRole('button',{name:new RegExp(s.title)});await scrollFind(page,tile);await tile.click();
  const action=page.getByRole('button',{name:step.button,exact:true});await scrollFind(page,action);
  let result;
  if(step.action==='ship'){
   await action.click();
   await page.getByRole('textbox',{name:'Đơn vị vận chuyển',exact:true}).fill('E2E simulated carrier');
   await page.getByRole('textbox',{name:'Mã vận đơn',exact:true}).fill(`E2E-PW-${s.orderId}`);
   result=await waitBusinessResponse(page,`/api/warehouse/orders/${s.orderId}/ship`,()=>page.getByRole('button',{name:'Xác nhận gửi',exact:true}).click());
  }else{
   result=await waitBusinessResponse(page,`/api/warehouse/orders/${s.orderId}/${step.action}`,()=>action.click());
  }
  expect(result.status).toBe(200);expect(result.success).toBe(true);
  const after=await get(request,session.token!,`/api/warehouse/orders?limit=100`);const changed=after.orders.find((o:any)=>String(o.id)===String(s.orderId));
  expect(changed.stage).toBe(step.after);updateState({warehouseStage:changed.stage});
  await evidence(info,'warehouse-transition',{orderId:s.orderId,action:step.action,before:step.before,after:changed.stage});
  await expect.poll(()=>page.locator('body').ariaSnapshot()).not.toContain(step.button);
  await attachState(page,info,'warehouse-after-action');
  const snapshot=await page.locator('body').ariaSnapshot();
  expect(snapshot,'A successful warehouse update must not display a failure message').not.toContain('Không cập nhật được đơn hàng.');
  expect(errors).toEqual([]);
 });
}
