import assert from 'node:assert/strict';
import { test } from 'node:test';
import { formatDate, getErrorMessage } from './categoryUtils.js';

test('category utilities format valid and invalid dates', () => {
  assert.equal(formatDate(null), '—');
  assert.equal(formatDate('not-a-date'), '—');
  assert.match(formatDate('2026-01-02T00:00:00Z'), /02 Jan 2026/);
});

test('category utilities expose API validation messages', () => {
  assert.equal(getErrorMessage({ response: { status: 403 } }), 'Only administrators can manage categories.');
  assert.equal(getErrorMessage({ response: { data: { errors: { name: ['Name is required'] } } } }), 'Name is required');
});
