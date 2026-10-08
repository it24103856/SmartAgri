import assert from 'node:assert/strict';
import { test } from 'node:test';
import { errorMessage, money } from './smartBasketUtils.js';

test('smart basket utilities format budget values', () => {
  assert.match(money(500), /500\.00/);
  assert.match(money(null), /0\.00/);
});

test('smart basket errors distinguish authorization failures', () => {
  assert.equal(errorMessage({ response: { status: 403 } }), 'An active admin account is required.');
  assert.equal(errorMessage({ response: { data: { message: 'Revision changed' } } }), 'Revision changed');
});
