import { useCallback, useEffect, useId, useRef, useState } from 'react';

import {
  AlertCircle,
  CheckCircle2,
  Clock3,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  Tractor,
  Trash2,
  Truck,
  Wheat,
  X,
} from 'lucide-react';

import api from '../../services/api';
import '../Categories/CategoryManagement.css';
import '../Products/ProductManagement.css';

const CATEGORIES = [
  { value: 'MACHINERY', label: 'Machinery & Land Prep', icon: Tractor, unit: 'acre' },
  { value: 'INPUTS', label: 'Seeds & Fertilizer', icon: Wheat, unit: 'acre' },
  { value: 'TRANSPORT', label: 'Transport & Logistics', icon: Truck, unit: 'km' },
];

const EMPTY_FORM = {
  name: '',
  description: '',
  category: 'MACHINERY',
  baseRate: '',
  minimumCharge: '',
  cropType: '',
  quantityPerAcreKg: '',
  maxLoadKg: '',
  ratePerExtraKg: '',
  isActive: true,
};

function categoryMeta(value) {
  return CATEGORIES.find((c) => c.value === value) ?? CATEGORIES[0];
}

function getError(error) {
  if (error.response?.status === 403) {
    return 'Only active administrators can manage packages.';
  }

  const data = error.response?.data;

  if (data?.message) return data.message;

  if (data?.errors) {
    return Object.values(data.errors).flat().join(' ');
  }

  return 'The request failed. Please try again.';
}

function Notice({ text, error = false }) {
  if (!text) return null;

  return (
    <div
      className={`cat-notice cat-notice-${error ? 'error' : 'success'}`}
      role={error ? 'alert' : 'status'}
    >
      {error ? <AlertCircle size={18} /> : <CheckCircle2 size={18} />}
      <span>{text}</span>
    </div>
  );
}

function Modal({ title, busy, onClose, children, wide = false }) {
  const ref = useRef(null);
  const titleId = useId();

  useEffect(() => {
    const dialog = ref.current;
    dialog.showModal();

    return () => {
      if (dialog.open) dialog.close();
    };
  }, []);

  return (
    <dialog
      ref={ref}
      className={`cat-dialog product-modal ${wide ? 'product-modal-wide' : ''}`}
      aria-labelledby={titleId}
      onCancel={(event) => {
        event.preventDefault();
        if (!busy) onClose();
      }}
    >
      <div className="product-modal-heading">
        <h2 id={titleId}>{title}</h2>
        <button
          type="button"
          className="cat-icon-button"
          onClick={onClose}
          disabled={busy}
          aria-label="Close dialog"
        >
          <X size={20} />
        </button>
      </div>

      {children}
    </dialog>
  );
}

function money(value) {
  return new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 2,
  }).format(Number(value) || 0);
}

// ---------------------------------------------------------------------------
// Package create/edit form
// ---------------------------------------------------------------------------

function PackageForm({ pkg, onClose, onSaved }) {
  const [form, setForm] = useState(
    pkg
      ? {
          name: pkg.name,
          description: pkg.description,
          category: pkg.category,
          baseRate: String(pkg.baseRate ?? ''),
          minimumCharge: pkg.minimumCharge == null ? '' : String(pkg.minimumCharge),
          cropType: pkg.cropType ?? '',
          quantityPerAcreKg:
            pkg.quantityPerAcreKg == null ? '' : String(pkg.quantityPerAcreKg),
          maxLoadKg: pkg.maxLoadKg == null ? '' : String(pkg.maxLoadKg),
          ratePerExtraKg: pkg.ratePerExtraKg == null ? '' : String(pkg.ratePerExtraKg),
          isActive: pkg.isActive,
        }
      : EMPTY_FORM,
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const isInputs = form.category === 'INPUTS';
  const isTransport = form.category === 'TRANSPORT';

  const set = (key) => (event) => {
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    setForm((current) => ({ ...current, [key]: value }));
  };

  const submit = async (event) => {
    event.preventDefault();
    if (busy) return;

    setBusy(true);
    setError('');

    const payload = {
      name: form.name.trim(),
      description: form.description.trim(),
      category: form.category,
      baseRate: Number(form.baseRate),
      minimumCharge: form.minimumCharge.trim() === '' ? null : Number(form.minimumCharge),
      cropType: isInputs ? form.cropType.trim() : null,
      quantityPerAcreKg:
        isInputs && form.quantityPerAcreKg.trim() !== ''
          ? Number(form.quantityPerAcreKg)
          : null,
      maxLoadKg: isTransport && form.maxLoadKg.trim() !== '' ? Number(form.maxLoadKg) : null,
      ratePerExtraKg:
        isTransport && form.ratePerExtraKg.trim() !== '' ? Number(form.ratePerExtraKg) : null,
      isActive: form.isActive,
    };

    try {
      const response = pkg
        ? await api.put(`/packages/${pkg.id}`, payload)
        : await api.post('/packages', payload);

      onSaved(response.data);
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title={pkg ? 'Edit package' : 'New package'} busy={busy} onClose={onClose}>
      <form className="cat-form" onSubmit={submit}>
        <label className="cat-field">
          <span>Category</span>
          <select value={form.category} onChange={set('category')} disabled={busy}>
            {CATEGORIES.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </select>
        </label>

        <label className="cat-field">
          <span>Package name</span>
          <input value={form.name} onChange={set('name')} required disabled={busy} />
        </label>

        <label className="cat-field">
          <span>Description</span>
          <textarea
            rows={3}
            value={form.description}
            onChange={set('description')}
            required
            disabled={busy}
          />
        </label>

        <div className="product-fields" style={{ gridTemplateColumns: "1fr 1fr", display: "grid", gap: 12 }}>
          <label className="cat-field">
            <span>Price per {categoryMeta(form.category).unit} (Rs.)</span>
            <input
              type="number"
              min="0.01"
              step="0.01"
              value={form.baseRate}
              onChange={set('baseRate')}
              required
              disabled={busy}
            />
          </label>

          <label className="cat-field">
            <span>Minimum charge (Rs., optional)</span>
            <input
              type="number"
              min="0"
              step="0.01"
              value={form.minimumCharge}
              onChange={set('minimumCharge')}
              disabled={busy}
            />
          </label>
        </div>

        {isInputs && (
          <div className="product-fields" style={{ gridTemplateColumns: "1fr 1fr", display: "grid", gap: 12 }}>
            <label className="cat-field">
              <span>Crop type</span>
              <input
                value={form.cropType}
                onChange={set('cropType')}
                placeholder="e.g. Paddy"
                required
                disabled={busy}
              />
            </label>

            <label className="cat-field">
              <span>Quantity per acre (kg)</span>
              <input
                type="number"
                min="0.01"
                step="0.01"
                value={form.quantityPerAcreKg}
                onChange={set('quantityPerAcreKg')}
                required
                disabled={busy}
              />
            </label>
          </div>
        )}

        {isTransport && (
          <div className="product-fields" style={{ gridTemplateColumns: "1fr 1fr", display: "grid", gap: 12 }}>
            <label className="cat-field">
              <span>Max load included (kg)</span>
              <input
                type="number"
                min="0.01"
                step="0.01"
                value={form.maxLoadKg}
                onChange={set('maxLoadKg')}
                required
                disabled={busy}
              />
            </label>

            <label className="cat-field">
              <span>Rate per extra kg (Rs., optional)</span>
              <input
                type="number"
                min="0"
                step="0.01"
                value={form.ratePerExtraKg}
                onChange={set('ratePerExtraKg')}
                disabled={busy}
              />
            </label>
          </div>
        )}

        <label className="cat-field" style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
          <input type="checkbox" checked={form.isActive} onChange={set('isActive')} disabled={busy} />
          <span>Visible to farmers</span>
        </label>

        {error && <Notice text={error} error />}

        <div className="product-form-actions">
          <button type="button" className="cat-button" onClick={onClose} disabled={busy}>
            Cancel
          </button>
          <button type="submit" className="cat-button cat-button-primary" disabled={busy}>
            {busy ? <Loader2 size={16} className="cat-spin" /> : pkg ? 'Save changes' : 'Create package'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Delete confirmation
// ---------------------------------------------------------------------------

function DeleteDialog({ pkg, busy, onCancel, onConfirm }) {
  return (
    <Modal title="Delete package" busy={busy} onClose={onCancel}>
      <div className="cat-form">
        <p>
          Delete <strong>{pkg.name}</strong>? If it already has bookings it will be hidden from
          farmers instead of removed, to keep booking history intact.
        </p>
        <div className="product-form-actions">
          <button type="button" className="cat-button" onClick={onCancel} disabled={busy}>
            Cancel
          </button>
          <button
            type="button"
            className="cat-button cat-button-danger"
            onClick={onConfirm}
            disabled={busy}
          >
            {busy ? <Loader2 size={16} className="cat-spin" /> : 'Delete'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function PackageManagement() {
  const [view, setView] = useState('packages'); // 'packages' | 'bookings'

  const [packages, setPackages] = useState([]);
  const [bookings, setBookings] = useState([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [category, setCategory] = useState('ALL');
  const [search, setSearch] = useState('');

  const [editor, setEditor] = useState(undefined); // undefined=closed, null=create, pkg=edit
  const [deleting, setDeleting] = useState(null);
  const [reviewing, setReviewing] = useState(null); // { booking, action }
  const [reviewNote, setReviewNote] = useState('');
  const [reviewBusy, setReviewBusy] = useState(false);

  const load = useCallback(async (activeView, signal) => {
    setLoading(true);
    setError('');

    try {
      if (activeView === 'bookings') {
        const response = await api.get('/packages/bookings/pending', { signal });
        if (!signal?.aborted) setBookings(response.data);
      } else {
        const response = await api.get('/packages', { signal });
        if (!signal?.aborted) setPackages(response.data);
      }
    } catch (requestError) {
      if (!signal?.aborted) setError(getError(requestError));
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    load(view, controller.signal);
    return () => controller.abort();
  }, [load, view]);

  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(''), 3000);
    return () => clearTimeout(timer);
  }, [notice]);

  const filtered = packages.filter((p) => {
    if (category !== 'ALL' && p.category !== category) return false;
    if (search.trim() && !p.name.toLowerCase().includes(search.trim().toLowerCase())) return false;
    return true;
  });

  const handleSaved = (saved) => {
    setPackages((current) => [saved, ...current.filter((p) => p.id !== saved.id)]);
    setEditor(undefined);
    setNotice(editor === null ? 'Package created.' : 'Package updated.');
  };

  const handleDelete = async () => {
    if (!deleting) return;

    setError('');
    try {
      await api.delete(`/packages/${deleting.id}`, { params: { version: deleting.version } });
      setPackages((current) => current.filter((p) => p.id !== deleting.id));
      setNotice('Package removed.');
      setDeleting(null);
    } catch (requestError) {
      setError(getError(requestError));
      setDeleting(null);
    }
  };

  const submitReview = async () => {
    if (!reviewing) return;

    if (reviewing.action === 'reject' && reviewNote.trim().length < 3) {
      setError('Enter a short note explaining the rejection.');
      return;
    }

    setReviewBusy(true);
    setError('');

    try {
      await api.post(`/packages/bookings/${reviewing.booking.id}/${reviewing.action}`, {
        version: reviewing.booking.version,
        adminNote: reviewNote.trim() || null,
      });

      setBookings((current) => current.filter((b) => b.id !== reviewing.booking.id));
      setNotice(reviewing.action === 'approve' ? 'Booking confirmed.' : 'Booking rejected.');
      setReviewing(null);
      setReviewNote('');
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setReviewBusy(false);
    }
  };

  return (
    <div className="category-page product-page">
      <header className="cat-header">
        <div>
          <div className="cat-eyebrow">
            <Tractor size={16} />
            Farmer packages
          </div>
          <h1>Packages</h1>
          <p>Machinery, seeds &amp; fertilizer, and transport packages for farmers.</p>
        </div>

        {view === 'packages' && (
          <button
            type="button"
            className="cat-button cat-button-primary"
            onClick={() => setEditor(null)}
          >
            <Plus size={18} />
            New package
          </button>
        )}
      </header>

      <div className="cat-filters" role="group" aria-label="Package view" style={{ marginBottom: 16 }}>
        <button
          type="button"
          className={view === 'packages' ? 'is-selected' : ''}
          aria-pressed={view === 'packages'}
          onClick={() => setView('packages')}
        >
          All packages
        </button>
        <button
          type="button"
          className={view === 'bookings' ? 'is-selected' : ''}
          aria-pressed={view === 'bookings'}
          onClick={() => setView('bookings')}
        >
          Booking requests
        </button>
      </div>

      <Notice text={notice} />
      {error && <Notice text={error} error />}

      {view === 'packages' ? (
        <section className="cat-card">
          <div className="cat-card-heading">
            <div>
              <h2>Package directory</h2>
              <p>Only active packages are visible to farmers.</p>
            </div>

            <div className="cat-toolbar">
              <div className="cat-search">
                <Search size={16} />
                <input
                  placeholder="Search packages..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <button
                type="button"
                className="cat-icon-button"
                onClick={() => load('packages')}
                title="Refresh"
              >
                <RefreshCw size={16} />
              </button>
            </div>
          </div>

          <div className="cat-filters" role="group" aria-label="Category">
            {['ALL', ...CATEGORIES.map((c) => c.value)].map((value) => (
              <button
                key={value}
                type="button"
                className={category === value ? 'is-selected' : ''}
                aria-pressed={category === value}
                onClick={() => setCategory(value)}
              >
                {value === 'ALL' ? 'All categories' : categoryMeta(value).label}
              </button>
            ))}
          </div>

          {loading ? (
            <div className="cat-table-scroll">
              <Loader2 size={20} className="cat-spin" />
            </div>
          ) : filtered.length === 0 ? (
            <p className="cat-empty">No packages match your filters.</p>
          ) : (
            <div className="cat-table-scroll">
              <table className="cat-table product-table">
                <thead>
                  <tr>
                    <th>Package</th>
                    <th>Category</th>
                    <th>Rate</th>
                    <th>Status</th>
                    <th aria-label="Actions" />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((pkg) => {
                    const meta = categoryMeta(pkg.category);
                    const Icon = meta.icon;

                    return (
                      <tr key={pkg.id}>
                        <td>
                          <div className="cat-category-text">
                            <strong>{pkg.name}</strong>
                            <p>{pkg.description}</p>
                          </div>
                        </td>
                        <td>
                          <span
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                              fontSize: 13,
                              color: '#4B5F52',
                            }}
                          >
                            <Icon size={14} /> {meta.label}
                          </span>
                        </td>
                        <td className="product-price">
                          <strong>{money(pkg.baseRate)}</strong>
                          <small>per {meta.unit}</small>
                          {pkg.minimumCharge && (
                            <div style={{ fontSize: 12, color: '#8A9A8F' }}>
                              Min {money(pkg.minimumCharge)}
                            </div>
                          )}
                        </td>
                        <td>
                          <span className={`product-status status-${pkg.isActive ? 'approved' : 'rejected'}`}>
                            <span aria-hidden="true" />
                            {pkg.isActive ? 'Active' : 'Hidden'}
                          </span>
                        </td>
                        <td>
                          <div className="cat-row-actions">
                            <button
                              type="button"
                              className="cat-icon-button"
                              onClick={() => setEditor(pkg)}
                              title="Edit package"
                              aria-label={`Edit ${pkg.name}`}
                            >
                              <Pencil size={16} />
                            </button>
                            <button
                              type="button"
                              className="cat-icon-button cat-delete-button"
                              onClick={() => setDeleting(pkg)}
                              title="Delete package"
                              aria-label={`Delete ${pkg.name}`}
                            >
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : (
        <section className="cat-card">
          <div className="cat-card-heading">
            <div>
              <h2>Booking requests</h2>
              <p>Every farmer's pending booking, across all packages.</p>
            </div>
          </div>

          {loading ? (
            <div className="cat-table-scroll">
              <Loader2 size={20} className="cat-spin" />
            </div>
          ) : bookings.length === 0 ? (
            <p className="cat-empty">No pending booking requests.</p>
          ) : (
            <div className="cat-table-scroll">
              <table className="cat-table product-table">
                <thead>
                  <tr>
                    <th>Package</th>
                    <th>Farmer</th>
                    <th>Details</th>
                    <th>Total</th>
                    <th aria-label="Actions" />
                  </tr>
                </thead>
                <tbody>
                  {bookings.map((booking) => (
                    <tr key={booking.id}>
                      <td>
                        <div className="cat-category-text">
                          <strong>{booking.packageName}</strong>
                          <p>{categoryMeta(booking.category).label}</p>
                        </div>
                      </td>
                      <td>{booking.farmerName}</td>
                      <td style={{ fontSize: 13, color: '#4B5F52' }}>
                        {booking.landSizeAcres && `${booking.landSizeAcres} acres`}
                        {booking.distanceKm && `${booking.distanceKm} km`}
                        {booking.loadWeightKg ? `, ${booking.loadWeightKg} kg load` : ''}
                        {booking.notes && <div>&ldquo;{booking.notes}&rdquo;</div>}
                      </td>
                      <td className="product-price">
                        <strong>{money(booking.totalPrice)}</strong>
                        <small>{booking.calculatedQuantity} units</small>
                      </td>
                      <td>
                        <div className="cat-row-actions">
                          <button
                            type="button"
                            className="cat-icon-button"
                            style={{ color: '#2E7D46' }}
                            onClick={() => setReviewing({ booking, action: 'approve' })}
                            title="Approve"
                          >
                            <CheckCircle2 size={16} />
                          </button>
                          <button
                            type="button"
                            className="cat-icon-button cat-delete-button"
                            onClick={() => setReviewing({ booking, action: 'reject' })}
                            title="Reject"
                          >
                            <X size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {editor !== undefined && (
        <PackageForm pkg={editor} onClose={() => setEditor(undefined)} onSaved={handleSaved} />
      )}

      {deleting && (
        <DeleteDialog
          pkg={deleting}
          busy={false}
          onCancel={() => setDeleting(null)}
          onConfirm={handleDelete}
        />
      )}

      {reviewing && (
        <Modal
          title={reviewing.action === 'approve' ? 'Confirm booking' : 'Reject booking'}
          busy={reviewBusy}
          onClose={() => setReviewing(null)}
        >
          <div className="cat-form">
            <p>
              <strong>{reviewing.booking.packageName}</strong> for {reviewing.booking.farmerName} —{' '}
              {money(reviewing.booking.totalPrice)}
            </p>

            <label className="cat-field">
              <span>
                Note {reviewing.action === 'reject' ? '(required)' : '(optional)'}
              </span>
              <textarea
                rows={3}
                value={reviewNote}
                onChange={(e) => setReviewNote(e.target.value)}
                placeholder={
                  reviewing.action === 'reject'
                    ? 'Explain why this booking is rejected...'
                    : 'Any note for the farmer...'
                }
                disabled={reviewBusy}
              />
            </label>

            <div className="product-form-actions">
              <button type="button" className="cat-button" onClick={() => setReviewing(null)} disabled={reviewBusy}>
                Cancel
              </button>
              <button
                type="button"
                className={`cat-button ${reviewing.action === 'approve' ? 'cat-button-primary' : 'cat-button-danger'}`}
                onClick={submitReview}
                disabled={reviewBusy}
              >
                {reviewBusy ? (
                  <Loader2 size={16} className="cat-spin" />
                ) : reviewing.action === 'approve' ? (
                  'Confirm booking'
                ) : (
                  'Reject booking'
                )}
              </button>
            </div>
          </div>
        </Modal>
      )}

      <p className="cat-hint">
        <Clock3 size={13} /> Prices are calculated by the server from each package's rate — never
        trust a client-supplied total.
      </p>
    </div>
  );
}
