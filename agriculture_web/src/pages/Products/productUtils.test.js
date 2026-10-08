import assert from 'node:assert/strict';
import { test } from 'node:test';
import { getError, imageSource } from './productUtils.js';

test('product image sources reject unsafe protocols', () => {
  assert.equal(imageSource('', 'http://localhost/api'), '');
  assert.equal(imageSource('javascript:alert(1)', 'http://localhost/api'), '');
  assert.equal(imageSource('/uploads/carrot.png', 'http://localhost/api'), 'http://localhost/uploads/carrot.png');
});

test('product errors preserve server validation details', () => {
  assert.equal(getError({ response: { status: 403 } }), 'Only active administrators can manage products.');
  assert.equal(getError({ response: { data: { message: 'Invalid price' } } }), 'Invalid price');
});
