import {expect, type Page} from '@playwright/test';
import {apiURL} from './config';
import {scrollFind} from './business';

export async function openFixtureAuction(
  page: Page,
  fixture: {title: string; auctionId: string},
): Promise<void> {
  expect(fixture.title, 'Fixture title is required').toBeTruthy();
  expect(fixture.auctionId, 'Fixture auction ID is required').toMatch(/^\d+$/);
  await page.bringToFront();
  await page.getByRole('tab', {name: 'Khám phá', exact: true}).click();

  const search = page.getByRole('textbox', {
    name: 'Tìm theo tên sản phẩm', exact: true,
  });
  await scrollFind(page, search, -1);
  await search.click();
  await search.focus();
  await expect(search).toBeFocused();
  await search.press('ControlOrMeta+A');
  await search.press('Backspace');
  await search.pressSequentially(fixture.title, {delay: 20});
  // Check the native editing input while focused. Flutter Web may reset its
  // accessibility input when focus moves, despite retaining controller text.
  await expect(search).toHaveValue(fixture.title);

  // Await this exact search, not an earlier unfiltered discovery response.
  const [response] = await Promise.all([
    page.waitForResponse(r => {
      const url = new URL(r.url());
      return url.origin === new URL(apiURL).origin &&
        url.pathname === '/api/auctions' &&
        url.searchParams.get('q') === fixture.title &&
        r.request().method() === 'GET';
    }),
    page.getByRole('button', {name: 'Tìm kiếm', exact: true}).click(),
  ]);
  expect(response.status()).toBe(200);
  const result = await response.json();
  expect(result.success).toBe(true);
  expect(result.data.auctions, 'Unique fixture search must return one auction').toHaveLength(1);
  expect(String(result.data.auctions[0].id)).toBe(fixture.auctionId);
  expect(result.data.auctions[0].title).toBe(fixture.title);

  // Wait for Flutter to replace the old list before clicking. Never use first().
  const open = page.getByRole('button', {
    name: 'Xem chi tiết phiên', exact: true,
  });
  await scrollFind(page, open);
  await expect(open, 'Filtered discovery must expose one detail action').toHaveCount(1);
  await open.click();
  await expect(page.getByRole('heading', {
    name: `Phiên #${fixture.auctionId}`, exact: true,
  })).toBeVisible();
}
