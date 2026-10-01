import { lazy, Suspense, useEffect, useState } from 'react';
import api from './services/api';
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
  const [admin, setAdmin] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('user') || 'null');
    } catch {
      return null;
    }
  });
  const [profileError, setProfileError] = useState('');

  useEffect(() => {
    if (!isAuthenticated) return;
    const controller = new AbortController();
    api.get('/auth/session', { signal: controller.signal }).then(({ data }) => {
      setAdmin(data);
      setProfileError('');
      localStorage.setItem('user', JSON.stringify(data));
    }).catch(error => {
      if (controller.signal.aborted) return;
      if ([401, 403].includes(error.response?.status)) {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        setAdmin(null);
        setIsAuthenticated(false);
      } else {
        setProfileError('Could not refresh your profile. Showing saved account details.');
      }
    });
    return () => controller.abort();
  }, [isAuthenticated]);

  const handleLogin = (user) => {
    setAdmin(user);
    setProfileError('');
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setAdmin(null);
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
        admin={admin}
      />
      
      <main className={`min-w-0 flex-1 ${activeTab === 'dashboard' ? 'bg-white' : 'bg-[#F4F7F4]'} p-4 sm:p-8 overflow-y-auto`}>
        <Suspense fallback={<div role="status" className="p-4 text-gray-500">Loading page...</div>}>
        {activeTab === 'dashboard' && <Dashboard admin={admin} profileError={profileError} onNavigate={setActiveTab} />}
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
