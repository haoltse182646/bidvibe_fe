import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,attachState,runtimeErrors} from '../support/ui';
import {state,updateState,waitBusinessResponse,get,evidence,scrollFind} from '../support/business';

test('PW-APP-01: appraiser approves the new listing and returns to the queue without runtime errors',async({page,request},info)=>{
 const s=state();test.skip(!s.listingSubmitted,'BLOCKED: no submitted E2E listing from seller UI.');
 test.skip(!!s.auctionId,'Already approved in a prior run; do not repeat appraisal.');
 const errors=runtimeErrors(page);
 const session=await login(page,accounts.find(a=>a.role==='appraiser')!);
 const target=page.getByRole('button',{name:new RegExp(s.title)});
 await scrollFind(page,target);await target.click();
 const approve=page.getByRole('button',{name:'Duyệt và mở phiên',exact:true});await scrollFind(page,approve);
 await approve.click();
 const response=await waitBusinessResponse(page,`/api/appraisals/${s.listingId}/decision`,()=>page.getByRole('button',{name:'Duyệt',exact:true}).click());
 expect(response.status).toBe(201);expect(response.success).toBe(true);
 const auctionId=String(response.data.auctionId);updateState({auctionId,appraisalBackendApproved:true});
 const listing=await get(request,session.token!,`/api/appraisals/${s.listingId}`);expect(listing.status).toBe('live');
 await evidence(info,'approval-backend-result',{listingId:s.listingId,auctionId,listingStatus:listing.status});
 await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('Hàng chờ');
 await attachState(page,info,'queue-after-approval');
 await evidence(info,'runtime-errors',{errors});
 expect(errors,'Frontend must refresh the queue without a Flutter exception').toEqual([]);
 updateState({appraisalUiPassed:true});
});
