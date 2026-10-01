import { test } from 'node:test';
import assert from 'node:assert/strict';
import { reportCsv } from './salesReport.js';

test('CSV includes every row and safely quotes user-entered text', () => {
  const csv = reportCsv({
    range: 'This Month', from: '2026-09-30T18:30:00Z', to: '2026-10-01T12:00:00Z',
    summary: { totalRevenue: 100, totalOrders: 6, pendingPayments: 200 },
    monthlyData: [{ name: '01 Oct', revenue: 100 }], categoryData: [],
    recentTransactions: Array.from({ length: 6 }, (_, i) => ({
      id: `ORD-${i}`, date: '2026-10-01', customer: '=1+1', item: 'Carrots, "fresh"',
      amount: 100, status: 'Confirmed', paymentStatus: 'Unpaid', outstanding: 100,
    })),
  });
  assert.ok(csv.includes('ORD-5'));
  assert.ok(csv.includes('"\'=1+1"'));
  assert.ok(csv.includes('"Carrots, ""fresh"""'));
  assert.ok(csv.includes('Not available: costs and payouts are not recorded'));
});
