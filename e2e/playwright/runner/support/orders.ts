import {expect,type Page} from '@playwright/test';
import {scrollFind} from './business';
export async function openBuyerOrder(page:Page,title:string){
 await page.getByRole('tab',{name:'Hồ sơ',exact:true}).click();
 const order=page.getByRole('button',{name:new RegExp(title)});await scrollFind(page,order);await order.click();
 await expect(page.getByRole('heading',{name:/Đơn hàng #/})).toBeVisible();
}
