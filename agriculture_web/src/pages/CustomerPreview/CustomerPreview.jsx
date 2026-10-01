import { useEffect, useState } from 'react';
import { ArrowLeft, Leaf, Search, ShoppingBag } from 'lucide-react';
import api from '../../services/api';

const money = (value) => new Intl.NumberFormat('en-LK', { style: 'currency', currency: 'LKR' }).format(value);
const control = 'rounded-xl border border-green-200 bg-white px-4 py-2 text-sm text-green-900 focus-visible:outline-2 focus-visible:outline-green-600';

function Photo({ path, name, large = false }) {
  const [failed, setFailed] = useState(false);
  let url;
  try {
    const origin = new URL(api.defaults.baseURL, window.location.origin).origin;
    const candidate = new URL(path, origin);
    if (path && ['http:', 'https:'].includes(candidate.protocol)) url = candidate.href;
  } catch { /* Show the catalog placeholder for invalid image paths. */ }
  return <div className={`flex items-center justify-center bg-[#F0F7EF] ${large ? 'h-72' : 'h-44'} rounded-xl overflow-hidden`}>{url && !failed ? <img className="h-full w-full object-contain" src={url} alt={name} onError={() => setFailed(true)} /> : <Leaf size={48} className="text-green-300" aria-label="No product image" />}</div>;
}

function Catalog({ query, onSelect }) {
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  useEffect(() => {
    const controller = new AbortController();
    api.get('/catalog/products', { params: query, signal: controller.signal, timeout: 15000 })
      .then(({ data }) => { if (!controller.signal.aborted) setResult(data); })
      .catch(() => { if (!controller.signal.aborted) setError('Could not load products. Use Refresh to retry.'); });
    return () => controller.abort();
  }, [query]);
  if (error) return <p role="alert" className="py-12 text-center text-red-700">{error}</p>;
  if (!result) return <p role="status" className="py-12 text-center text-gray-500">Loading products...</p>;
  return <><p className="mb-4 text-sm text-gray-500">{result.totalCount} products · Page {result.page}</p><div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">{result.items.map((p) => <button key={p.id} className="rounded-2xl border border-green-100 bg-white p-3 text-left shadow-sm hover:shadow-md focus-visible:outline-2 focus-visible:outline-green-600" onClick={() => onSelect(p)}><Photo path={p.imageUrls?.[0]} name={p.name} /><p className="mt-3 text-xs text-gray-500">{p.categoryName}</p><h3 className="mt-1 font-semibold">{p.name}</h3><p className="mt-2 font-bold text-green-800">{money(p.price)} <span className="text-xs font-normal text-gray-500">/ {p.unit}</span></p><p className="mt-2 text-xs text-gray-500">{p.stockQuantity > 0 ? 'In stock' : 'Out of stock'}</p><span className="mt-3 block text-sm font-medium text-green-700">View details →</span></button>)}</div>{result.items.length === 0 && <p className="py-12 text-center text-gray-500">No products match your search.</p>}</>;
}

export default function CustomerPreview({ onBack }) {
  const [categories, setCategories] = useState([]);
  const [categoryError, setCategoryError] = useState('');
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState({ page: 1, pageSize: 12, sort: 'latest' });
  const [selected, setSelected] = useState(null);
  const [refresh, setRefresh] = useState(0);
  useEffect(() => {
    const controller = new AbortController();
    api.get('/catalog/categories', { signal: controller.signal, timeout: 15000 })
      .then(({ data }) => { if (!controller.signal.aborted) { setCategories(data); setCategoryError(''); } })
      .catch(() => { if (!controller.signal.aborted) setCategoryError('Categories unavailable. Use Refresh to retry.'); });
    return () => controller.abort();
  }, [refresh]);
  function filter(values) { setQuery((q) => ({ ...q, ...values, page: 1 })); }
  return <div className="min-h-screen bg-[#FAFCF8] text-[#1E3A2B]">
    <div className="border-b border-green-200 bg-[#EAF4EE] px-4 sm:px-8 py-3 flex flex-wrap items-center justify-between gap-3"><p className="text-sm font-medium">Customer View · Preview only · Shopping and payments are disabled</p><button className={control + ' flex items-center gap-2'} onClick={onBack}><ArrowLeft size={16} /> Back to Admin</button></div>
    <main className="mx-auto max-w-7xl p-4 sm:p-8 space-y-6">
      <header className="flex items-center justify-between gap-3"><h1 className="flex items-center gap-2 text-2xl font-bold"><Leaf className="text-green-600" /> SmartAgri <span className="text-sm font-normal text-gray-500">Shop</span></h1><ShoppingBag className="text-green-700" aria-hidden="true" /></header>
      {selected ? <section className="rounded-3xl border border-green-100 bg-white p-5 sm:p-8"><button className={control + ' mb-6'} onClick={() => setSelected(null)}>← Back to products</button><div className="grid md:grid-cols-2 gap-8"><div className="space-y-3">{(selected.imageUrls?.length ? selected.imageUrls : [null]).map((path, i) => <Photo key={i} path={path} name={selected.name} large />)}</div><div><p className="text-sm text-gray-500">{selected.categoryName}</p><h2 className="mt-2 text-3xl font-bold">{selected.name}</h2><p className="mt-4 text-2xl font-bold text-green-800">{money(selected.price)} <span className="text-sm font-normal">/ {selected.unit}</span></p><p className="mt-3 text-sm text-gray-500">{selected.stockQuantity > 0 ? `${selected.stockQuantity} in stock` : 'Out of stock'}</p><p className="mt-6 whitespace-pre-wrap text-gray-600">{selected.description || 'No description available.'}</p><button disabled className="mt-8 w-full rounded-xl bg-green-100 p-3 text-green-700 disabled:cursor-not-allowed">Add to cart · Unavailable in preview</button></div></div></section> : <>
      <section className="rounded-3xl bg-gradient-to-r from-[#D8EDDC] to-[#FAF1D9] p-6 sm:p-10"><p className="text-xs font-bold tracking-widest text-green-700">FRESH FROM THE FARM</p><h2 className="mt-3 text-3xl sm:text-4xl font-bold">Fresh picks.<br />Naturally good.</h2><p className="mt-3 text-gray-600">From local growers. Explore fresh produce and farm essentials.</p></section>
      <section aria-label="Browse products" className="space-y-5"><div className="flex flex-wrap items-center justify-between gap-3"><h2 className="text-xl font-bold">Explore products</h2><button className={control} onClick={() => setRefresh((v) => v + 1)}>Refresh</button></div>
      <div className="flex flex-wrap gap-3"><form className="flex flex-1 min-w-[220px] gap-2" onSubmit={(e) => { e.preventDefault(); filter({ search: search.trim() }); }}><input aria-label="Search products" placeholder="Search fresh produce..." maxLength={100} value={search} onChange={(e) => setSearch(e.target.value)} className={control + ' min-w-0 flex-1'} /><button aria-label="Submit search" className={control}><Search size={18} /></button></form><select aria-label="Product category" className={control} value={query.categoryId || ''} onChange={(e) => filter({ categoryId: e.target.value || undefined })}><option value="">All categories</option>{categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select><select aria-label="Sort products" className={control} value={query.sort} onChange={(e) => filter({ sort: e.target.value })}><option value="latest">Latest arrivals</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option></select></div>
      {categoryError && <p role="alert" className="text-sm text-amber-700">{categoryError}</p>}
      <Catalog key={JSON.stringify(query) + refresh} query={query} onSelect={setSelected} />
      <div className="flex items-center justify-between gap-3"><button disabled={query.page === 1} className={control + ' disabled:opacity-40'} onClick={() => setQuery((q) => ({ ...q, page: q.page - 1 }))}>Previous</button><NextPage key={JSON.stringify(query) + refresh} query={query} onNext={() => setQuery((q) => ({ ...q, page: q.page + 1 }))} /></div>
      </section></>}
    </main>
  </div>;
}

function NextPage({ query, onNext }) {
  const [hasNext, setHasNext] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    api.get('/catalog/products', { params: query, signal: controller.signal, timeout: 15000 }).then(({ data }) => { if (!controller.signal.aborted) setHasNext(data.page * data.pageSize < data.totalCount); }).catch(() => {});
    return () => controller.abort();
  }, [query]);
  return <button disabled={!hasNext} className={control + ' disabled:opacity-40'} onClick={onNext}>Next</button>;
}
