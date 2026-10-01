function cell(value) {
  let text = String(value ?? '');
  // Prevent spreadsheet formulas in customer-entered names and descriptions.
  if (/^[\s]*[=+@-]/.test(text) || /^[\t\r\n]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}

export function reportCsv(data) {
  const rows = [
    ['Report period', data.range], ['From (UTC)', data.from], ['To (UTC)', data.to],
    ['Currency', 'LKR'], ['Money collected', data.summary.totalRevenue],
    ['Net profit', 'Not available: costs and payouts are not recorded'],
    ['Orders/bookings created', data.summary.totalOrders],
    ['Outstanding on orders/bookings created in period', data.summary.pendingPayments],
    [], ['Period', 'Money collected'],
    ...data.monthlyData.map((row) => [row.name, row.revenue]),
    [], ['Category', 'Collected', 'Share (%)'],
    ...data.categoryData.map((row) => [row.name, row.amount, row.value]),
    [], ['ID', 'Created (UTC)', 'Customer', 'Item', 'Order value', 'Order status', 'Payment status', 'Outstanding'],
    ...data.recentTransactions.map((row) => [row.id, row.date, row.customer, row.item, row.amount, row.status, row.paymentStatus, row.outstanding]),
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}
