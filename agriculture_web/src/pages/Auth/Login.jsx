import React, { useState } from 'react';
import { Lock, Mail, Leaf, Eye, EyeOff } from 'lucide-react';
import axios from 'axios';
import api from '../../services/api';

const Login = ({ onLogin }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Backend API Call එක
      const response = await axios.post('http://localhost:5000/api/auth/login', {
        email: email,
        password: password
      });

      // API Response එක සාර්ථක නම්
      if (response.data && response.data.token) {
        const user = response.data.user;

        // **මෙතැනින් පරිශීලකයා Admin කෙනෙක් දැයි පරීක්ෂා කරයි**
       if (!user.role || user.role.toLowerCase() !== 'admin') {
  setError('Access Denied! Only Administrators can access the Admin Panel.');
  setLoading(false);
  return;
}

        // Admin නම් පමණක් Token සහ User Details LocalStorage එකේ Save වේ
        localStorage.setItem('token', response.data.token);
        localStorage.setItem('user', JSON.stringify(user));
        
        // Parent Component (App.jsx) එකේ Login status එක true කිරීම
        if (onLogin) {
          onLogin(user);
        }
      }
    } catch (err) {
      // Error Handling
      if (err.response && err.response.data && err.response.data.message) {
        setError(err.response.data.message);
      } else {
        setError('Login failed! Please check your connection or credentials.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#1E3A2B] flex items-center justify-center p-4 relative overflow-hidden">
      {/* Background Decorative Elements */}
      <div className="absolute -top-20 -left-20 w-96 h-96 bg-[#2D5A40] rounded-full blur-3xl opacity-50"></div>
      <div className="absolute -bottom-20 -right-20 w-96 h-96 bg-[#4E9F6E] rounded-full blur-3xl opacity-30"></div>

      {/* Main Login Card */}
      <div className="bg-white/95 backdrop-blur-md w-full max-w-md p-8 rounded-3xl shadow-2xl relative z-10 border border-white/20">
        
        {/* Brand Header */}
        <div className="flex flex-col items-center mb-6">
          <div className="w-14 h-14 bg-[#EAF4EE] text-[#1E3A2B] rounded-2xl flex items-center justify-center mb-3 shadow-inner">
            <Leaf size={28} />
          </div>
          <h2 className="text-2xl font-bold text-[#1E3A2B]">SmartAgri Portal</h2>
          <p className="text-xs text-gray-500 mt-1">Sign in to access your administrative dashboard</p>
        </div>

        {/* Error Alert Box */}
        {error && (
          <div className="mb-4 p-3 bg-red-100 border border-red-300 text-red-700 text-xs rounded-xl font-medium text-center">
            {error}
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Email Input */}
          <div>
            <label className="block text-xs font-semibold text-[#1E3A2B] uppercase mb-2">Email Address</label>
            <div className="relative">
              <Mail className="absolute left-3.5 top-3 text-gray-400" size={18} />
              <input 
                type="email" 
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@smartagri.com"
                className="w-full pl-10 pr-4 py-2.5 bg-[#F4F7F4] border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2D5A40] text-gray-800"
              />
            </div>
          </div>

          {/* Password Input */}
          <div>
            <label className="block text-xs font-semibold text-[#1E3A2B] uppercase mb-2">Password</label>
            <div className="relative">
              <Lock className="absolute left-3.5 top-3 text-gray-400" size={18} />
              <input 
                type={showPassword ? 'text' : 'password'} 
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-10 pr-10 py-2.5 bg-[#F4F7F4] border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2D5A40] text-gray-800"
              />
              <button 
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3.5 top-3 text-gray-400 hover:text-gray-600"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Remember Me & Forgot Password */}
          <div className="flex items-center justify-between text-xs">
            <label className="flex items-center space-x-2 text-gray-600 cursor-pointer">
              <input type="checkbox" className="rounded border-gray-300 text-[#2D5A40] focus:ring-[#2D5A40]" />
              <span>Remember me</span>
            </label>
            <a href="#forgot" className="text-[#2D5A40] font-semibold hover:underline">Forgot password?</a>
          </div>

          {/* Submit Button */}
          <button 
            type="submit"
            disabled={loading}
            className="w-full bg-[#1E3A2B] hover:bg-[#2D5A40] text-white py-3 rounded-xl font-semibold shadow-lg transition-all duration-200 hover:shadow-xl mt-2 disabled:opacity-50"
          >
            {loading ? 'Authenticating...' : 'Sign In to Dashboard'}
          </button>
        </form>

        {/* Footer */}
        <div className="mt-8 text-center text-xs text-gray-400">
          <p>© 2026 SmartAgri System. All rights reserved.</p>
        </div>
      </div>
    </div>
  );
};

export default Login;