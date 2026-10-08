import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ASSIGNABLE_ROLES, ROLE_FILTERS, isAssignableRole } from './userUtils.js';

test('user filters include all supported roles', () => {
  assert.deepEqual(ROLE_FILTERS, ['ALL', 'ADMIN', 'FARMER', 'CUSTOMER']);
  assert.deepEqual(ASSIGNABLE_ROLES, ['ADMIN', 'FARMER', 'CUSTOMER']);
  assert.equal(isAssignableRole('FARMER'), true);
  assert.equal(isAssignableRole('OWNER'), false);
});
