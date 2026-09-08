import React from 'react';
import { 
  Users, ShoppingCart, AlertCircle, Tractor, 
  Search, Bell, ArrowUpRight 
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell 
} from 'recharts';

// Dummy Chart Data
const salesData = [
  { month: 'Jan', revenue: 40000, profit: 24000 },
  { month: 'Feb', revenue: 55000, profit: 32000 },
  { month: 'Mar', revenue: 70000, profit: 45000 },
  { month: 'Apr', revenue: 62000, profit: 38000 },
  { month: 'May', revenue: 85000, profit: 52000 },
  { month: 'Jun', revenue: 95000, profit: 61000 },
];

const categoryData = [
  { name: 'Fertilizers', value: 45 },
  { name: 'Equipment', value: 30 },
  { name: 'Seeds', value: 25 },
];

const COLORS = ['#2D5A40', '#4E9F6E', '#8EB89B'];

const Dashboard = () => {
  return (
    <div className="flex-1 bg-[#F4F7F4] p-8 min-h-screen">
      {/* Top Header */}
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-2xl font-bold text-[#1E3A2B]">Welcome Back, Admin! 👋</h1>
          <p className="text-sm text-gray-500">SmartAgri System Overview & Performance Analytics</p>
        </div>

        {/* Search & Actions */}
        <div className="flex items-center space-x-4">
          <div className="relative">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
              type="text" 
              placeholder="Search products, orders..." 
              className="pl-10 pr-4 py-2 bg-white rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#4E9F6E]"
            />
          </div>
          <button className="p-2 bg-white rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50 relative">
            <Bell size={20} />
            <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
          </button>
        </div>
      </div>

      {/* Top Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-5 mb-8">
        {[
          { title: 'Total Customers', val: '1,280', icon: Users, color: 'bg-[#EAF4EE] text-[#1E3A2B]' },
          { title: 'Pending Orders', val: '24', icon: ShoppingCart, color: 'bg-[#EAF4EE] text-[#1E3A2B]' },
          { title: 'Farmer Approvals', val: '12', icon: AlertCircle, color: 'bg-[#FFF3E0] text-[#E65100]' },
          { title: 'Active Packages', val: '45', icon: Tractor, color: 'bg-[#EAF4EE] text-[#1E3A2B]' },
        ].map((card, idx) => {
          const Icon = card.icon;
          return (
            <div key={idx} className="bg-white p-5 rounded-2xl border border-gray-100 shadow-sm flex items-center justify-between">
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{card.title}</p>
                <h3 className="text-2xl font-bold text-[#1E3A2B] mt-1">{card.val}</h3>
              </div>
              <div className={`p-3 rounded-xl ${card.color}`}>
                <Icon size={22} />
              </div>
            </div>
          );
        })}
      </div>

      {/* Analytics Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        {/* Revenue & Profit Area Chart */}
        <div className="lg:col-span-2 bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
          <div className="flex justify-between items-center mb-6">
            <div>
              <h2 className="text-lg font-bold text-[#1E3A2B]">Revenue vs Profit</h2>
              <p className="text-xs text-gray-400">Monthly breakdown for the current year</p>
            </div>
            <span className="text-xs font-semibold bg-[#EAF4EE] text-[#2D5A40] px-3 py-1 rounded-full">Last 6 Months</span>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={salesData}>
                <defs>
                  <linearGradient id="colorRev" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2D5A40" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#2D5A40" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" stroke="#9CA3AF" fontSize={12} />
                <YAxis stroke="#9CA3AF" fontSize={12} />
                <Tooltip />
                <Area type="monotone" dataKey="revenue" stroke="#2D5A40" fillOpacity={1} fill="url(#colorRev)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Sales by Category Pie Chart */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm flex flex-col justify-between">
          <div>
            <h2 className="text-lg font-bold text-[#1E3A2B]">Category Share</h2>
            <p className="text-xs text-gray-400">Distribution by sales volume</p>
          </div>
          <div className="h-48 my-auto">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={categoryData} innerRadius={50} outerRadius={70} paddingAngle={5} dataKey="value">
                  {categoryData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="flex justify-around text-xs font-medium text-gray-600">
            {categoryData.map((item, idx) => (
              <div key={idx} className="flex items-center space-x-1">
                <span className="w-3 h-3 rounded-full" style={{ backgroundColor: COLORS[idx] }}></span>
                <span>{item.name}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Action Center */}
      <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
        <h2 className="text-lg font-bold text-[#1E3A2B] mb-4">Action Center</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[
            { title: 'Pending Farmer Listings', count: '12 Items', path: 'View Products' },
            { title: 'Equipment Verification', count: '5 Pending', path: 'Review Equipment' },
            { title: 'AI Recommendations', count: '7 Unreviewed', path: 'Verify Insights' },
          ].map((action, i) => (
            <div key={i} className="p-4 bg-[#F4F7F4] rounded-xl flex justify-between items-center hover:bg-[#EAF4EE] transition-all cursor-pointer">
              <div>
                <h4 className="font-semibold text-sm text-[#1E3A2B]">{action.title}</h4>
                <p className="text-xs text-gray-500 mt-0.5">{action.count}</p>
              </div>
              <ArrowUpRight size={18} className="text-[#2D5A40]" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;