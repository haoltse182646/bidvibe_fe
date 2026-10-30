import {test,expect} from '@playwright/test';
import {accounts,apiURL} from '../support/config';
import {state,updateState,get,evidence,fixturePrefix} from '../support/business';
test('SETUP-ADM-01: API prepares a separate live fixture for moderation/dispute UI tests',async({request},info)=>{
 test.skip(!!state().admin?.auctionId,'Admin fixture already prepared.');
 const token=async(key:string)=>{
  const a=accounts.find(x=>x.key===key)!;const r=await request.post(apiURL+`/api/auth/${a.role==='appraiser'?'ops/':''}login`,{data:{email:a.email,password:a.password}});const b=await r.json();expect(b.success).toBe(true);return b.data.token;
 };
 const seller=await token('SELLER');const appraiser=await token('APPRAISER');
 const post=async(t:string,url:string,data:any,status:number)=>{const r=await request.post(apiURL+url,{headers:{Authorization:`Bearer ${t}`},data});const b=await r.json();expect(r.status(),b.error?.code).toBe(status);expect(b.success).toBe(true);return b.data;};
 const original=await get(request,seller,'/api/listings/mine?limit=100');const photo=original.listings.find((x:any)=>String(x.id)===String(state().listingId)).photos[0].url;
 const title=`${fixturePrefix}${Date.now()}_AdminDispute`;
 const draft=await post(seller,'/api/listings',{title,categoryCode:'shoes',startingPrice:10000,durationHours:1,description:'Dedicated Playwright moderation/dispute fixture',condition:'E2E test only'},201);
 updateState({admin:{title,listingId:String(draft.id)}});
 await post(seller,`/api/listings/${draft.id}/photos`,{url:photo},201);await post(seller,`/api/listings/${draft.id}/submit`,{},200);
 const approved=await post(appraiser,`/api/appraisals/${draft.id}/decision`,{decision:'approve',reason:'E2E fixture preparation'},201);
 updateState({admin:{...state().admin,auctionId:String(approved.auctionId)}});
 await evidence(info,'API-fixture-setup',{classification:'API test data setup, NOT UI E2E listing coverage',...state().admin});
});
