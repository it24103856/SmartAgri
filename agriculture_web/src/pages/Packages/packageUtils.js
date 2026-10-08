export const CATEGORIES = [
  { value: 'MACHINERY', label: 'Machinery & Land Prep', unit: 'acre' },
  { value: 'INPUTS', label: 'Seeds & Fertilizer', unit: 'kg' },
  { value: 'TRANSPORT', label: 'Transport & Logistics', unit: 'km' },
];
export const categoryMeta = (value) => CATEGORIES.find((c) => c.value === value) ?? CATEGORIES[0];
export const money = (value) => new Intl.NumberFormat('en-LK', {
  style: 'currency', currency: 'LKR', minimumFractionDigits: 2,
}).format(Number(value) || 0);
