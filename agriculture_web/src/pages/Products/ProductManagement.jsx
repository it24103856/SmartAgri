import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';

import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Eye,
  Loader2,
  Package,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  Trash2,
  Upload,
  X,
} from 'lucide-react';

import api from '../../services/api';
import '../Categories/CategoryManagement.css';
import './ProductManagement.css';

const PAGE_SIZE = 6;

const UNITS = [
  ['kg', 'Kilogram'],
  ['g', 'Gram'],
  ['piece', 'Piece'],
  ['pack', 'Pack'],
  ['litre', 'Litre'],
];

const money = new Intl.NumberFormat('en-LK', {
  style: 'currency',
  currency: 'LKR',
  minimumFractionDigits: 2,
});

const apiOrigin = new URL(
  api.defaults.baseURL || 'http://localhost:5000/api',
  window.location.origin
).origin;

function imageSource(path) {
  if (!path) return '';

  try {
    const url = new URL(path, apiOrigin);

    return ['http:', 'https:'].includes(url.protocol)
      ? url.href
      : '';
  } catch {
    return '';
  }
}

function getError(error) {
  if (error.response?.status === 403) {
    return 'Only active administrators can manage products.';
  }

  const data = error.response?.data;

  if (data?.message) return data.message;

  if (data?.errors) {
    return Object.values(data.errors).flat().join(' ');
  }

  if (error.response?.status === 413) {
    return 'The upload is too large. Use up to 5 images, 5 MB each.';
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

function StatusBadge({ status }) {
  return (
    <span className={`product-status status-${status.toLowerCase()}`}>
      <span aria-hidden="true" />
      {status}
    </span>
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
      className={`cat-dialog product-modal ${
        wide ? 'product-modal-wide' : ''
      }`}
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

function SelectedImages({ files }) {
  const [urls, setUrls] = useState([]);

  useEffect(() => {
    const next = files.map((file) => URL.createObjectURL(file));
    setUrls(next);

    return () => next.forEach((url) => URL.revokeObjectURL(url));
  }, [files]);

  return (
    <div className="product-gallery">
      {urls.map((url, index) => (
        <img
          key={url}
          src={url}
          alt={`Selected product image ${index + 1}`}
        />
      ))}
    </div>
  );
}

function ProductForm({ product, categories, onClose, onSaved }) {
  const [form, setForm] = useState({
    isFood: product?.isFood || false,
    nutritionFacts: product?.nutritionFacts || '',
    nutritionBasis: product?.nutritionBasis || '',
    nutritionSourceName: product?.nutritionSourceName || '',
    nutritionSourceUrl: product?.nutritionSourceUrl || '',
    name: product?.name || '',
    categoryId: product?.categoryId?.toString() || '',
    description: product?.description || '',
    price: product?.price?.toString() || '',
    unit: product?.unit || 'piece',
    stockQuantity: product?.stockQuantity?.toString() || '0',
    weightKg: product?.weightKg?.toString() || '',
  });

  const [files, setFiles] = useState([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const inputRef = useRef(null);

  const existingImages = product?.imageUrls || [];

  const change = (event) => {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
  };

  const selectFiles = (event) => {
    const selected = Array.from(event.target.files || []);

    const invalid =
      selected.length > 5 ||
      selected.some(
        (file) =>
          file.size > 5 * 1024 * 1024 ||
          !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)
      );

    if (invalid) {
      setError('Select up to 5 JPG, PNG or WebP images, 5 MB each.');
      setFiles([]);
      event.target.value = '';
      return;
    }

    setError('');
    setFiles(selected);
  };

  const submit = async (event) => {
    event.preventDefault();

    if (saving) return;

    if (form.name.trim().length < 2) {
      setError('Enter a product name with at least 2 characters.');
      return;
    }

    if (files.length === 0 && existingImages.length === 0) {
      setError('Select at least one product image.');
      return;
    }

    setSaving(true);
    setError('');

    const body = new FormData();

    Object.entries(form).forEach(([key, value]) => {
      if (value !== '') {
        body.append(key, key === 'name' ? value.trim() : value);
      }
    });

    files.forEach((file) => body.append('Images', file));

    if (product) {
      body.append('Version', product.version);
    }

    try {
      // Axios sets the multipart boundary automatically.
      const response = product
        ? await api.put(`/products/${product.id}`, body)
        : await api.post('/products', body);

      onSaved(response.data);
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal
      title={product ? `Edit product #${product.id}` : 'Create product'}
      busy={saving}
      onClose={onClose}
      wide
    >
      <Notice text={error} error />

      {!product && (
        <p className="product-form-note">
          Products created by an administrator are approved automatically.
        </p>
      )}

      <form onSubmit={submit} className="cat-form product-form">
        <fieldset disabled={saving} className="product-fields">
          <div className="cat-field product-span">
            <label htmlFor="product-name">Product name *</label>
            <input
              id="product-name"
              name="name"
              value={form.name}
              onChange={change}
              required
              minLength={2}
              maxLength={150}
              placeholder="e.g. Fresh tomatoes"
            />
          </div>

          <div className="cat-field">
            <label htmlFor="product-category">Category *</label>
            <select
              id="product-category"
              name="categoryId"
              value={form.categoryId}
              onChange={change}
              required
            >
              <option value="">Select a category</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
          </div>

          <div className="cat-field">
            <label htmlFor="product-unit">Selling unit *</label>
            <select
              id="product-unit"
              name="unit"
              value={form.unit}
              onChange={change}
              required
            >
              {UNITS.map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </div>

          {[
            {
              name: 'price',
              label: 'Price per unit (LKR) *',
              min: '0.01',
              max: '999999999.99',
              step: '0.01',
              required: true,
            },
            {
              name: 'stockQuantity',
              label: 'Stock quantity (units) *',
              min: '0',
              max: '1000000',
              step: '1',
              required: true,
            },
            {
              name: 'weightKg',
              label: 'Weight in kg — optional',
              min: '0.001',
              max: '999999.999',
              step: '0.001',
              required: false,
            },
          ].map((field) => (
            <div className="cat-field" key={field.name}>
              <label htmlFor={`product-${field.name}`}>
                {field.label}
              </label>
              <input
                id={`product-${field.name}`}
                name={field.name}
                type="number"
                value={form[field.name]}
                onChange={change}
                min={field.min}
                max={field.max}
                step={field.step}
                required={field.required}
              />
            </div>
          ))}

          <div className="cat-field product-span">
            <label>
              <input
                type="checkbox"
                checked={form.isFood}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    isFood: event.target.checked,
                  }))
                }
              />
              {' '}Food product
            </label>

            <small>
              Leave off for fertilizer, equipment and other non-food items.
            </small>
          </div>

          {form.isFood && (
            <fieldset className="cat-field product-span">
              <legend>Nutrition information — optional</legend>

              <p>
                Enter verified information for this food. Complete all four
                fields, or leave all blank when information is unavailable.
              </p>

              {[
                ['nutritionFacts', 'Nutrient information with units', 2000],
                ['nutritionBasis', 'Reference quantity and preparation (e.g. per 100 g, raw)', 200],
                ['nutritionSourceName', 'Source name and food record identifier', 200],
                ['nutritionSourceUrl', 'Direct HTTPS source URL', 1000],
              ].map(([name, label, maxLength]) => (
                <div className="cat-field" key={name}>
                  <label htmlFor={name}>{label}</label>

                  <textarea
                    id={name}
                    name={name}
                    value={form[name]}
                    onChange={change}
                    maxLength={maxLength}
                    rows={name === 'nutritionFacts' ? 4 : 2}
                    required={[
                      'nutritionFacts',
                      'nutritionBasis',
                      'nutritionSourceName',
                      'nutritionSourceUrl',
                    ].some((key) => form[key].trim())}
                  />
                </div>
              ))}
            </fieldset>
          )}

          <div className="cat-field product-span">
            <label htmlFor="product-description">Description</label>
            <textarea
              id="product-description"
              name="description"
              value={form.description}
              onChange={change}
              rows={4}
              maxLength={2000}
              placeholder="Describe the product, quality and packaging..."
            />
            <div className="cat-character-count">
              {form.description.length} / 2000
            </div>
          </div>

          <div className="cat-field product-span">
            <label htmlFor="product-images">Product images *</label>

            <div className="product-upload">
              <Upload size={23} />
              <p>Choose up to 5 product images</p>
              <small>JPG, PNG or WebP · Maximum 5 MB per image</small>

              <input
                ref={inputRef}
                id="product-images"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                multiple
                onChange={selectFiles}
                required={existingImages.length === 0 && files.length === 0}
              />
            </div>

            {files.length > 0 ? (
              <>
                <SelectedImages files={files} />

                <button
                  type="button"
                  className="cat-button cat-button-secondary"
                  onClick={() => {
                    setFiles([]);
                    if (inputRef.current) inputRef.current.value = '';
                  }}
                >
                  Clear selection
                </button>
              </>
            ) : (
              <div className="product-gallery">
                {existingImages.map((url) => (
                  <img
                    key={url}
                    src={imageSource(url)}
                    alt={product.name}
                  />
                ))}
              </div>
            )}

            {product && (
              <small>
                Choosing new images replaces all current images after saving.
                Leave the upload empty to keep the current images.
              </small>
            )}
          </div>

          <div className="product-form-actions product-span">
            <button
              type="button"
              className="cat-button cat-button-secondary"
              onClick={onClose}
            >
              Cancel
            </button>

            <button
              type="submit"
              className="cat-button cat-button-primary"
            >
              {saving ? (
                <Loader2 size={17} className="cat-spin" />
              ) : (
                <CheckCircle2 size={17} />
              )}
              {saving ? 'Saving...' : product ? 'Save changes' : 'Create product'}
            </button>
          </div>
        </fieldset>
      </form>
    </Modal>
  );
}

function ProductDetails({ product, onClose, onChanged }) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const review = async (action) => {
    if (busy) return;

    if (action === 'reject' && reason.trim().length < 3) {
      setError('Enter a rejection reason with at least 3 characters.');
      return;
    }

    setBusy(true);
    setError('');

    try {
      const response = await api.post(
        `/products/${product.id}/${action}`,
        {
          version: product.version,
          reason: reason.trim() || null,
        }
      );

      onChanged(response.data);
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      title={`Product #${product.id}`}
      busy={busy}
      onClose={onClose}
      wide
    >
      <Notice text={error} error />

      <div className="product-detail-title">
        <h3>{product.name}</h3>
        <StatusBadge status={product.status} />
      </div>

      <div className="product-gallery product-detail-gallery">
        {product.imageUrls.map((url) => (
          <a
            key={url}
            href={imageSource(url)}
            target="_blank"
            rel="noreferrer"
          >
            <img src={imageSource(url)} alt={product.name} />
          </a>
        ))}
      </div>

      <dl className="product-detail-grid">
        {[
          ['Category', product.categoryName],
          ['Price', `${money.format(product.price)} / ${product.unit}`],
          ['Stock', `${product.stockQuantity} units`],
          ['Weight', product.weightKg == null ? 'Not specified' : `${product.weightKg} kg`],
          ['Submitted by', product.createdByName],
          ['Source', product.createdByRole],
          ['Created', new Date(product.createdAt).toLocaleDateString()],
          ['Reviewed by', product.reviewedByName || 'Not reviewed'],
        ].map(([label, value]) => (
          <div key={label}>
            <dt>{label}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>

      <div className="product-description">
        <h4>Description</h4>
        <p>{product.description || 'No description added.'}</p>
      </div>

      {product.rejectionReason && (
        <Notice text={`Rejection reason: ${product.rejectionReason}`} error />
      )}

      {product.status === 'PENDING' && (
        <div className="product-review">
          <div className="cat-field">
            <label htmlFor="product-rejection-reason">
              Reason — required when rejecting
            </label>
            <textarea
              id="product-rejection-reason"
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              maxLength={500}
              rows={3}
              disabled={busy}
              placeholder="Explain what needs to be corrected..."
            />
          </div>

          <div className="product-form-actions">
            <button
              type="button"
              className="cat-button cat-button-danger"
              disabled={busy}
              onClick={() => review('reject')}
            >
              <X size={17} />
              Reject
            </button>

            <button
              type="button"
              className="cat-button cat-button-primary"
              disabled={busy}
              onClick={() => review('approve')}
            >
              {busy ? (
                <Loader2 size={17} className="cat-spin" />
              ) : (
                <CheckCircle2 size={17} />
              )}
              Approve product
            </button>
          </div>
        </div>
      )}
    </Modal>
  );
}

function DeleteProduct({ product, onClose, onDeleted }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const remove = async () => {
    if (busy) return;

    setBusy(true);
    setError('');

    try {
      await api.delete(`/products/${product.id}`, {
        params: { version: product.version },
      });

      onDeleted(product.id);
    } catch (requestError) {
      setError(getError(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="Delete product?" busy={busy} onClose={onClose}>
      <Notice text={error} error />

      <p>
        <strong>{product.name}</strong> and its uploaded images will be
        removed. This action cannot be undone.
      </p>

      <div className="product-form-actions">
        <button
          type="button"
          className="cat-button cat-button-secondary"
          disabled={busy}
          onClick={onClose}
        >
          Keep product
        </button>

        <button
          type="button"
          className="cat-button cat-button-danger"
          disabled={busy}
          onClick={remove}
        >
          {busy ? (
            <Loader2 size={17} className="cat-spin" />
          ) : (
            <Trash2 size={17} />
          )}
          Delete
        </button>
      </div>
    </Modal>
  );
}

export default function ProductManagement() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [status, setStatus] = useState('ALL');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  // undefined = closed, null = create, product object = edit
  const [editor, setEditor] = useState(undefined);
  const [details, setDetails] = useState(null);
  const [deleting, setDeleting] = useState(null);

  const load = useCallback(async (signal) => {
    setLoading(true);
    setError('');

    try {
      const [productResponse, categoryResponse] = await Promise.all([
        api.get('/products', { signal }),
        api.get('/categories', { signal }),
      ]);

      if (!signal?.aborted) {
        setProducts(productResponse.data);
        setCategories(categoryResponse.data);
      }
    } catch (requestError) {
      if (!signal?.aborted) setError(getError(requestError));
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    load(controller.signal);
    return () => controller.abort();
  }, [load]);

  const replaceProduct = (saved) => {
    setProducts((current) => [
      saved,
      ...current.filter((product) => product.id !== saved.id),
    ]);
  };

  const query = search.trim().toLowerCase();

  const filtered = products.filter((product) => {
    const matchesStatus = status === 'ALL' || product.status === status;

    const matchesSearch =
      `${product.id} ${product.name} ${product.categoryName} ${product.createdByName}`
        .toLowerCase()
        .includes(query);

    return matchesStatus && matchesSearch;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * PAGE_SIZE;
  const visible = filtered.slice(start, start + PAGE_SIZE);

  const metrics = [
    ['Total products', products.length, Package],
    ['Pending review', products.filter((p) => p.status === 'PENDING').length, Clock3],
    ['Approved', products.filter((p) => p.status === 'APPROVED').length, CheckCircle2],
    ['Rejected', products.filter((p) => p.status === 'REJECTED').length, X],
  ];

  return (
    <div className="category-page product-page">
      <header className="cat-header">
        <div>
          <div className="cat-eyebrow">
            <Package size={16} />
            Product catalog
          </div>
          <h1>Products</h1>
          <p>Manage products, pricing and listing approvals.</p>
        </div>

        <button
          type="button"
          className="cat-button cat-button-primary"
          disabled={loading || Boolean(error) || categories.length === 0}
          onClick={() => setEditor(null)}
        >
          <Plus size={18} />
          New product
        </button>
      </header>

      <div className="cat-stats product-stats">
        {metrics.map(([label, value, Icon]) => (
          <div className="cat-stat" key={label}>
            <div>
              <p className="cat-stat-label">{label}</p>
              <strong className="cat-stat-value">
                {loading || error ? '—' : value}
              </strong>
            </div>
            <div className="cat-stat-icon">
              <Icon size={21} />
            </div>
          </div>
        ))}
      </div>

      <Notice text={notice} />

      {!loading && !error && categories.length === 0 && (
        <Notice
          text="Create a category in the Categories page before adding products."
          error
        />
      )}

      <section className="cat-card">
        <div className="cat-card-heading">
          <div>
            <h2>Product directory</h2>
            <p>Review submissions and keep your catalog up to date.</p>
          </div>

          <button
            type="button"
            className="cat-icon-button"
            onClick={() => load()}
            disabled={loading}
            title="Refresh products"
            aria-label="Refresh products"
          >
            <RefreshCw size={18} className={loading ? 'cat-spin' : ''} />
          </button>
        </div>

        <div className="cat-toolbar">
          <label className="cat-search">
            <Search size={18} />
            <input
              type="search"
              aria-label="Search products"
              placeholder="Search name, ID, category or submitter..."
              value={search}
              onChange={(event) => {
                setSearch(event.target.value);
                setPage(1);
              }}
            />
          </label>
        </div>

        <div className="cat-filters" role="group" aria-label="Product status">
          {['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map((value) => (
            <button
              key={value}
              type="button"
              className={status === value ? 'is-selected' : ''}
              aria-pressed={status === value}
              onClick={() => {
                setStatus(value);
                setPage(1);
              }}
            >
              {value === 'ALL' ? 'All products' : value}
            </button>
          ))}
        </div>

        {loading ? (
          <div className="cat-empty" role="status">
            <Loader2 size={28} className="cat-spin" />
            <h3>Loading products...</h3>
          </div>
        ) : error ? (
          <div className="cat-empty" role="alert">
            <AlertCircle size={28} />
            <h3>Could not load products</h3>
            <p>{error}</p>
            <button
              type="button"
              className="cat-button cat-button-secondary"
              onClick={() => load()}
            >
              Try again
            </button>
          </div>
        ) : visible.length === 0 ? (
          <div className="cat-empty">
            <Package size={32} />
            <h3>No products to display</h3>
            <p>Add a product or change your search and filters.</p>
          </div>
        ) : (
          <div className="cat-table-scroll">
            <table className="cat-table product-table">
              <thead>
                <tr>
                  <th scope="col">Product</th>
                  <th scope="col">Price / unit</th>
                  <th scope="col">Stock</th>
                  <th scope="col">Submitted by</th>
                  <th scope="col">Status</th>
                  <th scope="col" className="cat-actions-heading">Actions</th>
                </tr>
              </thead>

              <tbody>
                {visible.map((product) => (
                  <tr key={product.id}>
                    <td>
                      <div className="cat-category-cell">
                        {product.imageUrls.length > 0 ? (
                          <img
                            className="product-thumbnail"
                            src={imageSource(product.imageUrls[0])}
                            alt=""
                            loading="lazy"
                          />
                        ) : (
                          <span className="cat-avatar"><Package size={20} /></span>
                        )}

                        <div className="cat-category-text">
                          <strong>{product.name}</strong>
                          <p>#{product.id} · {product.categoryName}</p>
                        </div>
                      </div>
                    </td>

                    <td className="product-price">
                      <strong>{money.format(product.price)}</strong>
                      <small>per {product.unit}</small>
                    </td>

                    <td>{product.stockQuantity}</td>

                    <td className="product-source">
                      <strong>{product.createdByName}</strong>
                      <small>{product.createdByRole}</small>
                    </td>

                    <td><StatusBadge status={product.status} /></td>

                    <td>
                      <div className="cat-row-actions">
                        <button
                          type="button"
                          className="cat-icon-button"
                          onClick={() => setDetails(product)}
                          title={product.status === 'PENDING' ? 'Review submission' : 'View details'}
                          aria-label={`View ${product.name}`}
                        >
                          <Eye size={17} />
                        </button>

                        <button
                          type="button"
                          className="cat-icon-button"
                          onClick={() => setEditor(product)}
                          title="Edit product"
                          aria-label={`Edit ${product.name}`}
                        >
                          <Pencil size={16} />
                        </button>

                        <button
                          type="button"
                          className="cat-icon-button cat-delete-button"
                          onClick={() => setDeleting(product)}
                          title="Delete product"
                          aria-label={`Delete ${product.name}`}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!loading && !error && (
          <footer className="cat-pagination">
            <span>
              Showing {filtered.length ? start + 1 : 0}
              –{Math.min(start + PAGE_SIZE, filtered.length)} of {filtered.length}
            </span>

            <div className="cat-page-controls">
              <button
                type="button"
                className="cat-icon-button"
                disabled={currentPage === 1}
                onClick={() => setPage(currentPage - 1)}
                aria-label="Previous page"
              >
                <ChevronLeft size={18} />
              </button>

              <span>{currentPage} / {totalPages}</span>

              <button
                type="button"
                className="cat-icon-button"
                disabled={currentPage === totalPages}
                onClick={() => setPage(currentPage + 1)}
                aria-label="Next page"
              >
                <ChevronRight size={18} />
              </button>
            </div>
          </footer>
        )}
      </section>

      {editor !== undefined && (
        <ProductForm
          product={editor}
          categories={categories}
          onClose={() => setEditor(undefined)}
          onSaved={(saved) => {
            replaceProduct(saved);
            setEditor(undefined);
            setPage(1);
            setNotice(`"${saved.name}" saved successfully.`);
          }}
        />
      )}

      {details && (
        <ProductDetails
          product={details}
          onClose={() => setDetails(null)}
          onChanged={(saved) => {
            replaceProduct(saved);
            setDetails(null);
            setNotice(`"${saved.name}" is now ${saved.status.toLowerCase()}.`);
          }}
        />
      )}

      {deleting && (
        <DeleteProduct
          product={deleting}
          onClose={() => setDeleting(null)}
          onDeleted={(id) => {
            setProducts((current) => current.filter((p) => p.id !== id));
            setDeleting(null);
            setNotice('Product deleted successfully.');
          }}
        />
      )}
    </div>
  );
}
