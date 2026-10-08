export function getErrorMessage(error) {
  const data = error.response?.data;
  if (error.response?.status === 413) return 'Choose an image no larger than 5 MB.';
  if (error.response?.status === 403) return 'Only administrators can manage categories.';
  if (data?.message) return data.message;
  if (data?.errors) return Object.values(data.errors).flat().join(' ');
  return 'Unable to complete the request. Please try again.';
}

export function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
}
