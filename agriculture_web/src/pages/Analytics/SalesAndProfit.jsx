import { useEffect, useState } from 'react';
import { Download, Loader2, TrendingUp, DollarSign, Package, Clock } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import api from '../../services/api';
import { reportCsv } from './salesReport';

const COLORS = ['#2D5A40', '#4E9F6E', '#8A9A8F', '#C2D5C8'];
const money = (amount) => `Rs. ${Number(amount ?? 0).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const date = (value) => new Date(value).toLocaleString('en-GB', { timeZone: 'Asia/Colombo' });
const status = (value) => value === 'AWAITING_PAYMENT' ? 'Awaiting advance payment' : (value || 'Unknown').replaceAll('_', ' ');

export default function SalesAndProfit() {
  const [timeRange, setTimeRange] = useState('Last 6 Months');
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [retry, setRetry] = useState(0);
  const [showAll, setShowAll] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      setLoading(true);
      setError(null);
      setShowAll(false);
      try {
        const response = await api.get('/analytics/sales-profit', {
          params: { range: timeRange }, signal: controller.signal,
        });
        if (!controller.signal.aborted) setData(response.data);
      } catch (err) {
        if (!controller.signal.aborted) setError(err.response?.data?.message || 'Failed to load analytics. Please retry.');
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }
    load();
    return () => controller.abort();
  }, [timeRange, retry]);

  function download() {
    const url = URL.createObjectURL(new Blob(['\uFEFF', reportCsv(data)], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `sales-report-${data.range.replaceAll(' ', '-')}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  const summary = data?.summary;
  const transactions = data?.recentTransactions ?? [];
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap justify-between items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-[#1E3A2B]">Sales &amp; Profit Analytics</h1>
          <p className="text-gray-500 mt-1">Verified collections and order activity. Dates use Sri Lanka time.</p>
        </div>
        <div className="flex gap-3">
          <select aria-label="Report period" value={timeRange} onChange={(e) => setTimeRange(e.target.value)} className="border rounded-xl px-4 py-2 bg-white">
            {['This Week', 'This Month', 'Last 6 Months', 'This Year'].map((range) => <option key={range}>{range}</option>)}
          </select>
          <button disabled={loading || !!error || !data} onClick={download} className="bg-[#1E3A2B] text-white px-4 py-2 rounded-xl flex items-center gap-2 disabled:opacity-50">
            <Download size={16} /> Export CSV
          </button>
        </div>
      </div>
      {loading ? <div role="status" className="flex h-64 items-center justify-center"><Loader2 className="animate-spin" /><span className="ml-2">Loading report...</span></div>
        : error ? <div role="alert" className="text-red-700">{error} <button onClick={() => setRetry((value) => value + 1)} className="underline">Retry</button></div>
          : data && <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <Metric title="Money collected" amount={money(summary.totalRevenue)} note="Paid product payments + approved package receipts in this period." />
              <Metric title="Net profit" amount="Not available" note="Costs, farmer payouts and operating expenses are not recorded. No assumed margin is used." />
              <Metric title="Orders & bookings created" amount={summary.totalOrders} note="All statuses, created in the selected period." />
              <Metric title="Outstanding payments" amount={money(summary.pendingPayments)} note="Current unpaid amounts on eligible orders/bookings created in this period; includes package balances." />
            </div>
            <p className="text-sm text-gray-500">Collections use the payment date (package receipts use approval date), even for older orders. Outstanding amounts include approved service balances, including those due after completion. Unapproved requests are excluded. Legacy bookings without verified payments are not counted as collections. This report does not calculate accounting revenue or net profit; chargebacks are excluded from collected product payments.</p>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <section className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 lg:col-span-2">
                <div className="flex justify-between items-center mb-6">
                  <h2 className="text-lg font-bold text-[#1E3A2B]">Money collected over time</h2>
                </div>
                <div className="h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data.monthlyData} margin={{ left: 10, right: 10, bottom: 0, top: 10 }}>
                      <defs>
                        <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#2D5A40" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#2D5A40" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" />
                      <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 12}} dy={10} />
                      <YAxis axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 12}} tickFormatter={(value) => `Rs.${value / 1000}k`} />
                      <Tooltip 
                        contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                        formatter={(value) => [money(value), 'Collected']} 
                      />
                      <Area type="monotone" name="Collected" dataKey="revenue" stroke="#2D5A40" strokeWidth={3} fillOpacity={1} fill="url(#colorRevenue)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </section>
              
              <section className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col">
                <h2 className="text-lg font-bold text-[#1E3A2B] mb-6">Collections by category</h2>
                {data.categoryData.length === 0 ? <p className="text-gray-500 flex-1 flex items-center justify-center">No verified payments in this period.</p> : <>
                  <div className="h-[220px] w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={data.categoryData} dataKey="amount" nameKey="name" cx="50%" cy="50%" innerRadius={65} outerRadius={85} paddingAngle={5} stroke="none">
                          {data.categoryData.map((item, index) => <Cell key={item.name} fill={COLORS[index % COLORS.length]} />)}
                        </Pie>
                        <Tooltip 
                          formatter={(value) => money(value)} 
                          contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                        />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="mt-6 space-y-4">
                    {data.categoryData.map((item, idx) => (
                      <div key={item.name} className="flex justify-between items-center text-sm">
                        <div className="flex items-center gap-3">
                          <div className="w-3 h-3 rounded-full shadow-sm" style={{ backgroundColor: COLORS[idx % COLORS.length] }}></div>
                          <span className="text-gray-600 font-medium">{item.name}</span>
                        </div>
                        <div className="text-right">
                          <span className="font-bold text-[#1E3A2B] block">{money(item.amount)}</span>
                          <span className="text-xs text-gray-400">{item.value}%</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </>}
              </section>
            </div>

            <section className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden mt-8">
              <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-gray-50/30">
                <h2 className="text-lg font-bold text-[#1E3A2B]">Orders &amp; bookings created in this period</h2>
                {transactions.length > 5 && (
                  <button 
                    className="text-sm font-semibold text-[#2D5A40] hover:text-[#1E3A2B] bg-[#EAF4EE] px-4 py-2 rounded-lg transition-colors" 
                    onClick={() => setShowAll((value) => !value)}
                  >
                    {showAll ? 'Show latest 5' : `View all (${transactions.length})`}
                  </button>
                )}
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm whitespace-nowrap">
                  <thead className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                    <tr>
                      {['ID', 'Created (Sri Lanka)', 'Customer', 'Item / Service', 'Order value', 'Order status', 'Payment status', 'Outstanding'].map((label) => (
                        <th key={label} className="px-6 py-4 font-semibold">{label}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {(showAll ? transactions : transactions.slice(0, 5)).map((row) => (
                      <tr key={row.id} className="hover:bg-[#F4F7F4]/50 transition-colors">
                        <td className="px-6 py-4 font-bold text-[#1E3A2B]">{row.id}</td>
                        <td className="px-6 py-4 text-gray-500">{date(row.date)}</td>
                        <td className="px-6 py-4 font-medium text-gray-800">{row.customer}</td>
                        <td className="px-6 py-4 text-gray-600 max-w-[200px] truncate" title={row.item}>{row.item}</td>
                        <td className="px-6 py-4 font-bold text-[#2D5A40]">{money(row.amount)}</td>
                        <td className="px-6 py-4">
                          <span className={`px-3 py-1 rounded-full text-xs font-bold
                            ${row.status === 'Completed' || row.status === 'CONFIRMED' ? 'bg-green-100 text-green-700' : ''}
                            ${row.status === 'Pending' || row.status === 'PENDING' || row.status === 'AwaitingPayment' ? 'bg-amber-100 text-amber-700' : ''}
                            ${row.status === 'Refunded' || row.status === 'REJECTED' || row.status === 'CANCELLED' ? 'bg-red-100 text-red-700' : ''}
                            ${!['Completed','CONFIRMED','Pending','PENDING','AwaitingPayment','Refunded','REJECTED','CANCELLED'].includes(row.status) ? 'bg-gray-100 text-gray-700' : ''}
                          `}>
                            {status(row.status)}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <span className={`px-3 py-1 rounded-full text-xs font-bold
                            ${row.paymentStatus === 'PAID' ? 'bg-green-100 text-green-700' : ''}
                            ${row.paymentStatus === 'UNPAID' || row.paymentStatus === 'PARTIAL' ? 'bg-amber-100 text-amber-700' : ''}
                            ${row.paymentStatus === 'NOT_REQUIRED' ? 'bg-gray-100 text-gray-600' : ''}
                            ${!['PAID','UNPAID','PARTIAL','NOT_REQUIRED'].includes(row.paymentStatus) ? 'bg-blue-100 text-blue-700' : ''}
                          `}>
                            {status(row.paymentStatus)}
                          </span>
                        </td>
                        <td className="px-6 py-4 font-semibold text-gray-700">{money(row.outstanding)}</td>
                      </tr>
                    ))}
                    {transactions.length === 0 && (
                      <tr>
                        <td colSpan={8} className="p-8 text-center text-gray-500 bg-gray-50/30">
                          <Package className="mx-auto mb-3 text-gray-400" size={32} />
                          <p>No orders or bookings in this period.</p>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          </>}
    </div>
  );
}

function Metric({ title, amount, note, icon: Icon, color, bg }) {
  // Determine default styles based on title if specific ones aren't provided
  let defaultBg = "bg-gray-50";
  let defaultColor = "text-gray-600";
  let DefaultIcon = TrendingUp;

  if (title.toLowerCase().includes("money") || title.toLowerCase().includes("revenue")) {
    defaultBg = "bg-[#EAF4EE]";
    defaultColor = "text-[#2D5A40]";
    DefaultIcon = DollarSign;
  } else if (title.toLowerCase().includes("profit")) {
    defaultBg = "bg-blue-50";
    defaultColor = "text-blue-600";
    DefaultIcon = TrendingUp;
  } else if (title.toLowerCase().includes("orders") || title.toLowerCase().includes("bookings")) {
    defaultBg = "bg-indigo-50";
    defaultColor = "text-indigo-600";
    DefaultIcon = Package;
  } else if (title.toLowerCase().includes("outstanding") || title.toLowerCase().includes("pending")) {
    defaultBg = "bg-amber-50";
    defaultColor = "text-amber-600";
    DefaultIcon = Clock;
  }

  const FinalIcon = Icon || DefaultIcon;
  const finalBg = bg || defaultBg;
  const finalColor = color || defaultColor;

  return (
    <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow duration-200">
      <div className="flex justify-between items-start">
        <div>
          <h2 className="text-gray-500 text-sm font-semibold uppercase tracking-wider">{title}</h2>
          <p className="text-3xl font-extrabold text-[#1E3A2B] mt-2 tracking-tight">{amount}</p>
        </div>
        <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${finalBg} ${finalColor}`}>
          <FinalIcon size={24} strokeWidth={2.5} />
        </div>
      </div>
      <div className="mt-5 flex items-start gap-2 bg-gray-50/50 p-3 rounded-xl border border-gray-50">
        <span className="text-gray-500 text-xs leading-relaxed">{note}</span>
      </div>
    </div>
  );
}
