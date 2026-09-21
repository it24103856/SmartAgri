import { useEffect, useRef, useState } from 'react';
import api from '../../services/api';

const money = (value) =>
  new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
  }).format(Number(value ?? 0));

const dateTime = (value) =>
  value ? new Date(value).toLocaleString() : '—';

function errorMessage(error) {
  const status = error.response?.status;
  const data = error.response?.data;

  if (status === 401) return 'Session expired. Please log in again.';
  if (status === 403) return 'An active admin account is required.';

  if (typeof data?.message === 'string') return data.message;

  if (data?.errors) {
    return Object.values(data.errors).flat().join(' ');
  }

  return 'Could not complete the request. Check your connection.';
}

const buttonClass =
  'rounded-xl border border-green-200 bg-white px-4 py-2 ' +
  'text-sm font-semibold text-green-900 hover:bg-green-50 ' +
  'disabled:cursor-not-allowed disabled:opacity-50';

function BasketReview({ id, onDecision }) {
  const [basket, setBasket] = useState(null);
  const [note, setNote] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [mustReload, setMustReload] = useState(false);
  const [reload, setReload] = useState(0);
  const submitting = useRef(false);
  const mounted = useRef(false);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  useEffect(() => {
    const controller = new AbortController();

    async function load() {
      setLoading(true);
      setError('');

      try {
        const { data } = await api.get(
          `/admin-smart-baskets/${id}`,
          { signal: controller.signal },
        );

        if (controller.signal.aborted) return;

        setBasket(data);
        setMustReload(false);
      } catch (err) {
        if (!controller.signal.aborted) {
          setError(errorMessage(err));
        }
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }

    load();
    return () => controller.abort();
  }, [id, reload]);

  async function decide(decision) {
    if (
      submitting.current ||
      loading ||
      mustReload ||
      basket?.status !== 'AwaitingApproval'
    ) return;

    if (decision === 'Rejected' && !note.trim()) {
      setError('Please enter a rejection reason.');
      return;
    }

    const confirmed = window.confirm(
      `${decision === 'Approved' ? 'Approve' : 'Reject'} ` +
      `revision ${basket.proposalRevision} for ` +
      `${money(basket.proposedTotal)}?`,
    );

    if (!confirmed) return;

    submitting.current = true;
    setSaving(true);
    setError('');
    setNotice('');

    try {
      const { data } = await api.post(
        `/admin-smart-baskets/${id}/decision`,
        {
          version: basket.version,
          proposalRevision: basket.proposalRevision,
          decision,
          note: note.trim() || null,
        },
      );

      if (!mounted.current) return;

      setBasket(data);
      setNote('');
      setNotice(
        decision === 'Approved'
          ? 'Basket approved. The customer can proceed to checkout.'
          : 'Basket rejected. The decision has been recorded.',
      );
      onDecision();
    } catch (err) {
      if (!mounted.current) return;

      const status = err.response?.status;
      const uncertain = !status || status === 408 || status >= 500;

      if (status === 409 || uncertain) {
        setMustReload(true);
        setError(
          uncertain
            ? 'The result could not be confirmed. Reload details to ' +
              'check whether the decision was saved before trying again.'
            : `${errorMessage(err)} Reload details before reviewing again.`,
        );
      } else {
        setError(errorMessage(err));
      }
    } finally {
      submitting.current = false;
      if (mounted.current) setSaving(false);
    }
  }

  const canDecide =
    basket?.status === 'AwaitingApproval' &&
    !loading &&
    !saving &&
    !mustReload;

  return (
    <section className="rounded-2xl border border-green-100 bg-white p-6 shadow-sm">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-xl font-bold text-green-950">
          Basket review
        </h2>

        <button
          className={buttonClass}
          disabled={loading || saving}
          onClick={() => setReload((value) => value + 1)}
        >
          Reload details
        </button>
      </div>

      {error && (
        <p role="alert" className="mb-4 rounded-xl bg-red-50 p-3 text-red-700">
          {error}
        </p>
      )}

      {notice && (
        <p role="status" className="mb-4 rounded-xl bg-green-50 p-3 text-green-800">
          {notice}
        </p>
      )}

      {loading ? (
        <p className="text-gray-500">Loading basket…</p>
      ) : basket ? (
        <>
          <p className="break-all text-xs text-gray-500">{basket.id}</p>

          <div className="my-4 flex flex-wrap gap-3 text-sm">
            <span className="rounded-full bg-green-50 px-3 py-1 font-semibold">
              {basket.status}
            </span>
            <span>Customer #{basket.customerId}</span>
            <span>Revision {basket.proposalRevision}</span>
          </div>

          <p className="whitespace-pre-wrap text-gray-800">
            {basket.objective}
          </p>

          <div className="my-5 grid grid-cols-2 gap-4">
            <div className="rounded-xl bg-gray-50 p-4">
              <p className="text-sm text-gray-500">Budget</p>
              <p className="font-bold">{money(basket.budget)}</p>
            </div>
            <div className="rounded-xl bg-green-50 p-4">
              <p className="text-sm text-gray-500">Proposed total</p>
              <p className="font-bold">{money(basket.proposedTotal)}</p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 text-gray-600">
                <tr>
                  <th className="p-3">Product</th>
                  <th className="p-3">Quantity</th>
                  <th className="p-3">Unit price</th>
                  <th className="p-3">Total</th>
                </tr>
              </thead>
              <tbody>
                {(basket.items ?? []).map((item) => (
                  <tr key={item.productId} className="border-b border-gray-100">
                    <td className="p-3">
                      {item.productName}
                      <div className="text-xs text-gray-500">{item.unit}</div>
                    </td>
                    <td className="p-3">{item.quantity}</td>
                    <td className="p-3">{money(item.unitPrice)}</td>
                    <td className="p-3">{money(item.lineTotal)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {basket.status === 'AwaitingApproval' && (
            <div className="mt-6">
              <label htmlFor="basket-note" className="block text-sm font-semibold">
                Review note — required when rejecting
              </label>
              <textarea
                id="basket-note"
                rows={3}
                maxLength={1000}
                value={note}
                disabled={!canDecide}
                onChange={(event) => setNote(event.target.value)}
                className="mt-2 w-full rounded-xl border border-gray-300 p-3"
                placeholder="Enter your review note"
              />

              <div className="mt-3 flex flex-wrap gap-3">
                <button
                  disabled={!canDecide}
                  onClick={() => decide('Approved')}
                  className="rounded-xl bg-green-700 px-5 py-2 font-semibold text-white disabled:opacity-50"
                >
                  {saving ? 'Saving…' : 'Approve basket'}
                </button>
                <button
                  disabled={!canDecide}
                  onClick={() => decide('Rejected')}
                  className="rounded-xl border border-red-200 px-5 py-2 font-semibold text-red-700 disabled:opacity-50"
                >
                  Reject basket
                </button>
              </div>

              <p className="mt-3 text-sm text-gray-500">
                Approval allows customer checkout. It does not create an order.
              </p>
            </div>
          )}

          {basket.linkedOrder && (
            <p className="mt-5 rounded-xl bg-blue-50 p-3 text-blue-900">
              Linked order #{basket.linkedOrder.id}
              {' — '}{basket.linkedOrder.status}
            </p>
          )}

          <h3 className="mb-3 mt-7 font-bold">Decision history</h3>
          {(basket.decisions ?? []).length === 0 ? (
            <p className="text-sm text-gray-500">No decisions recorded yet.</p>
          ) : (
            basket.decisions.map((entry, index) => (
              <div key={index} className="mb-2 rounded-xl bg-gray-50 p-3 text-sm">
                <p className="font-semibold">
                  {entry.decision} — Revision {entry.proposalRevision}
                </p>
                <p>Admin #{entry.adminId} · {dateTime(entry.createdAt)}</p>
                <p className="mt-1 whitespace-pre-wrap">{entry.note}</p>
              </div>
            ))
          )}

          <h3 className="mb-3 mt-7 font-bold">Workflow history</h3>
          <ol className="space-y-2">
            {(basket.history ?? []).map((step, index) => (
              <li key={index} className="rounded-xl border border-gray-100 p-3 text-sm">
                <div className="flex flex-wrap justify-between gap-2">
                  <strong>{step.agentName}</strong>
                  <span>{step.status}</span>
                </div>
                <p className="text-gray-500">
                  Attempt {step.attempt} · {step.toolName ?? 'Agent step'}
                </p>
                <p className="text-xs text-gray-500">
                  {dateTime(step.finishedAt)}
                </p>
              </li>
            ))}
          </ol>
        </>
      ) : (
        <p className="text-gray-500">Reload details to try again.</p>
      )}
    </section>
  );
}

export default function SmartBasketManagement() {
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedId, setSelectedId] = useState(null);
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    const controller = new AbortController();

    async function load() {
      setLoading(true);
      setError('');

      try {
        const { data } = await api.get('/admin-smart-baskets', {
          params: { page, pageSize: 20 },
          signal: controller.signal,
        });

        if (controller.signal.aborted) return;

        setItems(data.items);
        setTotal(data.totalCount);
      } catch (err) {
        if (!controller.signal.aborted) {
          setError(errorMessage(err));
        }
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }

    load();
    return () => controller.abort();
  }, [page, refresh]);

  return (
    <div className="mx-auto max-w-6xl space-y-6 text-gray-800">
      <header>
        <h1 className="text-3xl font-bold text-green-950">Smart Basket approvals</h1>
        <p className="mt-2 text-gray-500">
          Review customer-submitted baskets and their workflow history.
        </p>
      </header>

      {selectedId ? (
        <>
          <button
            className={buttonClass}
            onClick={() => {
              setSelectedId(null);
              setRefresh((value) => value + 1);
            }}
          >
            ← Back to pending baskets
          </button>

          <BasketReview
            key={selectedId}
            id={selectedId}
            onDecision={() => setRefresh((value) => value + 1)}
          />
        </>
      ) : (
        <section className="rounded-2xl border border-green-100 bg-white p-6 shadow-sm">
          <div className="mb-5 flex items-center justify-between gap-3">
            <h2 className="text-lg font-bold">Awaiting approval ({total})</h2>
            <button
              className={buttonClass}
              disabled={loading}
              onClick={() => setRefresh((value) => value + 1)}
            >
              Refresh / Retry
            </button>
          </div>

          {error && <p role="alert" className="mb-4 text-red-700">{error}</p>}

          {loading ? (
            <p>Loading requests…</p>
          ) : error ? null : items.length === 0 ? (
            <p className="text-gray-500">No pending baskets on this page.</p>
          ) : (
            <div className="space-y-3">
              {items.map((item) => (
                <button
                  key={item.id}
                  onClick={() => setSelectedId(item.id)}
                  className="w-full rounded-xl border border-green-100 p-4 text-left hover:bg-green-50"
                >
                  <div className="flex flex-wrap justify-between gap-2">
                    <strong>Customer #{item.customerId}</strong>
                    <strong>{money(item.proposedTotal)}</strong>
                  </div>
                  <p className="my-2">{item.objective}</p>
                  <p className="text-sm text-gray-500">
                    Budget {money(item.budget)} · Revision {item.proposalRevision}
                  </p>
                  <p className="mt-1 text-xs text-gray-500">
                    {dateTime(item.updatedAt)}
                  </p>
                </button>
              ))}
            </div>
          )}

          <div className="mt-6 flex items-center justify-between gap-3">
            <button
              className={buttonClass}
              disabled={loading || page === 1}
              onClick={() => setPage((value) => value - 1)}
            >
              Previous
            </button>
            <span className="text-sm">Page {page}</span>
            <button
              className={buttonClass}
              disabled={loading || !!error || page * 20 >= total}
              onClick={() => setPage((value) => value + 1)}
            >
              Next
            </button>
          </div>
        </section>
      )}
    </div>
  );
}