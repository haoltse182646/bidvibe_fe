import {test,expect} from '@playwright/test';
import {login,runtimeErrors,attachState} from '../support/ui';
import {state,updateState,freshAccount,get,evidence,scrollFind,waitBusinessResponse} from '../support/business';
import {openBuyerOrder} from '../support/orders';

test('PW-PAY-01: winner creates/selects an address and pays the order from the wallet',async({page,request},info)=>{
 test.setTimeout(120_000);const s=state();test.skip(!s.orderId,'BLOCKED: auction winner/order has not been created.');
 const errors=runtimeErrors(page);const session=await login(page,freshAccount());
 const order=await get(request,session.token!,`/api/orders/${s.orderId}`);test.skip(order.paymentStatus==='paid','Already paid; never send payment twice.');
 expect(order.paymentStatus).toBe('awaiting_payment');
 await openBuyerOrder(page,s.title);
 if(!order.shippingAddress){
  const choose=page.getByRole('button',{name:/Chưa có địa chỉ nhận hàng/});await scrollFind(page,choose);await choose.click();
  await page.getByRole('button',{name:'Thêm địa chỉ mới',exact:true}).click();
  for(const [label,value] of [['Họ và tên người nhận *','E2E Playwright'],['Số điện thoại *','0900000000'],['Tỉnh / thành phố *','Ho Chi Minh'],['Địa chỉ cụ thể *','E2E test only - 1 Test Street']]){
   const input=page.getByRole('textbox',{name:new RegExp('^'+label.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'))});
   await scrollFind(page,input);await input.click();await input.pressSequentially(value,{delay:25});await input.press('Tab');await expect(input).toHaveValue(value);
  }
  const save=page.getByRole('button',{name:'Lưu địa chỉ',exact:true});await scrollFind(page,save);
  const created=await waitBusinessResponse(page,'/api/addresses',()=>save.click());expect(created.status).toBe(201);expect(created.success).toBe(true);
  updateState({addressId:String(created.data.id)});
  const select=page.getByRole('button',{name:'Chọn địa chỉ của E2E Playwright',exact:true});await select.click();
  const attached=await waitBusinessResponse(page,`/api/orders/${s.orderId}/shipping-address`,()=>page.getByRole('button',{name:'Dùng địa chỉ này',exact:true}).click());
  expect(attached.success).toBe(true);
 }
 const walletMethod=page.getByRole('button',{name:/Ví BidVibe/});await scrollFind(page,walletMethod);await walletMethod.click();
 const before=await get(request,session.token!,'/api/wallet');const current=await get(request,session.token!,`/api/orders/${s.orderId}`);
 const pay=page.getByRole('button',{name:/^Thanh toán \d/});await expect(pay).toBeEnabled();await pay.click();
 const result=await waitBusinessResponse(page,`/api/orders/${s.orderId}/pay`,()=>page.getByRole('button',{name:'Thanh toán',exact:true}).click());
 expect(result.status).toBe(200);expect(result.success).toBe(true);updateState({paid:true});
 const after=await get(request,session.token!,'/api/wallet');const paid=await get(request,session.token!,`/api/orders/${s.orderId}`);
 expect(paid.paymentStatus).toBe('paid');expect(after.balance).toBe(before.balance-current.amountToPay);expect(after.held).toBe(before.held-current.depositApplied);
 await evidence(info,'wallet-payment',{orderId:s.orderId,amountToPay:current.amountToPay,depositApplied:current.depositApplied,before,after,paymentStatus:paid.paymentStatus,shippingAddressId:paid.shippingAddress?.id});
 await attachState(page,info,'paid-order-screen');expect(errors).toEqual([]);
});
