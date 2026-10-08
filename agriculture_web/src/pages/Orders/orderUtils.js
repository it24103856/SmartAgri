const moneyFormatter = new Intl.NumberFormat('en-LK', { style: 'currency', currency: 'LKR' });
export const money = (value) => moneyFormatter.format(Number(value ?? 0));
export const dateTime = (value) => {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleString('en-LK');
};
export function errorMessage(error) {
  const status = error.response?.status;
  const data = error.response?.data;
  if (status === 401) return 'Your session expired. Log out and sign in again.';
  if (status === 403) return 'An active administrator account is required.';
  if (status === 404) return 'Order or API endpoint not found. Check that the updated backend is running.';
  if (typeof data?.message === 'string') return data.message;
  if (data?.errors) return Object.values(data.errors).flat().join(' ');
  return 'Could not connect to the server. Please try again.';
}
