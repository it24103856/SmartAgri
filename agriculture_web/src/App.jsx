import { lazy, Suspense, useState } from 'react';
import Sidebar from './components/layout/Sidebar';
import Login from './pages/Auth/Login';

const Dashboard = lazy(() => import('./pages/Dashboard/Dashboard'));
const UserManagement = lazy(() => import('./pages/Users/UserManagement'));
const CategoryManagement = lazy(() => import('./pages/Categories/CategoryManagement'));
const ProductManagement = lazy(() => import('./pages/Products/ProductManagement'));
const OrderManagement = lazy(() => import('./pages/Orders/OrderManagement'));
const SmartBasketManagement = lazy(() => import('./pages/SmartBaskets/SmartBasketManagement'));
const PackageManagement = lazy(() => import('./pages/Packages/PackageManagement'));
const SalesAndProfit = lazy(() => import('./pages/Analytics/SalesAndProfit'));


function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return !!localStorage.getItem('token');
  });
  const [activeTab, setActiveTab] = useState('dashboard');

  const handleLogin = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setIsAuthenticated(false);
  };

  if (!isAuthenticated) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <div className="flex flex-row min-h-screen bg-[#F4F7F4] font-sans overflow-x-hidden">
      <Sidebar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        onLogout={handleLogout} 
      />
      
      <main className="min-w-0 flex-1 bg-[#F4F7F4] p-8 overflow-y-auto">
        <Suspense fallback={<div role="status" className="p-4 text-gray-500">Loading page...</div>}>
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'users' && <UserManagement />}
        {activeTab === 'categories' && <CategoryManagement />}
        {activeTab === 'products' && <ProductManagement />}
        {activeTab === 'orders' && <OrderManagement />}
        {activeTab === 'ai-manage' && <SmartBasketManagement />}
        {activeTab === 'equipment' && <PackageManagement />}
        {activeTab === 'analytics' && <SalesAndProfit />}

        {![
          'dashboard',
          'users',
          'categories',
          'products',
          'orders',
          'ai-manage',
          'equipment',
          'analytics',
        ].includes(activeTab) && (
          <div className="p-4">
            <h1 className="text-2xl font-bold text-[#1E3A2B] capitalize">{activeTab} Section</h1>
            <p className="mt-2 text-gray-500">Module component under development...</p>
          </div>
        )}
        </Suspense>
      </main>
    </div>
  );
}

export default App;
