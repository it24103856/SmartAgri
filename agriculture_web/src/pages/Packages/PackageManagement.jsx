import { useCallback, useEffect, useId, useRef, useState } from 'react';

import {
  AlertCircle,
  CheckCircle2,
  Clock3,
  Loader2,
  ImagePlus,
  Leaf,
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
import './PackageManagement.css';
import PackagePaymentReview from './PackagePaymentReview';
import { categoryMeta, CATEGORIES, money } from './packageUtils';

const CATEGORY_ICONS = { MACHINERY: Tractor, INPUTS: Wheat, TRANSPORT: Truck };
const packageCategoryMeta = (value) => ({
  ...categoryMeta(value),
  icon: CATEGORY_ICONS[categoryMeta(value).value],
});

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

function getError(error) {
  if (error.response?.status === 413) return 'Choose up to 6 images, no larger than 5 MB each.';
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

function Modal({ title, busy, onClose, children, wide = false, className = '' }) {
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
      className={`cat-dialog product-modal ${wide ? 'product-modal-wide' : ''} ${className}`}
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

// ---------------------------------------------------------------------------
// Package create/edit form
// ---------------------------------------------------------------------------

function packageImageSource(path) {
  return new URL(path, new URL(api.defaults.baseURL, window.location.origin).origin).href;
}

function PackageImagePreview({ image, alt = '' }) {
  const ref = useRef(null);
  useEffect(() => {
    const source = image.file ? URL.createObjectURL(image.file) : packageImageSource(image.url);
    ref.current.src = source;
    return () => { if (image.file) URL.revokeObjectURL(source); };
  }, [image]);
  return <img ref={ref} alt={alt} className="package-photo" />;
}

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

  const [images, setImages] = useState(() => (pkg?.imageUrls ?? []).map((url) => ({ id: url, url })));

  const addImages = (event) => {
    const files = Array.from(event.target.files ?? []);
    event.target.value = '';
    if (files.length + images.length > 6) {
      setError('Choose up to 6 images per package.');
      return;
    }
    if (files.some((file) => !['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size === 0 || file.size > 5 * 1024 * 1024)) {
      setError('Choose JPG, PNG or WebP images, up to 5 MB each.');
      return;
    }
    setImages((current) => [...current, ...files.map((file) => ({ id: crypto.randomUUID(), file }))]);
    setError('');
  };

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
      const body = new FormData();
      Object.entries(payload).forEach(([key, value]) => {
        if (value !== null) body.append(key, String(value));
      });
      let uploadIndex = 0;
      const order = images.map((image) => {
        if (!image.file) return image.url;
        body.append('Images', image.file);
        return `new:${uploadIndex++}`;
      });
      body.append('ImageOrderJson', JSON.stringify(order));
      if (pkg) body.append('Version', pkg.version);
      const response = pkg
        ? await api.put(`/packages/${pkg.id}/with-images`, body)
        : await api.post('/packages/with-images', body);

      onSaved(response.data);
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title={pkg ? 'Edit package' : 'New package'} busy={busy} onClose={onClose} wide className="package-editor-modal">
      <form className="cat-form package-form" onSubmit={submit}>
        <div className="package-form-intro">
          <span className="package-intro-icon"><Leaf size={24} /></span>
          <div><strong>Support a better harvest.</strong><p>Add a service farmers can discover, explore and book.</p></div>
        </div>
        <div className="package-form-layout">
        <div className="package-form-main">
        <section className="package-form-section">
          <h3><span>01</span> Package details</h3>
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
          <input value={form.name} onChange={set('name')} placeholder="e.g. Harvest transport" minLength={2} maxLength={150} required disabled={busy} />
        </label>

        <label className="cat-field">
          <span>Description</span>
          <textarea
            rows={4}
            maxLength={2000}
            placeholder="Describe what is included and how it helps the farmer."
            value={form.description}
            onChange={set('description')}
            required
            disabled={busy}
          />
        </label>

        </section>
        <section className="package-form-section">
          <h3><span>02</span> Pricing & requirements</h3>
        <div className="package-fields">
          <label className="cat-field">
            <span>Price per {packageCategoryMeta(form.category).unit} (Rs.)</span>
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
          <div className="package-fields">
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
          <div className="package-fields">
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

        </section>
        </div>
        <aside className="package-form-side">
        <section className="package-image-editor" aria-label="Package images">
          <h3><span>03</span> Photo gallery</h3>
          <label className="package-upload-zone">
            <ImagePlus size={28} />
            <strong>Add package photos</strong>
            <span>Choose JPG, PNG or WebP images</span>
            <input type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={addImages} disabled={busy || images.length >= 6} aria-describedby="package-images-help" />
          </label>
          <p id="package-images-help">Up to 6 images, 5 MB each. The cover appears on the farmer dashboard.</p>
          <div className="package-image-grid">
            {images.map((image, index) => (
              <div className="package-image-item" key={image.id}>
                <PackageImagePreview image={image} alt={`Package image ${index + 1}`} />
                <div className="package-image-actions">
                  <button type="button" className={`cat-button ${index === 0 ? 'cat-button-primary' : ''}`} disabled={busy || index === 0}
                    onClick={() => setImages((current) => [image, ...current.filter((entry) => entry.id !== image.id)])}>
                    {index === 0 ? 'Cover image' : 'Set as cover'}
                  </button>
                  <button type="button" className="cat-icon-button cat-delete-button" disabled={busy}
                    aria-label={`Remove image ${index + 1}`} onClick={() => setImages((current) => current.filter((entry) => entry.id !== image.id))}>
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>

        <label className="package-visibility">
          <input type="checkbox" checked={form.isActive} onChange={set('isActive')} disabled={busy} />
          <span><strong>Visible to farmers</strong><small>Turn off to keep this package hidden.</small></span>
        </label>
        </aside>
        </div>

        {error && <Notice text={error} error />}

        <div className="product-form-actions package-form-footer">
          <span>{images.length} / 6 photos added</span>
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
        const response = await api.get('/packages/bookings', { signal });
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
    if (!reviewing || reviewBusy) return;

    if (reviewing.action === 'reject' && reviewNote.trim().length < 3) {
      setError('Enter a short note explaining the rejection.');
      return;
    }

    setReviewBusy(true);
    setError('');

    try {
      const response = await api.post(
        `/packages/bookings/${reviewing.booking.id}/${reviewing.action}`,
        {
          version: reviewing.booking.version,
          adminNote: reviewNote.trim() || null,
        },
      );

      setBookings((current) =>
        current.map((booking) =>
          booking.id === response.data.id ? response.data : booking,
        ),
      );

      const messages = {
        approve: 'Booking approved. Advance payment is required for new bookings.',
        reject: 'Booking rejected.',
        complete: 'Booking completed.',
      };

      setNotice(messages[reviewing.action]);
      setReviewing(null);
      setReviewNote('');
    } catch (requestError) {
      if (requestError.response?.status === 409) {
        setReviewing(null);
        await load('bookings');
      }
      setError(getError(requestError));
    } finally {
      setReviewBusy(false);
    }
  };

  const reviewLabels = {
    approve: 'Confirm booking',
    reject: 'Reject booking',
    complete: 'Mark completed',
  };

  const openReview = (booking, action) => {
    setReviewNote('');
    setError('');
    setReviewing({ booking, action });
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
      {view === 'bookings' && (
        <PackagePaymentReview onReviewed={() => load('bookings')} />
      )}

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
                    <th aria-label="    Actions" />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((pkg) => {
                    const meta = packageCategoryMeta(pkg.category);
                    const Icon = meta.icon;

                    return (
                      <tr key={pkg.id}>
                        <td>
                          <div className="package-table-name">
                            {pkg.imageUrls?.[0] ? <img className="package-table-cover" src={packageImageSource(pkg.imageUrls[0])} alt="" /> : <span className="cat-avatar"><Icon size={24} /></span>}
                            <div className="cat-category-text">
                              <strong>{pkg.name}</strong>
                              <p>{pkg.description}</p>
                            </div>
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
      <h2>Service bookings</h2>
      <p>Review requests and track confirmed, completed and cancelled services.</p>
    </div>

    <button
      type="button"
      className="cat-button"
      onClick={() => load('bookings')}
      disabled={loading || reviewBusy}
    >
      Refresh
    </button>
  </div>

  {loading ? (
    <div className="cat-table-scroll">
      <Loader2 size={20} className="cat-spin" />
    </div>
  ) : bookings.length === 0 ? (
    <p className="cat-empty">No bookings yet.</p>
  ) : (
    <div className="cat-table-scroll">
      <table className="cat-table product-table">
        <thead>
          <tr>
            <th>Package / Farmer</th>
            <th>Farm / Date</th>
            <th>Details</th>
            <th>Total</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>

        <tbody>
          {bookings.map((booking) => (
            <tr key={booking.id}>
              <td>
                <strong>{booking.packageName}</strong>
                <div>{booking.farmerName}</div>
                <small>Booking #{booking.id}</small>
              </td>

              <td>
                <strong>{booking.farmName || 'Not recorded'}</strong>
                <div>{booking.farmLocation || 'Location not recorded'}</div>
                <div>{booking.serviceDate || 'Date not recorded'}</div>
              </td>

              <td>
                {booking.landSizeAcres != null && (
                  <div>{booking.landSizeAcres} acres</div>
                )}
                {booking.distanceKm != null && (
                  <div>{booking.distanceKm} km</div>
                )}
                {booking.loadWeightKg != null && (
                  <div>{booking.loadWeightKg} kg load</div>
                )}
                {booking.category === 'INPUTS' && (
                  <div>{booking.calculatedQuantity} kg supply</div>
                )}
                {booking.notes && <div>Farmer: {booking.notes}</div>}
                {booking.adminNote && <div>Admin: {booking.adminNote}</div>}
              </td>

              <td>{money(booking.totalPrice)}</td>
              <td>
                <div>
                  {booking.status === 'AWAITING_PAYMENT'
                    ? 'Awaiting advance payment'
                    : booking.status}
                </div>
                {booking.requiresAdvancePayment && (
                  <>
                    <small>{booking.paymentStatus}</small>
                    <div>Paid: {money(booking.amountPaid)}</div>
                    <div>
                      Outstanding: {money(booking.totalPrice - booking.amountPaid)}
                    </div>
                  </>
                )}
              </td>

              <td>
                <div className="cat-row-actions">
                  {booking.status === 'PENDING' && (
                    <>
                      <button
                        type="button"
                        className="cat-button cat-button-primary"
                        disabled={reviewBusy}
                        onClick={() => openReview(booking, 'approve')}
                      >
                        Approve
                      </button>

                      <button
                        type="button"
                        className="cat-button cat-button-danger"
                        disabled={reviewBusy}
                        onClick={() => openReview(booking, 'reject')}
                      >
                        Reject
                      </button>
                    </>
                  )}

                  {booking.status === 'CONFIRMED' && (
                    <button
                      type="button"
                      className="cat-button cat-button-primary"
                      disabled={reviewBusy}
                      onClick={() => openReview(booking, 'complete')}
                    >
                      Mark completed
                    </button>
                  )}
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
          title={reviewLabels[reviewing.action]}
          busy={reviewBusy}
          onClose={() => {
            if (!reviewBusy) setReviewing(null);
          }}
        >
          <div className="cat-form">
            <p>
              <strong>{reviewing.booking.packageName}</strong>
              {' — '}
              {reviewing.booking.farmerName}
            </p>

            <p>
              Farm: {reviewing.booking.farmName || 'Not recorded'}
              <br />
              Service date: {reviewing.booking.serviceDate || 'Not recorded'}
              <br />
              Total: {money(reviewing.booking.totalPrice)}
            </p>

            {reviewing.action === 'complete' && (
              <p>Confirm that this service has actually been delivered.</p>
            )}

            <label className="cat-field">
              <span>
                Admin note {reviewing.action === 'reject' ? '(required)' : '(optional)'}
              </span>
              <textarea
                rows={3}
                maxLength={500}
                value={reviewNote}
                onChange={(event) => setReviewNote(event.target.value)}
                disabled={reviewBusy}
              />
            </label>

            <div className="product-form-actions">
              <button
                type="button"
                className="cat-button"
                onClick={() => setReviewing(null)}
                disabled={reviewBusy}
              >
                Close
              </button>

              <button
                type="button"
                className={`cat-button ${
                  reviewing.action === 'reject'
                    ? 'cat-button-danger'
                    : 'cat-button-primary'
                }`}
                onClick={submitReview}
                disabled={reviewBusy}
              >
                {reviewBusy ? 'Saving...' : reviewLabels[reviewing.action]}
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
