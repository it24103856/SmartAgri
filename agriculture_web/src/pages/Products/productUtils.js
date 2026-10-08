export function imageSource(path, baseUrl, origin = 'http://localhost') {
  if (!path) return '';
  try {
    const apiOrigin = new URL(baseUrl, origin).origin;
    const url = new URL(path, apiOrigin);
    return ['http:', 'https:'].includes(url.protocol) ? url.href : '';
  } catch {
    return '';
  }
}

export function getError(error) {
  if (error.response?.status === 403) return 'Only active administrators can manage products.';
  const data = error.response?.data;
  if (data?.message) return data.message;
  if (data?.errors) return Object.values(data.errors).flat().join(' ');
  if (error.response?.status === 413) return 'The upload is too large. Use up to 5 images, 5 MB each.';
  return 'The request failed. Please try again.';
}
