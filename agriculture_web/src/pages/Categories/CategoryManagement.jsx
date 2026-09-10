import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  FolderOpen,
  FolderTree,
  Info,
  Loader2,
  Package,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  Trash2,
  X,
} from 'lucide-react';

import api from '../../services/api';
import './CategoryManagement.css';

const EMPTY_FORM = { name: '', description: '' };
const PAGE_SIZE = 6;

function getErrorMessage(error) {
  const data = error.response?.data;

  if (error.response?.status === 413) return 'Choose an image no larger than 5 MB.';

  if (error.response?.status === 403) {
    return 'Only administrators can manage categories.';
  }

  if (data?.message) return data.message;

  if (data?.errors) {
    return Object.values(data.errors).flat().join(' ');
  }

  return 'Unable to complete the request. Please try again.';
}

function CategoryImagePreview({ file, imageUrl }) {
  const ref = useRef(null);
  useEffect(() => {
    const url = file ? URL.createObjectURL(file) : imageUrl;
    if (ref.current) ref.current.src = url;
    return () => { if (file) URL.revokeObjectURL(url); };
  }, [file, imageUrl]);
  return <img ref={ref} className="cat-image-preview" alt="Category preview" />;
}

function categoryImageSource(path) {
  return new URL(path, new URL(api.defaults.baseURL, window.location.origin).origin).href;
}

function formatDate(value) {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return '—';

  return date.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function StatCard({ icon: Icon, label, value, description }) {
  return (
    <div className="cat-stat">
      <div>
        <p className="cat-stat-label">{label}</p>
        <strong className="cat-stat-value">{value}</strong>
        <p className="cat-stat-description">{description}</p>
      </div>

      <div className="cat-stat-icon">
        <Icon size={22} strokeWidth={1.7} />
      </div>
    </div>
  );
}

function DeleteDialog({ category, busy, onCancel, onConfirm }) {
  const dialogRef = useRef(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    dialog.showModal();

    return () => {
      if (dialog.open) dialog.close();
    };
  }, []);

  return (
    <dialog
      ref={dialogRef}
      className="cat-dialog"
      aria-labelledby="cat-delete-title"
      aria-describedby="cat-delete-description"
      onCancel={(event) => {
        event.preventDefault();
        if (!busy) onCancel();
      }}
    >
      <div className="cat-dialog-icon">
        <Trash2 size={25} />
      </div>

      <h2 id="cat-delete-title">Delete category?</h2>

      <p id="cat-delete-description">
        <strong>{category.name}</strong> will be permanently removed.
        This action cannot be undone.
      </p>

      <div className="cat-dialog-actions">
        <button
          type="button"
          autoFocus
          className="cat-button cat-button-secondary"
          disabled={busy}
          onClick={onCancel}
        >
          Keep category
        </button>

        <button
          type="button"
          className="cat-button cat-button-danger"
          disabled={busy}
          onClick={onConfirm}
        >
          {busy ? (
            <Loader2 size={16} className="cat-spin" />
          ) : (
            <Trash2 size={16} />
          )}
          {busy ? 'Deleting...' : 'Delete category'}
        </button>
      </div>
    </dialog>
  );
}

export default function CategoryManagement() {
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [imageFile, setImageFile] = useState(null);
  const [existingImage, setExistingImage] = useState(null);
  const imageInputRef = useRef(null);

  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [sort, setSort] = useState('name');
  const [page, setPage] = useState(1);

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [notice, setNotice] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);

  const nameRef = useRef(null);
  const busy = saving || deleting;
  const controlsDisabled = busy || loading || Boolean(loadError);

  const loadCategories = useCallback(async (signal) => {
    setLoading(true);
    setLoadError('');

    try {
      const response = await api.get('/categories', { signal });

      if (!signal?.aborted) {
        setCategories(response.data);
      }
    } catch (error) {
      if (!signal?.aborted) {
        setLoadError(getErrorMessage(error));
      }
    } finally {
      if (!signal?.aborted) {
        setLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    loadCategories(controller.signal);

    return () => controller.abort();
  }, [loadCategories]);

  useEffect(() => {
    if (showForm) {
      nameRef.current?.focus();
      nameRef.current?.scrollIntoView({ block: 'nearest' });
    }
  }, [showForm, editingId]);

  const resetForm = () => {
    setImageFile(null);
    setExistingImage(null);
    if (imageInputRef.current) imageInputRef.current.value = '';
    setShowForm(false);
    setForm(EMPTY_FORM);
    setEditingId(null);
  };

  const startCreate = () => {
    resetForm();
    setShowForm(true);
    setNotice(null);
    nameRef.current?.focus();
  };

  const startEdit = (category) => {
    setImageFile(null);
    setExistingImage(category.imageUrl || null);
    if (imageInputRef.current) imageInputRef.current.value = '';
    setShowForm(true);
    setEditingId(category.id);
    setForm({
      name: category.name,
      description: category.description || '',
    });
    setNotice(null);
    nameRef.current?.focus();
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (controlsDisabled) return;

    const name = form.name.trim();
    const description = form.description.trim();

    if (name.length < 2 || name.length > 100) {
      setNotice({
        type: 'error',
        text: 'Category name must contain 2 to 100 characters.',
      });
      nameRef.current?.focus();
      return;
    }

    if (description.length > 500) {
      setNotice({
        type: 'error',
        text: 'Description cannot exceed 500 characters.',
      });
      return;
    }

    setSaving(true);
    setNotice(null);

    try {
      const payload = new FormData();
      payload.append('Name', name);
      payload.append('Description', description);
      if (imageFile) payload.append('Image', imageFile);

      const isEditing = editingId !== null;

      const response = isEditing
        ? await api.put(`/categories/${editingId}`, payload)
        : await api.post('/categories', payload);

      const savedCategory = response.data;

      setCategories((current) =>
        isEditing
          ? current.map((category) =>
              category.id === editingId ? savedCategory : category
            )
          : [...current, savedCategory]
      );

      setNotice({
        type: 'success',
        text: `"${savedCategory.name}" ${
          isEditing ? 'updated' : 'created'
        } successfully.`,
      });

      resetForm();
    } catch (error) {
      setNotice({
        type: 'error',
        text: getErrorMessage(error),
      });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget || controlsDisabled) return;

    setDeleting(true);
    setNotice(null);

    try {
      await api.delete(`/categories/${deleteTarget.id}`);

      setCategories((current) =>
        current.filter((category) => category.id !== deleteTarget.id)
      );

      if (editingId === deleteTarget.id) {
        resetForm();
      }

      setNotice({
        type: 'success',
        text: `"${deleteTarget.name}" deleted successfully.`,
      });
    } catch (error) {
      setNotice({
        type: 'error',
        text: getErrorMessage(error),
      });
    } finally {
      setDeleting(false);
      setDeleteTarget(null);
    }
  };

  const usedCount = categories.filter(
    (category) => category.productCount > 0
  ).length;

  const emptyCount = categories.length - usedCount;
  const query = search.trim().toLowerCase();

  const filteredCategories = categories
    .filter((category) => {
      const matchesSearch =
        `${category.name} ${category.description || ''}`
          .toLowerCase()
          .includes(query);

      const matchesFilter =
        filter === 'all' ||
        (filter === 'used' && category.productCount > 0) ||
        (filter === 'empty' && category.productCount === 0);

      return matchesSearch && matchesFilter;
    })
    .sort((first, second) => {
      if (sort === 'newest') {
        return (
          (Date.parse(second.createdAt) || 0) -
          (Date.parse(first.createdAt) || 0)
        );
      }

      return first.name.localeCompare(second.name);
    });

  const totalPages = Math.max(
    1,
    Math.ceil(filteredCategories.length / PAGE_SIZE)
  );

  const currentPage = Math.min(page, totalPages);
  const startIndex = (currentPage - 1) * PAGE_SIZE;

  const visibleCategories = filteredCategories.slice(
    startIndex,
    startIndex + PAGE_SIZE
  );

  const statsUnavailable = loading || Boolean(loadError);

  return (
    <div className="category-page">
      <header className="cat-header">
        <div>
          <div className="cat-eyebrow">
            <FolderTree size={15} />
            Product catalog
          </div>

          <h1>Categories</h1>

          <p>
            Keep your catalog organized and make products easier to find.
          </p>
        </div>

        <button
          type="button"
          className="cat-button cat-button-primary"
          onClick={startCreate}
          disabled={controlsDisabled}
        >
          <Plus size={18} />
          New category
        </button>
      </header>

      <section className="cat-stats" aria-label="Category overview">
        <StatCard
          icon={FolderTree}
          label="Total categories"
          value={statsUnavailable ? '—' : categories.length}
          description="Across your product catalog"
        />

        <StatCard
          icon={Package}
          label="With products"
          value={statsUnavailable ? '—' : usedCount}
          description="Categories currently in use"
        />

        <StatCard
          icon={FolderOpen}
          label="Empty categories"
          value={statsUnavailable ? '—' : emptyCount}
          description="No products assigned yet"
        />
      </section>

      {notice && (
        <div
          className={`cat-notice cat-notice-${notice.type}`}
          role={notice.type === 'error' ? 'alert' : 'status'}
        >
          {notice.type === 'error' ? (
            <AlertCircle size={19} />
          ) : (
            <CheckCircle2 size={19} />
          )}

          <span>{notice.text}</span>

          <button
            type="button"
            className="cat-icon-button"
            aria-label="Dismiss message"
            onClick={() => setNotice(null)}
          >
            <X size={17} />
          </button>
        </div>
      )}

      <div className="cat-grid" style={showForm ? undefined : { gridTemplateColumns: 'minmax(0, 1fr)' }}>
        <section className="cat-card cat-directory">
          <div className="cat-card-heading">
            <div>
              <h2>Category directory</h2>
              <p>Manage the categories in your catalog.</p>
            </div>

            <button
              type="button"
              className="cat-icon-button"
              title="Refresh categories"
              aria-label="Refresh categories"
              disabled={loading || busy}
              onClick={() => loadCategories()}
            >
              <RefreshCw
                size={18}
                className={loading ? 'cat-spin' : ''}
              />
            </button>
          </div>

          <div className="cat-toolbar">
            <label className="cat-search">
              <Search size={18} aria-hidden="true" />

              <input
                type="search"
                aria-label="Search categories"
                placeholder="Search categories..."
                value={search}
                onChange={(event) => {
                  setSearch(event.target.value);
                  setPage(1);
                }}
              />
            </label>

            <select
              className="cat-sort"
              aria-label="Sort categories"
              value={sort}
              onChange={(event) => {
                setSort(event.target.value);
                setPage(1);
              }}
            >
              <option value="name">Name: A–Z</option>
              <option value="newest">Newest first</option>
            </select>
          </div>

          <div className="cat-filters" role="group" aria-label="Filter categories">
            {[
              ['all', 'All categories'],
              ['used', 'With products'],
              ['empty', 'Empty'],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                className={filter === value ? 'is-selected' : ''}
                aria-pressed={filter === value}
                onClick={() => {
                  setFilter(value);
                  setPage(1);
                }}
              >
                {label}
              </button>
            ))}
          </div>

          {loading ? (
            <div className="cat-empty" role="status">
              <Loader2 size={28} className="cat-spin" />
              <h3>Loading categories</h3>
              <p>Your catalog will appear here shortly.</p>
            </div>
          ) : loadError ? (
            <div className="cat-empty" role="alert">
              <AlertCircle size={30} />
              <h3>Could not load categories</h3>
              <p>{loadError}</p>

              <button
                type="button"
                className="cat-button cat-button-secondary"
                onClick={() => loadCategories()}
              >
                <RefreshCw size={16} />
                Try again
              </button>
            </div>
          ) : visibleCategories.length === 0 ? (
            <div className="cat-empty">
              <div className="cat-empty-icon">
                <FolderOpen size={30} />
              </div>

              <h3>
                {categories.length === 0
                  ? 'Start organizing your catalog'
                  : 'No matching categories'}
              </h3>

              <p>
                {categories.length === 0
                  ? 'Click New category to create your first category.'
                  : 'Try a different search or change the filter.'}
              </p>
            </div>
          ) : (
            <div className="cat-table-scroll">
              <table className="cat-table">
                <thead>
                  <tr>
                    <th scope="col">Category</th>
                    <th scope="col">Products</th>
                    <th scope="col">Created</th>
                    <th scope="col" className="cat-actions-heading">
                      Actions
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {visibleCategories.map((category) => (
                    <tr
                      key={category.id}
                      className={
                        editingId === category.id ? 'cat-editing-row' : ''
                      }
                    >
                      <td>
                        <div className="cat-category-cell">
                          {category.imageUrl ? (
                            <img className="cat-avatar cat-image-thumbnail" src={categoryImageSource(category.imageUrl)} alt="" />
                          ) : (
                            <span className="cat-avatar" aria-hidden="true">
                              {category.name.charAt(0).toUpperCase()}
                            </span>
                          )}

                          <div className="cat-category-text">
                            <strong>{category.name}</strong>

                            <p title={category.description || ''}>
                              {category.description || 'No description added'}
                            </p>
                          </div>
                        </div>
                      </td>

                      <td>
                        <span
                          className={`cat-count ${
                            category.productCount === 0
                              ? 'cat-count-empty'
                              : ''
                          }`}
                        >
                          {category.productCount}
                        </span>
                      </td>

                      <td className="cat-date">
                        {formatDate(category.createdAt)}
                      </td>

                      <td>
                        <div className="cat-row-actions">
                          <button
                            type="button"
                            className="cat-icon-button"
                            aria-label={`Edit ${category.name}`}
                            title="Edit category"
                            disabled={controlsDisabled}
                            onClick={() => startEdit(category)}
                          >
                            <Pencil size={16} />
                          </button>

                          <button
                            type="button"
                            className="cat-icon-button cat-delete-button"
                            aria-label={`Delete ${category.name}`}
                            title={
                              category.productCount > 0
                                ? 'Move products to another category first'
                                : 'Delete category'
                            }
                            disabled={
                              controlsDisabled || category.productCount > 0
                            }
                            onClick={() => setDeleteTarget(category)}
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

          {!loading && !loadError && (
            <footer className="cat-pagination">
              <span>
                Showing{' '}
                <strong>
                  {filteredCategories.length === 0 ? 0 : startIndex + 1}
                  –{Math.min(startIndex + PAGE_SIZE, filteredCategories.length)}
                </strong>{' '}
                of <strong>{filteredCategories.length}</strong>
              </span>

              <div className="cat-page-controls">
                <button
                  type="button"
                  className="cat-icon-button"
                  aria-label="Previous page"
                  disabled={currentPage === 1}
                  onClick={() => setPage(currentPage - 1)}
                >
                  <ChevronLeft size={17} />
                </button>

                <span>
                  {currentPage} / {totalPages}
                </span>

                <button
                  type="button"
                  className="cat-icon-button"
                  aria-label="Next page"
                  disabled={currentPage === totalPages}
                  onClick={() => setPage(currentPage + 1)}
                >
                  <ChevronRight size={17} />
                </button>
              </div>
            </footer>
          )}
        </section>

        {showForm && (
        <aside className="cat-card cat-editor">
          <div className="cat-editor-heading">
            <div className="cat-editor-icon">
              {editingId !== null ? (
                <Pencil size={21} />
              ) : (
                <Plus size={23} />
              )}
            </div>

            <div>
              <h2>{editingId !== null ? 'Edit category' : 'New category'}</h2>
              <p>
                {editingId !== null
                  ? 'Update the category details.'
                  : 'Give your products a place to belong.'}
              </p>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="cat-form">
            <fieldset disabled={controlsDisabled}>
              <div className="cat-field">
                <label htmlFor="cat-name">
                  Category name <span className="cat-required">*</span>
                </label>

                <input
                  ref={nameRef}
                  id="cat-name"
                  required
                  minLength={2}
                  maxLength={100}
                  placeholder="e.g. Fresh vegetables"
                  value={form.name}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      name: event.target.value,
                    }))
                  }
                  aria-describedby="cat-name-help"
                />

                <small id="cat-name-help">
                  Use a short, recognizable name.
                </small>
              </div>

              <div className="cat-field">
                <div className="cat-label-row">
                  <label htmlFor="cat-description">Description</label>
                  <span>Optional</span>
                </div>

                <textarea
                  id="cat-description"
                  rows={5}
                  maxLength={500}
                  placeholder="Describe the products in this category..."
                  value={form.description}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      description: event.target.value,
                    }))
                  }
                />

                <div className="cat-character-count">
                  {form.description.length} / 500
                </div>
              </div>

              <div className="cat-field">
                <label htmlFor="cat-image">Category image (optional)</label>
                <input
                  ref={imageInputRef}
                  id="cat-image"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  aria-describedby="cat-image-help"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    if (file && (file.size === 0 || file.size > 5 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type))) {
                      setNotice({ type: 'error', text: 'Choose a JPG, PNG or WebP image up to 5 MB.' });
                      event.target.value = '';
                      setImageFile(null);
                      return;
                    }
                    setImageFile(file || null);
                    setNotice(null);
                  }}
                />
                <small id="cat-image-help">JPG, PNG or WebP, up to 5 MB. Choose a new image to replace the current one.</small>
                {(imageFile || existingImage) && (
                  <CategoryImagePreview file={imageFile} imageUrl={existingImage ? categoryImageSource(existingImage) : null} />
                )}
                {imageFile && (
                  <button type="button" className="cat-button cat-button-secondary" onClick={() => {
                    setImageFile(null);
                    if (imageInputRef.current) imageInputRef.current.value = '';
                  }}>Clear selection</button>
                )}
              </div>

              <button
                type="submit"
                className="cat-button cat-button-primary cat-button-full"
              >
                {saving ? (
                  <Loader2 size={17} className="cat-spin" />
                ) : editingId !== null ? (
                  <CheckCircle2 size={17} />
                ) : (
                  <Plus size={17} />
                )}

                {saving
                  ? 'Saving...'
                  : editingId !== null
                    ? 'Save changes'
                    : 'Create category'}
              </button>

                <button
                  type="button"
                  className="cat-button cat-button-secondary cat-button-full cat-cancel-edit"
                  onClick={resetForm}
                >
                  Cancel
                </button>
            </fieldset>
          </form>

          <div className="cat-editor-note">
            <Info size={17} />
            <p>
              Categories with products cannot be deleted. Reassign their
              products to another category first.
            </p>
          </div>
        </aside>
        )}
      </div>

      {deleteTarget && (
        <DeleteDialog
          category={deleteTarget}
          busy={deleting}
          onCancel={() => setDeleteTarget(null)}
          onConfirm={handleDelete}
        />
      )}
    </div>
  );
}