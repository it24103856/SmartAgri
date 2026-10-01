import { useEffect, useState } from 'react';
import { ArrowUpRight, ShoppingCart, Package, Sparkles, TrendingUp, RefreshCw } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import UserAvatar from '../../components/UserAvatar';
import api from '../../services/api';

const money = (value) => new Intl.NumberFormat('en-LK', { style: 'currency', currency: 'LKR' }).format(Number(value ?? 0));
const panel = 'rounded-2xl border border-[#DFE8E0] bg-white p-5 sm:p-6 shadow-sm';
const button = 'rounded-xl border border-[#DCE7DF] bg-white px-4 py-2 text-sm font-semibold text-[#2D5A40] hover:bg-[#EAF4EE] focus-visible:outline-2 focus-visible:outline-green-600';

function Badge({ value }) {
  const normalized = String(value || '').toUpperCase();
  const tone = ['PAID', 'DELIVERED', 'CONFIRMED'].includes(normalized)
    ? 'bg-green-50 text-green-800' : ['CANCELLED', 'FAILED', 'PAYMENTFAILED', 'PAYMENTREVIEW'].includes(normalized)
      ? 'bg-red-50 text-red-800' : 'bg-amber-50 text-amber-800';
  return <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${tone}`}>{value ? value.replaceAll('_', ' ').replace(/([a-z])([A-Z])/g, '$1 $2') : 'Unknown'}</span>;
}

export default function Dashboard({ admin, profileError, onNavigate }) {
  const [range, setRange] = useState('This Month');
  const [retry, setRetry] = useState(0);
  const [report, setReport] = useState({ loading: true });
  const [overview, setOverview] = useState({ loading: true });

  useEffect(() => {
    const controller = new AbortController();
    api.get('/analytics/sales-profit', { params: { range }, signal: controller.signal, timeout: 15000 })
      .then(({ data }) => { if (!controller.signal.aborted) setReport({ data }); })
      .catch(() => { if (!controller.signal.aborted) setReport({ error: 'Could not load sales. Please retry.' }); });
    return () => controller.abort();
  }, [range, retry]);

  useEffect(() => {
    const controller = new AbortController();
    const config = { signal: controller.signal, timeout: 15000 };
    Promise.allSettled([
      api.get('/products', config),
      api.get('/admin-smart-baskets', { ...config, params: { page: 1, pageSize: 1 } }),
      api.get('/admin/orders', { ...config, params: { page: 1, pageSize: 5 } }),
    ]).then(([products, baskets, orders]) => {
      if (controller.signal.aborted) return;
      setOverview({
        pendingProducts: products.status === 'fulfilled' ? products.value.data.filter((p) => p.status === 'PENDING').length : null,
        pendingAI: baskets.status === 'fulfilled' ? baskets.value.data.totalCount : null,
        orders: orders.status === 'fulfilled' ? orders.value.data : null,
        error: [products, baskets, orders].some((r) => r.status === 'rejected') ? 'Some dashboard data could not be loaded. Please retry.' : '',
      });
    });
    return () => controller.abort();
  }, [retry]);

  function refresh() {
    setReport({ loading: true });
    setOverview({ loading: true });
    setRetry((v) => v + 1);
  }

  const value = (amount, loading) => loading ? 'Loading...' : amount ?? 'Unavailable';
  const cards = [
    { title: 'Sales Revenue', value: report.data ? money(report.data.summary.totalRevenue) : value(null, report.loading), note: range + ' ? verified payments', icon: TrendingUp },
    { title: 'Orders', value: value(overview.orders?.totalCount, overview.loading), note: 'All customer orders', icon: ShoppingCart },
    { title: 'Pending Products', value: value(overview.pendingProducts, overview.loading), note: 'Waiting for product review', icon: Package },
    { title: 'Pending AI Approvals', value: value(overview.pendingAI, overview.loading), note: 'Smart Baskets awaiting approval', icon: Sparkles },
  ];

  return (
    <div className="space-y-6 text-[#1E3A2B]">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div><p className="mb-1 text-xs font-semibold uppercase tracking-widest text-[#4E9F6E]">SmartAgri Admin</p><h1 className="text-2xl sm:text-3xl font-bold">Dashboard</h1><p className="mt-2 text-sm text-gray-500">Welcome back, {admin?.fullName || 'Admin'}. Here is your store at a glance.</p></div>
        <button className={button + ' flex items-center gap-2'} onClick={refresh}><RefreshCw size={16} /> Refresh</button>
      </header>
      {(report.error || overview.error) && <div role="alert" className="rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">{report.error || overview.error} <button className="underline font-semibold" onClick={refresh}>Retry</button></div>}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {cards.map(({ title, value: amount, note, icon: Icon }) => <section key={title} className={panel}><div className="flex justify-between items-center gap-3"><h2 className="text-sm font-medium text-gray-500">{title}</h2><span className="rounded-xl bg-[#EAF4EE] p-3 text-[#2D5A40]"><Icon size={20} /></span></div><p className="mt-4 text-2xl font-bold break-words" aria-live="polite">{amount}</p><p className="mt-2 text-xs text-gray-500">{note}</p></section>)}
      </div>
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <section className={panel + ' xl:col-span-2 min-w-0'}>
          <div className="flex flex-wrap justify-between items-center gap-3 mb-6"><div><h2 className="text-lg font-bold">Sales Revenue</h2><p className="mt-1 text-xs text-gray-500">Verified collections ? Sri Lanka time ? LKR</p></div><select aria-label="Sales date range" className={button} value={range} onChange={(e) => { setReport({ loading: true }); setRange(e.target.value); }}>{['This Week', 'This Month', 'Last 6 Months', 'This Year'].map((r) => <option key={r}>{r}</option>)}</select></div>
          <div className="h-72">
            {report.loading ? <p role="status" className="flex h-full items-center justify-center text-gray-500">Loading sales...</p> : report.data ? <ResponsiveContainer width="100%" height="100%"><AreaChart data={report.data.monthlyData} margin={{ top: 10, right: 12, left: 8, bottom: 10 }}><defs><linearGradient id="dashboardSales" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#4E9F6E" stopOpacity={0.3} /><stop offset="100%" stopColor="#4E9F6E" stopOpacity={0.02} /></linearGradient></defs><CartesianGrid vertical={false} stroke="#EDF2EE" strokeDasharray="4 4" /><XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#6B7280', fontSize: 12 }} /><YAxis axisLine={false} tickLine={false} tick={{ fill: '#6B7280', fontSize: 12 }} tickFormatter={(v) => v >= 1000 ? `${v / 1000}k` : v} /><Tooltip formatter={(v) => [money(v), 'Sales Revenue']} contentStyle={{ borderRadius: 12, borderColor: '#DFE8E0' }} /><Area type="monotone" dataKey="revenue" stroke="#4E9F6E" strokeWidth={3} fill="url(#dashboardSales)" /></AreaChart></ResponsiveContainer> : <p className="flex h-full items-center justify-center text-gray-500">Sales data unavailable.</p>}
          </div>
          {report.data?.summary.totalRevenue === 0 && <p className="text-sm text-gray-500">No verified payments in this period.</p>}
          <p className="mt-4 text-xs text-gray-500">Includes paid product orders and approved package receipts. Profit is unavailable because costs and payouts are not recorded.</p>
        </section>
        <section className={panel}><h2 className="text-lg font-bold">Pending actions</h2><p className="mt-1 mb-6 text-sm text-gray-500">Review items waiting for your approval.</p><div className="space-y-4">{[
          { title: 'Product approvals', count: overview.pendingProducts, tab: 'products', icon: Package },
          { title: 'Smart Basket approvals', count: overview.pendingAI, tab: 'ai-manage', icon: Sparkles },
        ].map(({ title, count, tab, icon: Icon }) => <button key={tab} onClick={() => onNavigate(tab)} className="flex w-full items-center gap-3 rounded-xl border border-[#DCE7DF] bg-[#F4FAF6] p-4 text-left hover:bg-[#EAF4EE] focus-visible:outline-2 focus-visible:outline-green-600"><Icon size={22} className="shrink-0 text-[#4E9F6E]" /><span className="flex-1"><span className="block text-sm font-semibold">{title}</span><span className="mt-1 block text-xs text-gray-500">{overview.loading ? 'Loading...' : count == null ? 'Count unavailable' : `${count} pending`}</span></span><ArrowUpRight size={18} /></button>)}</div></section>
      </div>
      <section className={panel}>
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3"><div><h2 className="text-lg font-bold">Recent orders</h2><p className="mt-1 text-sm text-gray-500">Latest customer orders across all dates.</p></div><button className={button} onClick={() => onNavigate('orders')}>View all orders</button></div>
        <div className="overflow-x-auto"><table className="w-full min-w-[650px] text-left text-sm"><thead className="bg-[#F4FAF6] text-gray-500"><tr>{['Order', 'Customer', 'Amount', 'Payment status', 'Order status'].map((label) => <th key={label} scope="col" className="px-4 py-3 font-medium">{label}</th>)}</tr></thead><tbody className="divide-y divide-[#EDF2EE]">{overview.orders?.items.map((order) => <tr key={order.id} className="hover:bg-green-50/40"><td className="px-4 py-4"><p className="font-semibold">#{order.id}</p><p className="mt-1 text-xs text-gray-500">{new Date(order.createdAt).toLocaleDateString('en-GB', { timeZone: 'Asia/Colombo' })}</p></td><td className="px-4 py-4 font-medium">{order.fullName}</td><td className="px-4 py-4 font-semibold">{money(order.totalAmount)}</td><td className="px-4 py-4"><Badge value={order.paymentStatus} /></td><td className="px-4 py-4"><Badge value={order.status} /></td></tr>)}{!overview.orders?.items.length && <tr><td colSpan={5} className="py-10 text-center text-gray-500">{overview.loading ? 'Loading orders...' : overview.orders ? 'No orders yet.' : 'Recent orders unavailable.'}</td></tr>}</tbody></table></div>
      </section>
      <section aria-label="Your admin profile" className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm mb-8">
        <div className="flex items-center gap-4 mb-5">
          <UserAvatar user={admin} className="h-20 w-20" />
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-wider text-gray-500">Your profile</p>
            <h2 className="text-xl font-bold text-[#1E3A2B] break-words">{admin?.fullName || 'Admin'}</h2>
            <p className="text-sm text-gray-500">System Administrator</p>
          </div>
        </div>
        {profileError && <p role="status" className="text-sm text-amber-700 mb-4">{profileError}</p>}
        <dl className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4 text-sm">
          {[
            ['Email', admin?.email],
            ['Phone number', admin?.phone],
            ['Role', admin?.role],
            ['Account status', admin?.status],
            ['Address', [admin?.address, admin?.city, admin?.province].filter(Boolean).join(', ')],
            ['Joined', admin?.createdAt && !Number.isNaN(Date.parse(admin.createdAt)) ? new Date(admin.createdAt).toLocaleDateString() : null],
          ].map(([label, value]) => (
            <div key={label}>
              <dt className="text-gray-500 mb-1">{label}</dt>
              <dd className="font-medium text-[#1E3A2B] break-words">{value || 'Not provided'}</dd>
            </div>
          ))}
        </dl>
      </section>


    </div>
  );
}
