import React, { useState } from 'react';
import Sidebar from './components/layout/Sidebar';
import Dashboard from './pages/Dashboard/Dashboard';
import Login from './pages/Auth/Login';
import UserManagement from './pages/Users/UserManagement';
import CategoryManagement from './pages/Categories/CategoryManagement';
import ProductManagement from './pages/Products/ProductManagement';


function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState('dashboard');

  const handleLogin = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
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
      
      <main className="flex-1 bg-[#F4F7F4] p-8 overflow-y-auto">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'users' && <UserManagement />}
        {activeTab === 'categories' && <CategoryManagement />}
        {activeTab === 'products' && <ProductManagement />}

        {activeTab !== 'dashboard' && (
          <div className="p-4">
            <h1 className="text-2xl font-bold text-[#1E3A2B] capitalize">{activeTab} Section</h1>
            <p className="mt-2 text-gray-500">Module component under development...</p>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;