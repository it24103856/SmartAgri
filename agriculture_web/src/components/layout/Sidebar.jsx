import React from 'react';
import { 
  LayoutDashboard, Users, ShoppingBag, FolderTree, 
  PackageCheck, Tractor, Bot, TrendingUp, Settings, LogOut 
} from 'lucide-react';

const Sidebar = ({ activeTab, setActiveTab, onLogout }) => {
  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'users', label: 'User Management', icon: Users },
    { id: 'products', label: 'Product Catalog', icon: ShoppingBag },
    { id: 'categories', label: 'Categories', icon: FolderTree },
    { id: 'orders', label: 'Order Processing', icon: PackageCheck },
    { id: 'equipment', label: 'Equipment & Packages', icon: Tractor },
    { id: 'ai-manage', label: 'Smart Basket Approvals', icon: Bot },
    { id: 'analytics', label: 'Sales & Profit', icon: TrendingUp },
    { id: 'settings', label: 'System Settings', icon: Settings },
  ];

  return (
    <aside className="w-64 bg-[#1E3A2B] text-white flex flex-col justify-between py-6 pl-4 pr-0 min-h-screen relative select-none shrink-0">
      <div>
        {/* Profile Header */}
        <div className="flex flex-col items-center mb-8 pr-4">
          <div className="w-16 h-16 rounded-full bg-[#2D5A40] border-2 border-[#4E9F6E] flex items-center justify-center overflow-hidden mb-2 shadow-md">
            <img 
              src="https://api.dicebear.com/7.x/avataaars/svg?seed=Admin" 
              alt="Admin Profile" 
              className="w-14 h-14"
            />
          </div>
          <h3 className="font-bold text-base tracking-wide text-[#E2F0D9]">Kavindu Minsara</h3>
          <p className="text-xs text-[#8EB89B]">System Administrator</p>
        </div>

        {/* Navigation Links */}
        <nav className="space-y-2">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            
            return (
              <div key={item.id} className="relative">
                <button
                  onClick={() => setActiveTab(item.id)}
                  className={`w-full flex items-center space-x-3 px-4 py-3 text-sm font-semibold transition-all duration-150 cursor-pointer ${
                    isActive
                      ? 'bg-[#F4F7F4] text-[#1E3A2B] rounded-l-full relative z-10'
                      : 'text-[#C5E1A5] hover:text-white rounded-xl mr-4'
                  }`}
                >
                  <Icon size={18} className={isActive ? 'text-[#1E3A2B]' : 'text-[#8EB89B]'} />
                  <span>{item.label}</span>
                </button>

                {/* Curved Inward Cutouts for Active Tab */}
                {isActive && (
                  <>
                    {/* Top Curved Corner */}
                    <div className="absolute -top-4 right-0 w-4 h-4 bg-[#F4F7F4] z-0">
                      <div className="w-full h-full bg-[#1E3A2B] rounded-br-2xl"></div>
                    </div>
                    {/* Bottom Curved Corner */}
                    <div className="absolute -bottom-4 right-0 w-4 h-4 bg-[#F4F7F4] z-0">
                      <div className="w-full h-full bg-[#1E3A2B] rounded-tr-2xl"></div>
                    </div>
                  </>
                )}
              </div>
            );
          })}
        </nav>
      </div>

      {/* Logout Button */}
      <div className="pr-4">
        <button 
          onClick={onLogout}
          className="w-full flex items-center space-x-3 px-4 py-3 text-sm font-medium text-[#FF8A80] hover:bg-[#2D5A40] rounded-xl transition-all cursor-pointer"
        >
          <LogOut size={18} />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
