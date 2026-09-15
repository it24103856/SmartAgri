import { useEffect, useRef, useState } from 'react';
import api from '../../services/api';

const PAGE_SIZE = 10;

const NEXT_STATUS = {
  Confirmed: 'Preparing',
  Preparing: 'Packed',
  Packed: 'Dispatched',
  Dispatched: 'Delivered',
};

const STATUS_LABELS = {
  AwaitingPayment: 'Awaiting payment',
  Confirmed: 'Confirmed',
  Preparing: 'Preparing',
  Packed: 'Packed',
  Dispatched: 'Dispatched',
  Delivered: 'Delivered',
  PaymentFailed: 'Payment failed',
  PaymentReview: 'Needs review',
};

const moneyFormatter = new Intl.NumberFormat('en-LK', {
  style: 'currency',
  currency: 'LKR',
});

const money = (value) => moneyFormatter.format(Number(value ?? 0));

function dateTime(value) {
  if (!value) return '—';

  const date = new Date(value);

  return Number.isNaN(date.getTime())
    ? '—'
    : date.toLocaleString('en-LK');
}

function errorMessage(error) {
  const status = error.response?.status;
  const data = error.response?.data;

  if (status === 401) {
    return 'Your session expired. Log out and sign in again.';
  }

  if (status === 403) {
    return 'An active administrator account is required.';
  }

  if (status === 404) {
    return 'Order or API endpoint not found. Check that the updated backend is running.';
  }

  if (typeof data?.message === 'string') {
    return data.message;
  }

  if (data?.errors) {
    return Object.values(data.errors).flat().join(' ');
  }

  return 'Could not connect to the server. Please try again.';
}

const buttonClass =
  'rounded-xl border border-[#DCE7DF] bg-white px-4 py-2 text-sm ' +
  'font-semibold text-[#2D5A40] hover:bg-[#EAF4EE] ' +
  'disabled:cursor-not-allowed disabled:opacity-50';

const primaryButtonClass =
  'rounded-xl bg-[#2D5A40] px-4 py-2 text-sm font-semibold text-white ' +
  'hover:bg-[#1E3A2B] disabled:cursor-not-allowed disabled:opacity-50';

const panelClass =
  'rounded-2xl border border-[#DFE8E0] bg-white p-5 shadow-sm';

const fieldClass =
  'w-full rounded-xl border border-[#DCE7DF] bg-white px-3 py-2 ' +
  'text-sm outline-none focus:border-[#4E9F6E] focus:ring-2 ' +
  'focus:ring-[#EAF4EE]';

function Notice({ children, error = false }) {
  if (!children) return null;

  return (
    <div
      role={error ? 'alert' : 'status'}
      className={`rounded-xl border p-4 text-sm ${
        error
          ? 'border-red-200 bg-red-50 text-red-800'
          : 'border-green-200 bg-green-50 text-green-800'
      }`}
    >
      {children}
    </div>
  );
}

function StatusBadge({ status }) {
  const tone =
    status === 'Delivered'
      ? 'bg-green-100 text-green-800'
      : status === 'PaymentFailed' || status === 'PaymentReview'
        ? 'bg-red-100 text-red-800'
        : status === 'AwaitingPayment'
          ? 'bg-amber-100 text-amber-800'
          : 'bg-[#EAF4EE] text-[#2D5A40]';

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${tone}`}
    >
      {STATUS_LABELS[status] ?? status}
    </span>
  );
}

// Components using this hook are remounted when their query changes.
// Cleanup prevents an old request from updating an abandoned screen.
function useRead(url) {
  const [result, setResult] = useState({
    data: null,
    error: '',
  });

  useEffect(() => {
    const controller = new AbortController();

    api
      .get(url, {
        signal: controller.signal,
        timeout: 15000,
      })
      .then((response) => {
        if (!controller.signal.aborted) {
          setResult({ data: response.data, error: '' });
        }
      })
      .catch((error) => {
        if (!controller.signal.aborted) {
          setResult({ data: null, error: errorMessage(error) });
        }
      });

    return () => controller.abort();
  }, [url]);

  return result;
}

function OrderList({ url, page, onPage, onOpen, onRetry }) {
  const { data, error } = useRead(url);

  if (error) {
    return (
      <div className="space-y-3">
        <Notice error>{error}</Notice>
        <button className={buttonClass} onClick={onRetry}>
          Retry
        </button>
      </div>
    );
  }

  if (!data) {
    return (
      <div className={panelClass} role="status">
        Loading orders…
      </div>
    );
  }

  const totalPages = Math.max(1, data.totalPages);
  const items = data.items ?? [];

  return (
    <section className={panelClass}>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h2 className="font-bold">Customer orders</h2>
        <span className="text-sm text-gray-500">
          {data.totalCount} matching orders
        </span>
      </div>

      {items.length === 0 ? (
        <p className="py-10 text-center text-gray-500">
          No orders found. Try another search or filter.
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead className="border-b border-[#DFE8E0] text-gray-500">
              <tr>
                <th scope="col" className="p-3">Order</th>
                <th scope="col" className="p-3">Customer</th>
                <th scope="col" className="p-3">Status</th>
                <th scope="col" className="p-3">Payment</th>
                <th scope="col" className="p-3">Total</th>
                <th scope="col" className="p-3">Action</th>
              </tr>
            </thead>

            <tbody>
              {items.map((order) => (
                <tr
                  key={order.id}
                  className="border-b border-[#EDF2EE] hover:bg-[#F8FAF8]"
                >
                  <td className="p-3">
                    <div className="font-bold">#{order.id}</div>
                    <div className="mt-1 text-xs text-gray-500">
                      {dateTime(order.createdAt)}
                    </div>
                  </td>

                  <td className="p-3">
                    <div className="font-semibold">{order.fullName}</div>
                    <div className="text-xs text-gray-500">
                      {order.phone} · {order.city}
                    </div>
                  </td>

                  <td className="p-3">
                    <StatusBadge status={order.status} />
                  </td>

                  <td className="p-3">
                    <div>
                      {order.paymentMethod === 'COD'
                        ? 'Cash on Delivery'
                        : 'PayHere Sandbox'}
                    </div>
                    <div className="text-xs text-gray-500">
                      {order.paymentStatus}
                    </div>
                  </td>

                  <td className="p-3 font-semibold">
                    {money(order.totalAmount)}
                  </td>

                  <td className="p-3">
                    <button
                      className={buttonClass}
                      aria-label={`View order ${order.id}`}
                      onClick={() => onOpen(order.id)}
                    >
                      View
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
        <span className="text-sm text-gray-500">
          Page {page} of {totalPages}
        </span>

        <div className="flex gap-2">
          <button
            className={buttonClass}
            disabled={page <= 1}
            onClick={() => onPage(page - 1)}
          >
            Previous
          </button>

          <button
            className={buttonClass}
            disabled={page >= totalPages}
            onClick={() => onPage(page + 1)}
          >
            Next
          </button>
        </div>
      </div>
    </section>
  );
}

function OrderDetail({ id, onBack, onReload }) {
  const orderResult = useRead(`/admin/orders/${id}`);
  const historyResult = useRead(`/admin/orders/${id}/history`);

  const [note, setNote] = useState('');
  const [cashCollected, setCashCollected] = useState(false);
  const [busy, setBusy] = useState(false);
  const [updateError, setUpdateError] = useState('');
  const [mustReload, setMustReload] = useState(false);

  const submitting = useRef(false);
  const alive = useRef(false);

  useEffect(() => {
    alive.current = true;

    return () => {
      alive.current = false;
    };
  }, []);

  const order = orderResult.data;
  const next = order ? NEXT_STATUS[order.status] : null;
  const payment = order?.payment;

  const paymentReady =
    payment?.method === 'PAYHERE'
      ? payment.status === 'Paid'
      : payment?.method === 'COD'
        && ['Unpaid', 'Paid'].includes(payment.status);

  const requiresCash =
    next === 'Delivered'
    && payment?.method === 'COD'
    && payment.status === 'Unpaid';

  async function updateStatus(event) {
    event.preventDefault();

    if (
      submitting.current
      || !next
      || !paymentReady
      || mustReload
      || (requiresCash && !cashCollected)
    ) {
      return;
    }

    const confirmed = window.confirm(
      `Change order #${order.id} from ${order.status} to ${next}?`
      + (requiresCash ? '\nConfirm that the full cash payment was received.' : '')
    );

    if (!confirmed) return;

    submitting.current = true;
    setBusy(true);
    setUpdateError('');

    try {
      await api.patch(
        `/admin/orders/${order.id}/status`,
        {
          expectedStatus: order.status,
          status: next,
          note: note.trim() || null,
          paymentCollected: requiresCash && cashCollected,
        },
        { timeout: 20000 }
      );

      if (alive.current) {
        onReload(`Order #${order.id} updated to ${next}.`);
      }
    } catch (error) {
      if (alive.current) {
        setUpdateError(
          `${errorMessage(error)} Refresh the order to check its current status.`
        );

        // A timeout may happen after the server committed the update.
        // Read the current status before allowing another submission.
        setMustReload(true);
      }
    } finally {
      submitting.current = false;

      if (alive.current) {
        setBusy(false);
      }
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap gap-3">
        <button
          className={buttonClass}
          disabled={busy}
          onClick={onBack}
        >
          ← Back to orders
        </button>

        <button
          className={buttonClass}
          disabled={busy}
          onClick={() => onReload()}
        >
          Refresh order
        </button>
      </div>

      {orderResult.error ? (
        <Notice error>{orderResult.error}</Notice>
      ) : !order ? (
        <div className={panelClass} role="status">
          Loading order…
        </div>
      ) : (
        <>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-2xl font-bold">Order #{order.id}</h2>
              <p className="mt-1 text-sm text-gray-500">
                Placed {dateTime(order.createdAt)}
              </p>
            </div>
            <StatusBadge status={order.status} />
          </div>

          {order.reviewReason && (
            <Notice error>{order.reviewReason}</Notice>
          )}

          <div className="grid gap-5 xl:grid-cols-2">
            <section className={panelClass}>
              <h3 className="mb-3 font-bold">Delivery details</h3>
              <p className="font-semibold">{order.fullName}</p>
              <p className="break-words">{order.email}</p>
              <p>{order.phone}</p>
              <p className="mt-3 whitespace-pre-line">{order.address}</p>
              <p>{order.city}</p>
            </section>

            <section className={panelClass}>
              <h3 className="mb-3 font-bold">Payment summary</h3>
              <p>
                Method: {payment.method === 'COD'
                  ? 'Cash on Delivery'
                  : 'PayHere Sandbox'}
              </p>
              <p>Status: <strong>{payment.status}</strong></p>
              {payment.paidAt && <p>Paid: {dateTime(payment.paidAt)}</p>}
              {payment.providerPaymentId && (
                <p className="break-all">
                  Reference: {payment.providerPaymentId}
                </p>
              )}
              <div className="mt-4 space-y-1 border-t border-[#DFE8E0] pt-3">
                <p>Subtotal: {money(order.subtotal)}</p>
                <p>Delivery: {money(order.deliveryFee)}</p>
                <p className="text-lg font-bold">
                  Total: {money(order.totalAmount)}
                </p>
              </div>
            </section>
          </div>

          <section className={panelClass}>
            <h3 className="mb-3 font-bold">Purchased items</h3>
            <div className="divide-y divide-[#EDF2EE]">
              {order.items.map((item) => (
                <div
                  key={item.id}
                  className="flex flex-wrap justify-between gap-3 py-3"
                >
                  <div>
                    <p className="font-semibold">{item.name}</p>
                    <p className="text-sm text-gray-500">
                      {item.quantity} × {money(item.unitPrice)} / {item.unit}
                    </p>
                  </div>
                  <p className="font-semibold">{money(item.lineTotal)}</p>
                </div>
              ))}
            </div>
          </section>

          <section className={panelClass}>
            <h3 className="mb-3 font-bold">Process order</h3>

            {!next ? (
              <p className="text-sm text-gray-600">
                {order.status === 'Delivered'
                  ? 'This order has been delivered.'
                  : 'No fulfilment update is available for this status. Payment or review must be resolved first.'}
              </p>
            ) : !paymentReady ? (
              <Notice error>
                Payment must be resolved before processing this order.
              </Notice>
            ) : (
              <form onSubmit={updateStatus} className="space-y-4">
                <p className="text-sm">
                  Next step: <strong>{next}</strong>
                </p>

                <label className="block text-sm font-medium">
                  Note (optional)
                  <textarea
                    className={`${fieldClass} mt-2`}
                    rows={3}
                    maxLength={500}
                    value={note}
                    disabled={busy || mustReload}
                    onChange={(event) => setNote(event.target.value)}
                    placeholder="Add a note about this update"
                  />
                </label>

                {requiresCash && (
                  <label className="flex items-start gap-3 rounded-xl bg-amber-50 p-4 text-sm">
                    <input
                      type="checkbox"
                      className="mt-1 accent-[#2D5A40]"
                      checked={cashCollected}
                      disabled={busy || mustReload}
                      onChange={(event) =>
                        setCashCollected(event.target.checked)
                      }
                    />
                    <span>
                      I confirm that the full cash payment of{' '}
                      <strong>{money(order.totalAmount)}</strong> was received.
                    </span>
                  </label>
                )}

                <Notice error>{updateError}</Notice>

                <button
                  type="submit"
                  className={primaryButtonClass}
                  disabled={
                    busy
                    || mustReload
                    || (requiresCash && !cashCollected)
                  }
                >
                  {busy ? 'Updating…' : `Mark as ${next}`}
                </button>
              </form>
            )}
          </section>

          <section className={panelClass}>
            <h3 className="mb-4 font-bold">Status history</h3>

            {historyResult.error ? (
              <Notice error>{historyResult.error}</Notice>
            ) : !historyResult.data ? (
              <p role="status">Loading history…</p>
            ) : historyResult.data.length === 0 ? (
              <p className="text-sm text-gray-500">
                No admin status changes have been recorded yet.
              </p>
            ) : (
              <ol className="space-y-4">
                {historyResult.data.map((entry) => (
                  <li
                    key={entry.id}
                    className="border-l-4 border-[#8EB89B] pl-4"
                  >
                    <p className="font-semibold">
                      {STATUS_LABELS[entry.fromStatus] ?? entry.fromStatus}
                      {' → '}
                      {STATUS_LABELS[entry.toStatus] ?? entry.toStatus}
                    </p>
                    <p className="text-xs text-gray-500">
                      {dateTime(entry.createdAt)} · {entry.changedByName}
                    </p>
                    {entry.note && (
                      <p className="mt-1 whitespace-pre-wrap break-words text-sm">
                        {entry.note}
                      </p>
                    )}
                    {entry.paymentCollected && (
                      <p className="mt-1 text-sm font-semibold text-green-700">
                        Cash payment collected
                      </p>
                    )}
                  </li>
                ))}
              </ol>
            )}
          </section>
        </>
      )}
    </div>
  );
}

export default function OrderManagement() {
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [revision, setRevision] = useState(0);
  const [selectedId, setSelectedId] = useState(null);
  const [notice, setNotice] = useState('');

  function refresh(message = '') {
    setNotice(message);
    setRevision((value) => value + 1);
  }

  const params = new URLSearchParams({
    page: String(page),
    pageSize: String(PAGE_SIZE),
  });

  if (search) params.set('search', search);
  if (status) params.set('status', status);

  const url = `/admin/orders?${params.toString()}`;

  return (
    <div className="mx-auto max-w-7xl space-y-5 text-[#1E3A2B]">
      <header>
        <h1 className="text-2xl font-bold">Order Management</h1>
        <p className="mt-1 text-sm text-gray-500">
          Review customer orders and manage delivery progress.
        </p>
      </header>

      <Notice>{notice}</Notice>

      {selectedId !== null ? (
        <OrderDetail
          key={`${selectedId}:${revision}`}
          id={selectedId}
          onReload={refresh}
          onBack={() => {
            setSelectedId(null);
            setNotice('');
          }}
        />
      ) : (
        <>
          <form
            className={`${panelClass} flex flex-wrap items-end gap-3`}
            onSubmit={(event) => {
              event.preventDefault();
              setSearch(searchInput.trim());
              setPage(1);
              refresh();
            }}
          >
            <label className="min-w-[200px] flex-1 text-sm font-medium">
              Search orders
              <input
                className={`${fieldClass} mt-2`}
                value={searchInput}
                maxLength={100}
                onChange={(event) => setSearchInput(event.target.value)}
                placeholder="Order ID, name, email or phone"
              />
            </label>

            <label className="min-w-[180px] text-sm font-medium">
              Status
              <select
                className={`${fieldClass} mt-2`}
                value={status}
                onChange={(event) => {
                  setStatus(event.target.value);
                  setPage(1);
                  setNotice('');
                }}
              >
                <option value="">All statuses</option>
                {Object.entries(STATUS_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
            </label>

            <button type="submit" className={primaryButtonClass}>
              Search
            </button>

            <button
              type="button"
              className={buttonClass}
              onClick={() => refresh()}
            >
              Refresh
            </button>

            <button
              type="button"
              className={buttonClass}
              onClick={() => {
                setSearchInput('');
                setSearch('');
                setStatus('');
                setPage(1);
                refresh();
              }}
            >
              Reset
            </button>
          </form>

          <OrderList
            key={`${url}:${revision}`}
            url={url}
            page={page}
            onPage={setPage}
            onRetry={() => refresh()}
            onOpen={(id) => {
              setNotice('');
              setSelectedId(id);
            }}
          />
        </>
      )}
    </div>
  );
}