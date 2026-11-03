import {test, expect} from '@playwright/test';
import {accounts} from '../support/config';
import {login, runtimeErrors} from '../support/ui';
import {
  state, updateState, evidence, waitBusinessResponse, scrollFind,
} from '../support/business';

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

test('PW-SHIP-01: seller marks only the test order as sent to the warehouse', async ({page}, info) => {
  const s = state();
  test.skip(!s.paid, 'BLOCKED: the test order has not been paid.');
  test.skip(!!s.sentToWarehouse, 'Shipment already submitted.');
  expect(s.orderId, 'A paid fixture must have an order ID').toBeTruthy();
  expect(s.title, 'A paid fixture must have a title').toBeTruthy();

  const errors = runtimeErrors(page);
  await login(page, accounts.find(a => a.role === 'seller')!);
  await page.getByRole('tab', {name: 'Gửi kho', exact: true}).click();

  // Match both the unique fixture title and order number. Never select the
  // first global button: older paid orders can have the same action label.
  const card = page.getByRole('group', {
    name: new RegExp(
      `^${escapeRegex(s.title)}\\s.*Đơn #${escapeRegex(String(s.orderId))}(?:\\D|$)`,
    ),
  });
  await scrollFind(page, card);
  await expect(card, 'Select exactly the current E2E order').toHaveCount(1);

  const send = card.getByRole('button', {
    name: 'Tôi đã gửi hàng đến kho', exact: true,
  });
  await expect(send).toHaveCount(1);
  await expect(send).toBeEnabled();

  const result = await waitBusinessResponse(
    page,
    `/api/orders/${s.orderId}/ship-to-warehouse`,
    () => send.click(),
  );
  expect(result.status).toBe(200);
  expect(result.success).toBe(true);
  updateState({sentToWarehouse: true});
  await evidence(info, 'seller-shipment', {
    orderId: s.orderId, response: result.data,
  });
  expect(errors).toEqual([]);
});
