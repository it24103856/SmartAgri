import React, { useEffect, useState, useCallback, useMemo } from 'react';
import {
  Search, UserCheck, UserX, ShieldOff, Trash2,
  ChevronLeft, ChevronRight, X, Loader2, ArrowUpDown,
  Users, ShieldCheck, Sprout, ShoppingBag, Mail, Phone, Calendar
} from 'lucide-react';
import api from '../../services/api';

const ROLE_FILTERS = ['ALL', 'ADMIN', 'FARMER', 'CUSTOMER'];
const ASSIGNABLE_ROLES = ['ADMIN', 'FARMER', 'CUSTOMER'];
const STATUS_STYLES = {
  ACTIVE: 'bg-[#EAF4EE] text-[#2D5A40]',
  INACTIVE: 'bg-[#FFF3E0] text-[#E65100]',
  BLOCKED: 'bg-red-100 text-red-700',
};
const ROLE_STYLES = {
  ADMIN: 'bg-[#1E3A2B] text-white',
  FARMER: 'bg-[#8EB89B] text-[#1E3A2B]',
  CUSTOMER: 'bg-gray-200 text-gray-700',
};

const PAGE_SIZE = 8;

const ConfirmDialog = ({ title, message, confirmLabel, danger, onConfirm, onCancel }) => (
  <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
    <div className="bg-white rounded-2xl p-6 w-full max-w-sm shadow-xl">
      <h3 className="font-bold text-[#1E3A2B] text-base mb-2">{title}</h3>
      <p className="text-sm text-gray-500 mb-6">{message}</p>
      <div className="flex justify-end gap-3">
        <button onClick={onCancel} className="px-4 py-2 text-sm font-semibold rounded-xl text-gray-600 hover:bg-gray-100">
          Cancel
        </button>
        <button
          onClick={onConfirm}
          className={`px-4 py-2 text-sm font-semibold rounded-xl text-white ${danger ? 'bg-red-600 hover:bg-red-700' : 'bg-[#1E3A2B] hover:bg-[#2D5A40]'}`}
        >
          {confirmLabel}
        </button>
      </div>
    </div>
  </div>
);

const StatCard = ({ icon: Icon, label, value, accent }) => (
  <div className="bg-white p-5 rounded-2xl border border-gray-100 shadow-sm flex items-center justify-between">
    <div>
      <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{label}</p>
      <h3 className="text-2xl font-bold text-[#1E3A2B] mt-1">{value}</h3>
    </div>
    <div className={`p-3 rounded-xl ${accent}`}>
      <Icon size={22} />
    </div>
  </div>
);

const UserDetailModal = ({ user, onClose, onRoleChange, roleChanging }) => {
  const [pendingRole, setPendingRole] = useState(user.role);

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl w-full max-w-md shadow-xl overflow-hidden">
        <div className="bg-[#1E3A2B] px-6 py-5 flex items-center justify-between">
          <div>
            <h3 className="text-white font-bold text-lg">{user.fullName}</h3>
            <span className={`inline-block mt-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold ${ROLE_STYLES[user.role] || 'bg-white/20 text-white'}`}>
              {user.role}
            </span>
          </div>
          <button onClick={onClose} className="text-white/70 hover:text-white">
            <X size={20} />
          </button>
        </div>

        <div className="p-6 space-y-4">
          <div className="flex items-center gap-3 text-sm">
            <Mail size={16} className="text-gray-400" />
            <span className="text-gray-700">{user.email}</span>
          </div>
          {user.phone && (
            <div className="flex items-center gap-3 text-sm">
              <Phone size={16} className="text-gray-400" />
              <span className="text-gray-700">{user.phone}</span>
            </div>
          )}
          <div className="flex items-center gap-3 text-sm">
            <Calendar size={16} className="text-gray-400" />
            <span className="text-gray-700">
              Joined {new Date(user.createdAt).toLocaleDateString()}
            </span>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${STATUS_STYLES[user.status] || ''}`}>
              {user.status}
            </span>
          </div>

          {/* Role change */}
          <div className="pt-4 border-t border-gray-100">
            <label className="block text-xs font-semibold text-gray-500 uppercase mb-2">
              Change Role
            </label>
            <div className="flex gap-2">
              <select
                value={pendingRole}
                onChange={(e) => setPendingRole(e.target.value)}
                className="flex-1 px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#4E9F6E]"
              >
                {ASSIGNABLE_ROLES.map((r) => (
                  <option key={r} value={r}>{r}</option>
                ))}
              </select>
              <button
                disabled={pendingRole === user.role || roleChanging}
                onClick={() => onRoleChange(user, pendingRole)}
                className="px-4 py-2 bg-[#1E3A2B] text-white text-sm font-semibold rounded-xl disabled:opacity-40 hover:bg-[#2D5A40] flex items-center gap-2"
              >
                {roleChanging && <Loader2 className="animate-spin" size={14} />}
                Save
              </button>
            </div>
            <p className="text-[11px] text-gray-400 mt-2">
              Changing a role updates what this account can access immediately.
            </p>
          </div>

          {user.role === 'FARMER' && (
            <div className="pt-4 border-t border-gray-100 text-xs text-gray-400">
              Farm profile & verification details will appear here once the Farmer module is connected.
            </div>
          )}
          {user.role === 'CUSTOMER' && (
            <div className="pt-4 border-t border-gray-100 text-xs text-gray-400">
              Order history will appear here once the Orders module is connected.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL');
  const [page, setPage] = useState(1);
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [confirmAction, setConfirmAction] = useState(null);
  const [toast, setToast] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [roleChanging, setRoleChanging] = useState(false);
  const [sortKey, setSortKey] = useState('createdAt');
  const [sortDir, setSortDir] = useState('desc');

  const fetchAll = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const [usersRes, statsRes] = await Promise.all([
        api.get('/users'),
        api.get('/users/stats'),
      ]);
      setUsers(usersRes.data);
      setStats(statsRes.data);
    } catch (err) {
      setError(
        err.response?.data?.message ||
        'Could not load users. Please check your connection and try again.'
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(''), 2500);
    return () => clearTimeout(t);
  }, [toast]);

  const handleSort = (key) => {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  };

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    let result = users.filter((u) => {
      const matchesRole = roleFilter === 'ALL' || u.role === roleFilter;
      const matchesSearch = !q || u.fullName?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q);
      return matchesRole && matchesSearch;
    });

    result.sort((a, b) => {
      let av = a[sortKey];
      let bv = b[sortKey];
      if (sortKey === 'createdAt') { av = new Date(av).getTime(); bv = new Date(bv).getTime(); }
      else { av = (av || '').toString().toLowerCase(); bv = (bv || '').toString().toLowerCase(); }
      if (av < bv) return sortDir === 'asc' ? -1 : 1;
      if (av > bv) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return result;
  }, [users, search, roleFilter, sortKey, sortDir]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paged = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const runStatusChange = async (user, action) => {
    setActionLoadingId(user.id);
    try {
      await api.put(`/users/${user.id}/${action}`);
      const nextStatus = action === 'activate' ? 'ACTIVE' : action === 'deactivate' ? 'INACTIVE' : 'BLOCKED';
      setUsers((prev) => prev.map((u) => (u.id === user.id ? { ...u, status: nextStatus } : u)));
      setToast(`${user.fullName} is now ${nextStatus.toLowerCase()}.`);
      fetchAll();
    } catch (err) {
      setToast(err.response?.data?.message || 'Action failed. Please try again.');
    } finally {
      setActionLoadingId(null);
      setConfirmAction(null);
    }
  };

  const runDelete = async (user) => {
    setActionLoadingId(user.id);
    try {
      await api.delete(`/users/${user.id}`);
      setUsers((prev) => prev.filter((u) => u.id !== user.id));
      setToast(`${user.fullName} was deleted.`);
      fetchAll();
    } catch (err) {
      setToast(err.response?.data?.message || 'Delete failed. Please try again.');
    } finally {
      setActionLoadingId(null);
      setConfirmAction(null);
    }
  };

  const handleConfirmed = () => {
    if (!confirmAction) return;
    const { type, user } = confirmAction;
    if (type === 'delete') runDelete(user);
    else runStatusChange(user, type);
  };

  const handleRoleChange = async (user, newRole) => {
    setRoleChanging(true);
    try {
      const res = await api.put(`/users/${user.id}/role`, { role: newRole });
      setUsers((prev) => prev.map((u) => (u.id === user.id ? res.data : u)));
      setSelectedUser(res.data);
      setToast(`${user.fullName}'s role changed to ${newRole}.`);
      fetchAll();
    } catch (err) {
      setToast(err.response?.data?.message || 'Role change failed.');
    } finally {
      setRoleChanging(false);
    }
  };

  const confirmCopy = {
    activate: { title: 'Activate user', label: 'Activate', danger: false, msg: (n) => `Restore full access for ${n}?` },
    deactivate: { title: 'Deactivate user', label: 'Deactivate', danger: false, msg: (n) => `${n} won't be able to sign in until reactivated. Continue?` },
    block: { title: 'Block user', label: 'Block', danger: true, msg: (n) => `Block ${n}? This immediately revokes their access.` },
    delete: { title: 'Delete user', label: 'Delete permanently', danger: true, msg: (n) => `This permanently deletes ${n}'s account. This can't be undone.` },
  };

  const SortHeader = ({ label, sortField }) => (
    <button onClick={() => handleSort(sortField)} className="flex items-center gap-1 hover:text-[#1E3A2B]">
      {label}
      <ArrowUpDown size={12} className={sortKey === sortField ? 'text-[#2D5A40]' : 'text-gray-300'} />
    </button>
  );

  return (
    <div className="flex-1">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[#1E3A2B]">User Management</h1>
          <p className="text-sm text-gray-500">
            {loading ? 'Loading users…' : `${filtered.length} of ${users.length} accounts`}
          </p>
        </div>
        <div className="relative">
          <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
          <input
            type="text"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search by name or email…"
            className="pl-10 pr-4 py-2 bg-white rounded-xl border border-gray-200 text-sm w-64 focus:outline-none focus:ring-2 focus:ring-[#4E9F6E]"
          />
        </div>
      </div>

      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-5 mb-6">
          <StatCard icon={Users} label="Total Users" value={stats.totalUsers} accent="bg-[#EAF4EE] text-[#1E3A2B]" />
          <StatCard icon={ShieldCheck} label="Admins" value={stats.totalAdmins} accent="bg-[#EAF4EE] text-[#1E3A2B]" />
          <StatCard icon={Sprout} label="Farmers" value={stats.totalFarmers} accent="bg-[#EAF4EE] text-[#1E3A2B]" />
          <StatCard icon={ShoppingBag} label="Customers" value={stats.totalCustomers} accent="bg-[#EAF4EE] text-[#1E3A2B]" />
        </div>
      )}

      <div className="flex gap-2 mb-5">
        {ROLE_FILTERS.map((r) => (
          <button
            key={r}
            onClick={() => { setRoleFilter(r); setPage(1); }}
            className={`px-4 py-1.5 rounded-full text-xs font-semibold transition-all ${
              roleFilter === r ? 'bg-[#1E3A2B] text-white' : 'bg-white text-gray-500 border border-gray-200 hover:bg-[#EAF4EE]'
            }`}
          >
            {r === 'ALL' ? 'All Users' : r.charAt(0) + r.slice(1).toLowerCase()}
          </button>
        ))}
      </div>

      {error && (
        <div className="mb-5 p-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchAll} className="font-semibold underline">Retry</button>
        </div>
      )}

      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[#F4F7F4] text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <th className="px-6 py-3"><SortHeader label="Name" sortField="fullName" /></th>
                <th className="px-6 py-3">Email</th>
                <th className="px-6 py-3"><SortHeader label="Role" sortField="role" /></th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3"><SortHeader label="Joined" sortField="createdAt" /></th>
                <th className="px-6 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading && (
                <tr>
                  <td colSpan={6} className="px-6 py-10 text-center text-gray-400">
                    <Loader2 className="animate-spin inline mr-2" size={18} />
                    Loading users…
                  </td>
                </tr>
              )}

              {!loading && paged.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-10 text-center text-gray-400">
                    No users match this search or filter.
                  </td>
                </tr>
              )}

              {!loading && paged.map((u) => (
                <tr key={u.id} onClick={() => setSelectedUser(u)} className="hover:bg-[#F4F7F4]/60 transition-colors cursor-pointer">
                  <td className="px-6 py-4 font-semibold text-[#1E3A2B]">{u.fullName}</td>
                  <td className="px-6 py-4 text-gray-500">{u.email}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${ROLE_STYLES[u.role] || ''}`}>
                      {u.role}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${STATUS_STYLES[u.status] || ''}`}>
                      {u.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-400 text-xs">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4" onClick={(e) => e.stopPropagation()}>
                    <div className="flex justify-end gap-1.5">
                      {actionLoadingId === u.id ? (
                        <Loader2 className="animate-spin text-gray-400 mx-2" size={18} />
                      ) : (
                        <>
                          {u.status !== 'ACTIVE' && (
                            <button title="Activate" onClick={() => setConfirmAction({ type: 'activate', user: u })} className="p-2 rounded-lg text-[#2D5A40] hover:bg-[#EAF4EE]">
                              <UserCheck size={16} />
                            </button>
                          )}
                          {u.status !== 'INACTIVE' && (
                            <button title="Deactivate" onClick={() => setConfirmAction({ type: 'deactivate', user: u })} className="p-2 rounded-lg text-[#E65100] hover:bg-[#FFF3E0]">
                              <UserX size={16} />
                            </button>
                          )}
                          {u.status !== 'BLOCKED' && (
                            <button title="Block" onClick={() => setConfirmAction({ type: 'block', user: u })} className="p-2 rounded-lg text-red-600 hover:bg-red-50">
                              <ShieldOff size={16} />
                            </button>
                          )}
                          <button title="Delete" onClick={() => setConfirmAction({ type: 'delete', user: u })} className="p-2 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-red-600">
                            <Trash2 size={16} />
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!loading && filtered.length > 0 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-gray-100">
            <p className="text-xs text-gray-400">Page {page} of {totalPages}</p>
            <div className="flex gap-2">
              <button onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1} className="p-2 rounded-lg border border-gray-200 text-gray-500 disabled:opacity-40 hover:bg-[#F4F7F4]">
                <ChevronLeft size={16} />
              </button>
              <button onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page === totalPages} className="p-2 rounded-lg border border-gray-200 text-gray-500 disabled:opacity-40 hover:bg-[#F4F7F4]">
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {confirmAction && (
        <ConfirmDialog
          title={confirmCopy[confirmAction.type].title}
          message={confirmCopy[confirmAction.type].msg(confirmAction.user.fullName)}
          confirmLabel={confirmCopy[confirmAction.type].label}
          danger={confirmCopy[confirmAction.type].danger}
          onConfirm={handleConfirmed}
          onCancel={() => setConfirmAction(null)}
        />
      )}

      {selectedUser && (
        <UserDetailModal
          user={selectedUser}
          onClose={() => setSelectedUser(null)}
          onRoleChange={handleRoleChange}
          roleChanging={roleChanging}
        />
      )}

      {toast && (
        <div className="fixed bottom-6 right-6 bg-[#1E3A2B] text-white text-sm px-5 py-3 rounded-xl shadow-lg flex items-center gap-3 z-50">
          {toast}
          <button onClick={() => setToast('')}><X size={14} /></button>
        </div>
      )}
    </div>
  );
};

export default UserManagement;