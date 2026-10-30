import { test, expect } from '@playwright/test';

test('WEB-READY-01: Flutter Web exposes an accessible login form', async ({ page }, testInfo) => {
  const errors: string[]=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({state:'attached',timeout:60_000});
  // Flutter intentionally places this assistive-technology entry point
  // outside the visual viewport. Enable it with the keyboard, not coordinates.
  await placeholder.focus();
  await placeholder.press('Enter');
  await expect(page.getByRole('textbox')).toHaveCount(2);
  await expect(page.getByRole('button',{name:'Đăng nhập',exact:true})).toBeVisible();
  await expect(page.getByRole('checkbox')).toHaveCount(1);
  await testInfo.attach('login-accessibility-tree',{body:await page.locator('body').ariaSnapshot(),contentType:'text/plain'});
  await testInfo.attach('login-screenshot',{body:await page.screenshot(),contentType:'image/png'});
  expect(errors,'Uncaught Flutter/browser errors during initialization').toEqual([]);
});
