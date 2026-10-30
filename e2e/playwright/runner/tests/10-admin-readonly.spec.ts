import {test,expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login,runtimeErrors,attachState,logout} from '../support/ui';
import {get,evidence} from '../support/business';

test('PW-ADMIN-01: administrator opens dashboard, flags, disputes, report and accounts',async({page,request},info)=>{
 const errors=runtimeErrors(page);const session=await login(page,accounts.find(a=>a.role==='admin')!);
 const dashboard=await get(request,session.token!,'/api/admin/dashboard');
 await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain('Tổng quan vận hành');
 await evidence(info,'dashboard-api',{auctions:dashboard.auctions,orders:dashboard.orders,flags:dashboard.flags,disputes:dashboard.disputes});
 for(const [tab,title,endpoint]of [['Cờ','Cờ phiên','/api/admin/flags'],['Tranh chấp','Tranh chấp','/api/admin/disputes'],['Báo cáo','Báo cáo tuần','/api/admin/report/weekly'],['Tài khoản','Tài khoản','/api/admin/accounts']]){
  await page.getByRole('tab',{name:tab,exact:true}).click();
  await get(request,session.token!,endpoint);
  await expect.poll(()=>page.locator('body').ariaSnapshot()).toContain(title);
  await attachState(page,info,`admin-${tab}`);
 }
 expect(errors).toEqual([]);await logout(page);
});
