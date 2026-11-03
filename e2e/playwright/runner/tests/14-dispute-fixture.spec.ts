import fs from 'node:fs';
import {test, expect} from '@playwright/test';
import {apiURL} from '../support/config';
import {
  state, updateState, freshAccount, freshPath, get, evidence, clock,
} from '../support/business';

test('SETUP-DISP-01: API closes and pays only the admin fixture for dispute UI coverage', async ({request}, info) => {
  test.setTimeout(120_000);
  const s = state();
  const f = s.admin;
  test.skip(!f?.auctionId, 'BLOCKED: moderation fixture required.');
  test.skip(!!f.paid, 'Dispute fixture was already paid; never pay twice.');
  test.skip(!fs.existsSync(freshPath), 'BLOCKED: bidder registration did not produce a test account.');

  const account = freshAccount();
  const loginResponse = await request.post(apiURL + '/api/auth/login', {
    data: {email: account.email, password: account.password},
  });
  expect(loginResponse.status()).toBe(200);
  const login = await loginResponse.json();
  expect(login.success).toBe(true);
  const token = login.data.token;
  const post = async (endpoint: string, data: unknown, status = 200) => {
    const response = await request.post(apiURL + endpoint, {
      headers: {Authorization: `Bearer ${token}`}, data,
    });
    const body = await response.json();
    expect(response.status(), `${endpoint}: ${body.error?.code || ''} ${body.error?.message || ''}`).toBe(status);
    expect(body.success, endpoint).toBe(true);
    return body.data;
  };

  // API setup must not depend on the main UI payment journey creating an
  // address. Validate ownership against this buyer's own address list first.
  const existingOrder = f.orderId
    ? await get(request, token, `/api/orders/${f.orderId}`)
    : null;
  if (existingOrder) {
    expect(String(existingOrder.auctionId)).toBe(String(f.auctionId));
  }
  const addressData = await get(request, token, '/api/addresses');
  expect(Array.isArray(addressData.addresses)).toBe(true);
  const addresses = addressData.addresses;
  const candidates = [existingOrder?.shippingAddress?.id, state().admin?.addressId, s.addressId]
    .filter(Boolean).map(String);
  let address = candidates.map(id => addresses.find((a: any) => String(a.id) === id))
    .find(Boolean);
  if (!address) {
    address = await post('/api/addresses', {
      recipientName: 'E2E Playwright Setup',
      phone: '0900000000',
      city: 'Ho Chi Minh',
      addressLine: 'E2E test only - 1 Setup Street',
    }, 201);
  }
  const addressId = String(address.id);
  expect(addressId).toMatch(/^\d+$/);
  updateState({admin: {...state().admin, addressId}});

  let orderId = state().admin.orderId;
  if (!orderId) {
    const detail = await get(request, token, `/api/auctions/${f.auctionId}`);
    expect(detail.paused).toBe(false);
    expect(detail.status).toBe('active');
    await post(`/api/auctions/${f.auctionId}/join`, {}, 201);
    await post('/api/bids', {auctionId: f.auctionId, amount: detail.minNextBid}, 201);
    await clock(request, '/register', {
      auctionId: f.auctionId, sellerId: s.sellerId, title: f.title, token,
    });
    await clock(request, '/end-soon', {auctionId: f.auctionId});
    await expect.poll(async () => {
      await clock(request, '/close-expired', {auctionId: f.auctionId});
      return (await get(request, token, `/api/auctions/${f.auctionId}`)).status;
    }, {timeout: 40_000, intervals: [1000, 2000, 3000]}).toBe('ended');
    const orders = await get(request, token, '/api/orders/mine');
    const order = orders.orders.find((o: any) => String(o.auctionId) === String(f.auctionId));
    expect(order, 'New admin fixture must create a winner order').toBeTruthy();
    orderId = String(order.id);
    updateState({admin: {...state().admin, orderId}});
  }

  const order = await get(request, token, `/api/orders/${orderId}`);
  expect(String(order.auctionId)).toBe(String(f.auctionId));
  if (order.paymentStatus !== 'paid') {
    expect(order.paymentStatus).toBe('awaiting_payment');
    await post(`/api/orders/${orderId}/shipping-address`, {addressId});
    await post(`/api/orders/${orderId}/pay`, {method: 'qr'});
  }
  const paid = await get(request, token, `/api/orders/${orderId}`);
  expect(paid.paymentStatus).toBe('paid');
  expect(String(paid.shippingAddress?.id)).toBe(addressId);
  updateState({admin: {...state().admin, paid: true}});
  await evidence(info, 'dispute-fixture-preparation', {
    classification: 'API preparation, NOT UI registration/address/payment coverage',
    orderId, auctionId: f.auctionId, method: 'qr (simulated)', addressId,
  });
});
