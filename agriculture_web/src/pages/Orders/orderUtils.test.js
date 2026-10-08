import assert from 'node:assert/strict';
import { test } from 'node:test';
import { errorMessage, money, dateTime } from './orderUtils.js';

test('order utilities format currency and missing dates', () => {
  assert.match(money(1250), /1,250\.00/);
  assert.equal(dateTime(null), '—');
  assert.equal(dateTime('invalid'), '—');
});

test('order errors map authorization and API messages', () => {
  assert.equal(errorMessage({ response: { status: 401 } }), 'Your session expired. Log out and sign in again.');
  assert.equal(errorMessage({ response: { data: { message: 'Order is locked' } } }), 'Order is locked');
});
