import { useCallback, useEffect, useState } from 'react';
import api from '../../services/api';
import '../Categories/CategoryManagement.css';

function message(error) {
  return error.response?.data?.message || 'Request failed. Please retry.';
}

function ReceiptImage({ id, basePath }) {
  const [url, setUrl] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    let objectUrl = '';

    api.get(`${basePath}/receipts/${id}`, {
      responseType: 'blob',
      signal: controller.signal,
    }).then((response) => {
      if (controller.signal.aborted) return;
      objectUrl = URL.createObjectURL(response.data);
      setUrl(objectUrl);
    }).catch(() => {
      if (!controller.signal.aborted) {
        setError('Could not load the receipt.');
      }
    });

    return () => {
      controller.abort();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [id, basePath]);

  if (error) return <p role="alert">{error}</p>;
  if (!url) return <p>Loading receipt...</p>;

  return (
    <img
      src={url}
      alt="Bank transfer receipt"
      style={{
        width: '100%',
        maxWidth: 600,
        maxHeight: 500,
        objectFit: 'contain',
      }}
    />
  );
}

export default function PackagePaymentReview({ onReviewed, basePath = '/package-payments', isOrder = false }) {
  const [items, setItems] = useState([]);
  const [selected, setSelected] = useState(null);
  const [note, setNote] = useState('');
  const [verified, setVerified] = useState(false);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.get(`${basePath}/pending`);
      setItems(response.data);
    } catch (requestError) {
      setError(message(requestError));
    } finally {
      setLoading(false);
    }
  }, [basePath]);

  useEffect(() => {
    let alive = true;
    api.get(`${basePath}/pending`).then((response) => {
      if (alive) setItems(response.data);
    }).catch((requestError) => {
      if (alive) setError(message(requestError));
    });
    return () => { alive = false; };
  }, [basePath]);

  const open = (receipt) => {
    setSelected(receipt);
    setVerified(false);
    setNote('');
    setError('');
  };

  const review = async (approve) => {
    if (!selected || busy) return;

    if (approve && !verified) {
      setError('Check the bank credit before approving.');
      return;
    }

    if (!approve && note.trim().length < 3) {
      setError('Enter the rejection reason.');
      return;
    }

    setBusy(true);
    setError('');

    try {
      await api.post(
        `${basePath}/receipts/${selected.id}/${approve ? 'approve' : 'reject'}`,
        {
          version: selected.version,
          creditVerified: approve && verified,
          adminNote: note.trim() || null,
        },
      );

      setSelected(null);
      await load();
      await onReviewed?.();
    } catch (requestError) {
      setError(message(requestError));
      if (requestError.response?.status === 409) {
        setSelected(null);
        await load();
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="cat-card" style={{ marginBottom: 20 }}>
      <div className="cat-card-heading">
        <div>
          <h2>{isOrder ? 'Order payment verification' : 'Package payment verification'}</h2>
          <p>Verify the actual bank credit before approving a receipt.</p>
        </div>
        <button
          className="cat-button"
          onClick={load}
          disabled={busy || loading}
        >
          Refresh receipts
        </button>
      </div>

      {error && <p role="alert" style={{ color: '#b42318' }}>{error}</p>}

      {loading ? <p>Loading...</p> : (
        <div className="cat-table-scroll">
          <table className="cat-table">
            <thead>
              <tr>
                <th>{isOrder ? 'Order' : 'Booking'}</th>
                <th>Buyer</th>
                <th>Stage</th>
                <th>Amount</th>
                <th>Reference</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {items.map((receipt) => (
                <tr key={receipt.id}>
                  <td>#{receipt.orderId ?? receipt.bookingId} — {receipt.packageName ?? 'Products'}</td>
                  <td>{receipt.customerName ?? receipt.farmerName}</td>
                  <td>{receipt.stage}</td>
                  <td>Rs. {Number(receipt.amount).toFixed(2)}</td>
                  <td>{receipt.transferReference}</td>
                  <td>{receipt.status ?? 'SUBMITTED'}</td>
                  <td>
                    <button
                      className="cat-button"
                      disabled={busy}
                      onClick={() => open(receipt)}
                    >
                      {(receipt.status ?? 'SUBMITTED') === 'SUBMITTED' ? 'Review receipt' : 'View receipt'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {items.length === 0 && <p>No payment receipts found.</p>}
        </div>
      )}

      {selected && (
        <div style={{ padding: 20 }}>
          <h3>{isOrder ? 'Order' : 'Booking'} #{selected.orderId ?? selected.bookingId} — {selected.stage}</h3>
          <p>
            Expected credit: <strong>Rs. {Number(selected.amount).toFixed(2)}</strong>
            <br />
            Transaction reference: <strong>{selected.transferReference}</strong>
          </p>

          <ReceiptImage key={`${basePath}:${selected.id}`} id={selected.id} basePath={basePath} />

          {(selected.status ?? 'SUBMITTED') === 'SUBMITTED' && (
            <>
              <label style={{ display: 'block', margin: '16px 0' }}>
                <input
                  type="checkbox"
                  checked={verified}
                  disabled={busy}
                  onChange={(event) => setVerified(event.target.checked)}
                />
                {' '}I verified this amount in the bank account and checked that
                this transfer has not been credited to another order or booking.
              </label>

              <textarea
                value={note}
                maxLength={500}
                rows={3}
                disabled={busy}
                onChange={(event) => setNote(event.target.value)}
                placeholder="Admin note. Required when rejecting."
                style={{ width: '100%', marginBottom: 12 }}
              />
            </>
          )}

          {(selected.status ?? 'SUBMITTED') !== 'SUBMITTED' && selected.adminNote && (
            <p>Admin note: {selected.adminNote}</p>
          )}

          <div className="cat-row-actions">
            {(selected.status ?? 'SUBMITTED') === 'SUBMITTED' && (
              <>
                <button
                  className="cat-button cat-button-primary"
                  disabled={busy || !verified}
                  onClick={() => review(true)}
                >
                  Approve payment
                </button>

                <button
                  className="cat-button cat-button-danger"
                  disabled={busy}
                  onClick={() => review(false)}
                >
                  Reject receipt
                </button>
              </>
            )}

            <button
              className="cat-button"
              disabled={busy}
              onClick={() => setSelected(null)}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </section>
  );
}
