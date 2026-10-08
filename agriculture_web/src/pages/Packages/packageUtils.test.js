import assert from 'node:assert/strict';
import { test } from 'node:test';
import { CATEGORIES, categoryMeta, money } from './packageUtils.js';

test('package categories provide a safe fallback and units', () => {
  assert.equal(CATEGORIES.length, 3);
  assert.equal(categoryMeta('INPUTS').unit, 'kg');
  assert.equal(categoryMeta('unknown').value, 'MACHINERY');
});

test('package money formatting handles empty values', () => {
  assert.match(money(2500), /2,500\.00/);
  assert.match(money(null), /0\.00/);
});
