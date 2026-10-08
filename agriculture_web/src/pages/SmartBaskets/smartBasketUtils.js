export const money = (value) => new Intl.NumberFormat('en-LK', {
  style: 'currency', currency: 'LKR',
}).format(Number(value ?? 0));
export function errorMessage(error) {
  const status = error.response?.status;
  const data = error.response?.data;
  if (status === 401) return 'Session expired. Please log in again.';
  if (status === 403) return 'An active admin account is required.';
  if (typeof data?.message === 'string') return data.message;
  if (data?.errors) return Object.values(data.errors).flat().join(' ');
  return 'Could not complete the request. Check your connection.';
}
