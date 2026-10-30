import {test,expect} from '@playwright/test';
import {accounts,apiURL} from '../support/config';
import {state,updateState,freshAccount,get,evidence,clock} from '../support/business';
test('SETUP-DISP-01: API closes and pays only the admin fixture for dispute UI coverage',async({request},info)=>{
 test.setTimeout(90_000);const s=state();const f=s.admin;test.skip(!f?.auctionId,'BLOCKED: moderation fixture required.');test.skip(!!f.orderId,'Dispute order already prepared.');
 const account=freshAccount();const r=await request.post(apiURL+'/api/auth/login',{data:{email:account.email,password:account.password}});const b=await r.json();expect(b.success).toBe(true);const token=b.data.token;
 const post=async(url:string,data:any,code=200)=>{const r=await request.post(apiURL+url,{headers:{Authorization:`Bearer ${token}`},data});const b=await r.json();expect(r.status(),b.error?.code).toBe(code);expect(b.success).toBe(true);return b.data;};
 const detail=await get(request,token,`/api/auctions/${f.auctionId}`);expect(detail.paused).toBe(false);
 await post(`/api/auctions/${f.auctionId}/join`,{},201);await post('/api/bids',{auctionId:f.auctionId,amount:detail.minNextBid},201);
 await clock(request,'/register',{auctionId:f.auctionId,sellerId:s.sellerId,title:f.title,token});await clock(request,'/end-soon',{auctionId:f.auctionId});
 await expect.poll(async()=>{await clock(request,'/close-expired',{auctionId:f.auctionId});return(await get(request,token,`/api/auctions/${f.auctionId}`)).status;},{timeout:40_000,intervals:[1000,2000,3000]}).toBe('ended');
 const orders=await get(request,token,'/api/orders/mine');const order=orders.orders.find((o:any)=>String(o.auctionId)===f.auctionId);expect(order).toBeTruthy();
 updateState({admin:{...state().admin,orderId:String(order.id)}});
 await post(`/api/orders/${order.id}/shipping-address`,{addressId:s.addressId});
 await post(`/api/orders/${order.id}/pay`,{method:'qr'});
 updateState({admin:{...state().admin,paid:true}});
 await evidence(info,'dispute-fixture-preparation',{classification:'API preparation, NOT UI auction/payment coverage',orderId:String(order.id),auctionId:f.auctionId,method:'qr (simulated)',addressId:s.addressId});
});
