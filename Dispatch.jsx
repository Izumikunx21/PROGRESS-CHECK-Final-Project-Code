import React, { useState, useMemo } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { collection, doc, addDoc, updateDoc } from 'firebase/firestore';
import { db } from '@/firebase/config';
import { useFirestoreCollection } from '@/lib/useFirestoreCollection';
import { Send, MapPin, AlertTriangle, X, Truck, User, Clock, Zap } from 'lucide-react';

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

/* ─────────── helpers ─────────── */
function getDistance(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function formatDate(timestamp) {
  if (!timestamp) return '-';
  const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

const normalize = (v) => (v || '').toString().toLowerCase().replace(/[\s_-]+/g, '');

export default function AdminDispatch() {
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [dismissedAlerts, setDismissedAlerts] = useState(new Set());
  const [assignError,     setAssignError]     = useState(null);
  const qc = useQueryClient();

  const { data: bookings = [] } = useFirestoreCollection('bookings');
  const { data: users    = [] } = useFirestoreCollection('users');
  const { data: trucks   = [] } = useFirestoreCollection('trucks');

  const drivers = useMemo(() => users.filter((u) => u.role === 'driver'), [users]);

  const UNAVAILABLE_STATUSES = ['blocked', 'inactive', 'on_leave', 'on_trip', 'pending_assignment'];
  const availableDrivers = useMemo(
    () => drivers.filter((d) => !UNAVAILABLE_STATUSES.includes((d.status || '').toLowerCase())),
    [drivers]
  );

  const pendingBookings = useMemo(() => bookings.filter((b) => b.status === 'approved'), [bookings]);

  const rejectionAlerts = bookings.filter(
    (b) => b.needs_reassignment && b.status === 'approved' && !dismissedAlerts.has(b.id)
  );

  /* ── Truck type from booking ── */
  const getTruckType = (booking) => {
    const truck = booking?.truckType || booking?.truck;
    if (!truck) return '-';
    if (typeof truck === 'string') return truck;
    return truck.type || truck.truck_type || '-';
  };

  /* ── Get driver's permanently assigned truck (regardless of status) ── */
  const getDriverTruck = (driver) =>
    trucks.find((t) => t.driver_id === driver.id) || null;

  /* ── Get driver's truck only if available ── */
  const getAvailableTruck = (driver) =>
    trucks.find((t) => t.driver_id === driver.id && t.status === 'available') || null;

  const getCustomerName = (userId) => {
    const user = users.find((u) => u.id === userId);
    return user?.fullName || user?.name || 'Unknown Customer';
  };

  const formatSchedule = (timestamp) => {
    if (!timestamp) return '-';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  /* ─────────────────────────────────────────────────────────
     getSuggestedDrivers — 1:1 model
     Only shows drivers whose own truck:
       1. exists
       2. is available
       3. matches the booking's truck type
     Sorted by: online+nearest first, offline+nearest, unknown last
  ───────────────────────────────────────────────────────── */
  const getSuggestedDrivers = (booking) => {
    const rejected        = booking.rejected_drivers || [];
    const bookingTruckType = getTruckType(booking);
    const pLat = booking.pickupCoords?.lat ?? null;
    const pLng = booking.pickupCoords?.lng ?? null;

    const eligible = availableDrivers.filter((d) => {
      if (rejected.includes(d.email)) return false;
      const truck = getDriverTruck(d);
      if (!truck) return false;
      if (truck.status !== 'available') return false;
      if (normalize(truck.truck_type) !== normalize(bookingTruckType)) return false;
      return true;
    });

    return eligible
      .map((d) => {
        const dLat = d.current_location?.lat ?? null;
        const dLng = d.current_location?.lng ?? null;
        return {
          ...d,
          distance:
            pLat && pLng && dLat && dLng
              ? getDistance(pLat, pLng, dLat, dLng)
              : 999,
        };
      })
      .sort((a, b) => {
        const scoreA = (a.isOnline ? 0 : 1000) + (a.distance ?? 999);
        const scoreB = (b.isOnline ? 0 : 1000) + (b.distance ?? 999);
        return scoreA - scoreB;
      });
  };

  /* ── A booking is "ready" only if at least one eligible driver has a matching available truck ── */
  const hasAvailableTruck = (booking) => getSuggestedDrivers(booking).length > 0;

  const readyToAssignBookings = useMemo(
    () => pendingBookings.filter((b) => hasAvailableTruck(b)),
    [pendingBookings, trucks, availableDrivers]
  );
  const awaitingTruckBookings = useMemo(
    () => pendingBookings.filter((b) => !hasAvailableTruck(b)),
    [pendingBookings, trucks, availableDrivers]
  );
  const getQueuePosition = (booking) =>
    awaitingTruckBookings.findIndex((b) => b.id === booking.id) + 1;

    const blockedByMaintenance = (booking) => {
    const bookingTruckType = getTruckType(booking);
    return drivers.some((d) => {
      const truck = getDriverTruck(d);
      return (
        truck &&
        normalize(truck.truck_type) === normalize(bookingTruckType) &&
        truck.status === 'maintenance'
      );
    });
  };

  const suggestions = selectedBooking ? getSuggestedDrivers(selectedBooking) : [];
  const topDriver   = suggestions[0] ?? null;

  /* ─────────────────────────────────────────────────────────
     assignMutation
  ───────────────────────────────────────────────────────── */
  const assignMutation = useMutation({
    mutationFn: async ({ bookingId, driver, truck, booking }) => {
      const bookingRef    = doc(db, 'bookings', bookingId);
      const driverRef     = doc(db, 'users', driver.id);
      const currentDriver = users.find((u) => u.id === driver.id);
      const driverStatus  = (currentDriver?.status || '').toLowerCase();

      if (!currentDriver || UNAVAILABLE_STATUSES.includes(driverStatus))
        throw new Error('Driver is no longer available.');
      if (!truck)
        throw new Error('No available truck for this booking.');

      const liveTruck = trucks.find((t) => t.id === truck.id);
      if (!liveTruck || liveTruck.status !== 'available') {
        throw new Error(
          `Truck ${truck.plate_number} is no longer available (status: ${liveTruck?.status ?? 'unknown'}). ` +
          `It may have been placed under maintenance. Please refresh and try again.`
        );
      }

      // 1. Update booking
      await updateDoc(bookingRef, {
        status:                    'assigned',
        assigned_driver_email:     driver.email,
        assigned_driver_name:      driver.fullName || driver.name,
        assigned_driver_id:        driver.id,
        assigned_truck_id:         truck.id,
        assigned_truck_type:       truck.truck_type,
        assigned_truck_plate_number: truck.plate_number,
        needs_reassignment:        false,
      });

      // 2. Update truck
      await updateDoc(doc(db, 'trucks', truck.id), {
        status:               'reserved',
        current_booking_id:   bookingId,
        assigned_booking_id:  bookingId,
      });

      // 3. Update driver
      await updateDoc(driverRef, {
        status:                      'on_trip',
        current_booking_id:          bookingId,
        assigned_truck_id:           truck.id,
        assigned_truck_plate_number: truck.plate_number,
      });

      // 4. Write dispatch log — use passed booking snapshot to avoid stale closure
      await addDoc(collection(db, 'dispatch_logs'), {
        booking_id:                  bookingId,
        assigned_driver_email:       driver.email,
        assigned_driver_name:        driver.fullName || driver.name,
        assigned_driver_id:          driver.id,
        assigned_truck_id:           truck.id,
        assigned_truck_type:         truck.truck_type,
        assigned_truck_plate_number: truck.plate_number,
        decision:                    booking.needs_reassignment ? 'reassigned' : 'assigned',
        booking_status_at_log:       booking.status,
        timestamp:                   new Date(),
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['bookings'] });
      qc.invalidateQueries({ queryKey: ['users'] });
      qc.invalidateQueries({ queryKey: ['trucks'] });
      setSelectedBooking(null);
      setAssignError(null);
    },
    onError: (err) => setAssignError(err.message || 'Failed to assign driver. Please try again.'),
  });

  /* ─────────────────────────────────────────────────────────
     RENDER
  ───────────────────────────────────────────────────────── */
  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .dp * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .dp h1 { font-family:'Sora',sans-serif; }
        .dp-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px; overflow:hidden; }
        .dp-card-header { padding:16px 20px; border-bottom:1px solid ${BORDER};
          display:flex; align-items:center; justify-content:space-between; }
        .dp-section-label { font-size:10px; color:#4ade80; font-weight:700;
          letter-spacing:0.18em; text-transform:uppercase; }
        .dp-icon-wrap { width:34px; height:34px; border-radius:9px; background:${G_DIM};
          border:1px solid ${G_BRD}; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
        .dp-booking-row { padding:14px 16px; border-bottom:1px solid ${BORDER};
          cursor:pointer; transition:background 0.15s; }
        .dp-booking-row:last-child { border-bottom:none; }
        .dp-booking-row:hover { background:rgba(255,255,255,0.025); }
        .dp-booking-row.active { background:rgba(22,163,74,0.08); }
        .dp-info-chip { background:${CARD2}; border:1px solid ${BORDER}; border-radius:9px; padding:10px 14px; }
        .dp-driver-row { padding:12px 14px; background:${CARD2}; border:1px solid ${BORDER};
          border-radius:12px; display:flex; align-items:center; justify-content:space-between;
          transition:border-color 0.15s; }
        .dp-driver-row:hover { border-color:rgba(74,222,128,0.3); }
        .dp-driver-row.recommended { border-color:rgba(74,222,128,0.4); background:rgba(22,163,74,0.05); }
        .dp-btn-assign { display:flex; align-items:center; gap:6px; background:${G_DIM};
          border:1px solid ${G_BRD}; color:#4ade80; border-radius:8px; padding:7px 14px;
          font-size:12px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .dp-btn-assign:hover { background:rgba(22,163,74,0.25); }
        .dp-btn-assign:disabled { opacity:0.4; cursor:not-allowed; }
        .dp-btn-auto { display:flex; align-items:center; gap:6px;
          background:linear-gradient(135deg, rgba(22,163,74,0.25), rgba(22,163,74,0.12));
          border:1px solid rgba(74,222,128,0.5); color:#4ade80; border-radius:8px; padding:7px 14px;
          font-size:12px; font-weight:700; cursor:pointer; transition:all 0.18s;
          font-family:'DM Sans',sans-serif; box-shadow:0 0 12px rgba(22,163,74,0.15); }
        .dp-btn-auto:hover { background:linear-gradient(135deg, rgba(22,163,74,0.35), rgba(22,163,74,0.2));
          box-shadow:0 0 18px rgba(22,163,74,0.25); }
        .dp-btn-auto:disabled { opacity:0.4; cursor:not-allowed; box-shadow:none; }
        .dp-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:8px; padding:6px 10px; font-size:12px; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; display:flex; align-items:center; }
        .dp-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .dp-alert { background:rgba(251,191,36,0.07); border:1px solid rgba(251,191,36,0.2);
          border-radius:12px; padding:14px 16px; display:flex; align-items:flex-start; gap:12px;
          cursor:pointer; transition:border-color 0.15s; }
        .dp-alert:hover { border-color:rgba(251,191,36,0.35); }
        .dp-empty { display:flex; flex-direction:column; align-items:center; justify-content:center;
          padding:60px 24px; gap:10px; }
        .field-label-dp { font-size:10px; color:#64748b; font-weight:600;
          text-transform:uppercase; letter-spacing:0.07em; }
        .dp-badge-recommended { font-size:10px; font-weight:700; color:#4ade80;
          background:rgba(22,163,74,0.15); border:1px solid rgba(22,163,74,0.3);
          border-radius:4px; padding:1px 7px; }
        .dp-badge-offline { font-size:10px; font-weight:600; color:#94a3b8;
          background:rgba(148,163,184,0.1); border:1px solid rgba(148,163,184,0.25);
          border-radius:4px; padding:1px 6px; }
        .dp-auto-banner { background:linear-gradient(135deg, rgba(22,163,74,0.1), rgba(22,163,74,0.05));
          border:1px solid rgba(74,222,128,0.25); border-radius:12px; padding:12px 14px;
          display:flex; align-items:center; justify-content:space-between; gap:12px; }
        @media(max-width:1024px){ .dp-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="dp" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ── HEADER ── */}
        <div>
          <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>Dispatch Management</h1>
          <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>
            Review and assign drivers to approved booking requests
          </p>
        </div>

        {/* ── REJECTION ALERTS ── */}
        {rejectionAlerts.length > 0 && (
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {rejectionAlerts.map((b) => (
              <div
                key={b.id}
                className="dp-alert"
                onClick={() => {
                  setDismissedAlerts((prev) => new Set([...prev, b.id]));
                  setSelectedBooking(b);
                }}
              >
                <div style={{
                  width: 34, height: 34, borderRadius: 9,
                  background: "rgba(251,191,36,0.12)", border: "1px solid rgba(251,191,36,0.25)",
                  display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                }}>
                  <AlertTriangle size={16} style={{ color: "#fbbf24" }} />
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontSize: 13, fontWeight: 600, color: "#fde68a", margin: 0 }}>
                    Driver rejected assignment
                  </p>
                  <p style={{ fontSize: 12, color: "#92400e", margin: "3px 0 0" }}>
                    {getCustomerName(b.userId)}
                  </p>
                  {b.rejectedAt && (
                    <p style={{ fontSize: 11, color: "#78350f", margin: "2px 0 0" }}>
                      Rejected {formatDate(b.rejectedAt)}
                    </p>
                  )}
                </div>
                <button
                  className="dp-btn-ghost"
                  style={{ flexShrink: 0 }}
                  onClick={(e) => { e.stopPropagation(); setDismissedAlerts((prev) => new Set([...prev, b.id])); }}
                >
                  <X size={13} />
                </button>
              </div>
            ))}
          </div>
        )}

        {/* ── MAIN GRID ── */}
        <div className="dp-grid" style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, alignItems: "start" }}>

          {/* ── LEFT: BOOKINGS LIST ── */}
          <div className="dp-card" style={{ maxHeight: "75vh", display: "flex", flexDirection: "column" }}>
            <div className="dp-card-header">
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <div className="dp-icon-wrap">
                  <Send size={15} style={{ color: "#4ade80" }} />
                </div>
                <div>
                  <p className="dp-section-label">Queue</p>
                  <p style={{ fontSize: 15, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Approved Bookings</p>
                </div>
              </div>
              <span style={{
                fontSize: 12, fontWeight: 700, color: "#4ade80",
                background: G_DIM, border: `1px solid ${G_BRD}`,
                borderRadius: 6, padding: "3px 10px",
              }}>
                {readyToAssignBookings.length} ready · {awaitingTruckBookings.length} queued
              </span>
            </div>

            <div style={{ overflowY: "auto", flex: 1 }}>
              {pendingBookings.length === 0 && (
                <div className="dp-empty">
                  <Send size={28} style={{ color: "#334155" }} />
                  <p style={{ fontSize: 13, color: "#475569", margin: 0 }}>No approved bookings</p>
                </div>
              )}

              {pendingBookings.map((b) => {
                const isSelected = selectedBooking?.id === b.id;
                const ready      = hasAvailableTruck(b);
                return (
                  <div
                    key={b.id}
                    className={`dp-booking-row${isSelected ? " active" : ""}`}
                    onClick={() => setSelectedBooking(b)}
                    style={{ borderLeft: isSelected ? "3px solid #4ade80" : "3px solid transparent" }}
                  >
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                      <div>
                        <p style={{ fontSize: 13, fontWeight: 700, color: "#f1f5f9", margin: "0 0 5px" }}>
                          {getCustomerName(b.userId)}
                        </p>
                        <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                          <span style={{
                            fontSize: 11, color: "#94a3b8", background: CARD2,
                            border: `1px solid ${BORDER}`, borderRadius: 5, padding: "2px 8px",
                          }}>
                            {getTruckType(b)}
                          </span>
                          <span style={{ fontSize: 11, color: "#64748b" }}>{formatSchedule(b.schedule)}</span>
                        </div>

                        {b.needs_reassignment && (
                          <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 6 }}>
                            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#fbbf24", flexShrink: 0 }} />
                            <span style={{ fontSize: 11, fontWeight: 600, color: "#fbbf24" }}>Needs reassignment</span>
                          </div>
                        )}
                        {!ready && !b.needs_reassignment && (
                          <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 6 }}>
                            <Clock size={11} style={{ color: blockedByMaintenance(b) ? "#f87171" : "#94a3b8" }} />
                            <span style={{ fontSize: 11, color: blockedByMaintenance(b) ? "#fca5a5" : "#64748b" }}>
                              {blockedByMaintenance(b)
                                ? `Queue #${getQueuePosition(b)} · Matching truck(s) under maintenance`
                                : `Queue #${getQueuePosition(b)} · Awaiting available driver + truck`}
                            </span>
                          </div>
                        )}
                        {ready && !b.needs_reassignment && (
                          <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 6 }}>
                            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                            <span style={{ fontSize: 11, fontWeight: 600, color: "#4ade80" }}>Ready to assign</span>
                          </div>
                        )}
                      </div>

                      <span style={{
                        fontSize: 10, fontWeight: 700,
                        color: ready ? "#4ade80" : "#fbbf24",
                        background: ready ? G_DIM : "rgba(251,191,36,0.1)",
                        border: `1px solid ${ready ? G_BRD : "rgba(251,191,36,0.25)"}`,
                        borderRadius: 5, padding: "2px 8px", flexShrink: 0, marginLeft: 8,
                      }}>
                        {b.status}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* ── RIGHT PANEL ── */}
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {selectedBooking ? (
              <>
                {/* BOOKING INFO */}
                <div className="dp-card">
                  <div className="dp-card-header">
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div className="dp-icon-wrap">
                        <MapPin size={15} style={{ color: "#4ade80" }} />
                      </div>
                      <div>
                        <p className="dp-section-label">Details</p>
                        <p style={{ fontSize: 15, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Booking Info</p>
                      </div>
                    </div>
                    <button className="dp-btn-ghost" onClick={() => setSelectedBooking(null)}>
                      <X size={13} />
                    </button>
                  </div>

                  <div style={{ padding: "16px 20px", display: "flex", flexDirection: "column", gap: 14 }}>
                    {/* route */}
                    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                        <span style={{ marginTop: 4, width: 9, height: 9, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                        <div>
                          <p className="field-label-dp" style={{ margin: "0 0 2px" }}>Pickup</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                            {selectedBooking.pickupLocation || '-'}
                          </p>
                        </div>
                      </div>
                      <div style={{ marginLeft: 4, borderLeft: "2px dashed rgba(255,255,255,0.08)", height: 12 }} />
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                        <span style={{ marginTop: 4, width: 9, height: 9, borderRadius: "50%", background: "#f87171", flexShrink: 0 }} />
                        <div>
                          <p className="field-label-dp" style={{ margin: "0 0 2px" }}>Destination</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                            {selectedBooking.destination || '-'}
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* info chips */}
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                      {[
                        ["Distance",   selectedBooking.estimatedDistance ? `${Number(selectedBooking.estimatedDistance).toFixed(2)} km` : "-"],
                        ["Est. Cost",  selectedBooking.estimatedCost     ? `₱${Number(selectedBooking.estimatedCost).toLocaleString("en-PH", { minimumFractionDigits: 2 })}` : "-"],
                        ["Truck Type", getTruckType(selectedBooking)],
                        ["Schedule",   formatSchedule(selectedBooking.schedule)],
                      ].map(([label, value]) => (
                        <div key={label} className="dp-info-chip">
                          <p className="field-label-dp" style={{ margin: "0 0 3px" }}>{label}</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>{value}</p>
                        </div>
                      ))}
                    </div>

                    {/* notes */}
                    {selectedBooking.notes && (
                      <div style={{
                        background: "rgba(251,191,36,0.06)", border: "1px solid rgba(251,191,36,0.15)",
                        borderRadius: 10, padding: "10px 14px",
                      }}>
                        <p style={{ fontSize: 10, color: "#fbbf24", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.07em", margin: "0 0 4px" }}>
                          Customer Notes
                        </p>
                        <p style={{ fontSize: 12, color: "#fde68a", margin: 0, fontStyle: "italic" }}>
                          "{selectedBooking.notes}"
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                {/* DRIVERS */}
                <div className="dp-card">
                  <div className="dp-card-header">
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div className="dp-icon-wrap">
                        <User size={15} style={{ color: "#4ade80" }} />
                      </div>
                      <div>
                        <p className="dp-section-label">Assignment</p>
                        <p style={{ fontSize: 15, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Available Drivers</p>
                      </div>
                    </div>

                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ fontSize: 11, fontWeight: 600, color: "#64748b" }}>
                        {suggestions.length} eligible
                      </span>
                      {/* Auto-assign: uses topDriver's own truck */}
                      {topDriver && getAvailableTruck(topDriver) && (
                        <button
                          className="dp-btn-auto"
                          disabled={assignMutation.isPending}
                          onClick={() => assignMutation.mutate({
                            bookingId: selectedBooking.id,
                            driver:    topDriver,
                            truck:     getAvailableTruck(topDriver),
                            booking:   selectedBooking,
                          })}
                        >
                          <Zap size={11} />
                          {assignMutation.isPending ? "Assigning…" : "Auto-Assign"}
                        </button>
                      )}
                    </div>
                  </div>

                  <div style={{ padding: "14px 16px", display: "flex", flexDirection: "column", gap: 10 }}>

                    {/* error banner */}
                    {assignError && (
                      <div style={{
                        background: "rgba(239,68,68,0.07)", border: "1px solid rgba(239,68,68,0.2)",
                        borderRadius: 10, padding: "10px 14px",
                        display: "flex", alignItems: "flex-start", gap: 10,
                      }}>
                        <AlertTriangle size={14} style={{ color: "#f87171", flexShrink: 0, marginTop: 1 }} />
                        <div>
                          <p style={{ fontSize: 12, color: "#fca5a5", margin: 0 }}>{assignError}</p>
                          <button
                            onClick={() => setAssignError(null)}
                            style={{ fontSize: 11, color: "#f87171", background: "none", border: "none", cursor: "pointer", padding: 0, marginTop: 4 }}
                          >
                            Dismiss
                          </button>
                        </div>
                      </div>
                    )}

                    {/* no eligible drivers banner */}
                    {suggestions.length === 0 && (
                      <div style={{
                        background: "rgba(251,191,36,0.06)", border: "1px solid rgba(251,191,36,0.2)",
                        borderRadius: 10, padding: "10px 14px",
                        display: "flex", alignItems: "center", gap: 8,
                      }}>
                        <Clock size={14} style={{ color: "#fbbf24", flexShrink: 0 }} />
                        <div>
                          <p style={{ fontSize: 12, fontWeight: 600, color: "#fde68a", margin: 0 }}>
                            Queue #{getQueuePosition(selectedBooking)} — No driver + truck available
                          </p>
                            <p style={{ fontSize: 11, color: "#92400e", margin: "2px 0 0" }}>
                              {blockedByMaintenance(selectedBooking)
                                ? `A matching ${getTruckType(selectedBooking)} truck exists but is under maintenance`
                                : `Waiting for a ${getTruckType(selectedBooking)} driver to become available`}
                            </p>
                        </div>
                      </div>
                    )}

                    {/* system recommendation banner */}
                    {topDriver && getAvailableTruck(topDriver) && (
                      <div className="dp-auto-banner">
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <div style={{
                            width: 30, height: 30, borderRadius: 8, background: G_DIM,
                            border: `1px solid ${G_BRD}`, display: "flex", alignItems: "center",
                            justifyContent: "center", flexShrink: 0,
                          }}>
                            <Zap size={13} style={{ color: "#4ade80" }} />
                          </div>
                          <div>
                            <p style={{ fontSize: 11, fontWeight: 700, color: "#4ade80", margin: 0 }}>
                              System Recommendation
                            </p>
                            <p style={{ fontSize: 12, color: "#94a3b8", margin: "2px 0 0" }}>
                              <span style={{ color: "#e2e8f0", fontWeight: 600 }}>
                                {topDriver.fullName || topDriver.name}
                              </span>
                              {" · "}
                              {topDriver.distance < 999
                                ? `${topDriver.distance.toFixed(1)} km away`
                                : "Location unknown"}
                              {!topDriver.isOnline && <span style={{ color: "#94a3b8" }}> · Offline</span>}
                              {" · "}
                              <span style={{ color: "#64748b" }}>
                                Truck {getAvailableTruck(topDriver)?.plate_number}
                              </span>
                            </p>
                          </div>
                        </div>
                        <span style={{
                          fontSize: 10, color: "#4ade80", fontWeight: 700,
                          background: G_DIM, border: `1px solid ${G_BRD}`,
                          borderRadius: 4, padding: "2px 8px", flexShrink: 0,
                        }}>
                          Nearest
                        </span>
                      </div>
                    )}

                    {/* driver list */}
                    {suggestions.length === 0 ? (
                      <div className="dp-empty" style={{ padding: "32px 16px" }}>
                        <User size={24} style={{ color: "#334155" }} />
                        <p style={{ fontSize: 13, color: "#475569", margin: 0 }}>No available drivers</p>
                      </div>
                    ) : (
                      suggestions.map((d, index) => {
                        const driverTruck = getAvailableTruck(d);
                        return (
                          <div
                            key={d.id}
                            className={`dp-driver-row${index === 0 ? " recommended" : ""}`}
                          >
                            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                              <div style={{
                                width: 34, height: 34, borderRadius: 9, background: G_DIM,
                                border: `1px solid ${G_BRD}`, display: "flex", alignItems: "center",
                                justifyContent: "center", fontSize: 13, fontWeight: 700, color: "#4ade80", flexShrink: 0,
                              }}>
                                {d.fullName?.[0]?.toUpperCase() ?? "?"}
                              </div>
                              <div>
                                <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
                                  <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                                    {d.fullName || d.name}
                                  </p>
                                  {index === 0 && (
                                    <span className="dp-badge-recommended">★ Recommended</span>
                                  )}
                                  {!d.isOnline && (
                                    <span className="dp-badge-offline">Offline</span>
                                  )}
                                </div>
                                <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 2, flexWrap: "wrap" }}>
                                  <span style={{
                                    width: 6, height: 6, borderRadius: "50%",
                                    background: d.isOnline ? "#4ade80" : "#94a3b8",
                                  }} />
                                  <span style={{ fontSize: 11, color: "#64748b" }}>
                                    {d.distance < 999
                                      ? `${d.distance.toFixed(1)} km away`
                                      : "Location unknown"}
                                  </span>
                                  {/* show the driver's own truck plate */}
                                  {driverTruck && (
                                    <>
                                      <span style={{ fontSize: 11, color: "#334155" }}>·</span>
                                      <Truck size={10} style={{ color: "#4ade80" }} />
                                      <span style={{ fontSize: 11, color: "#4ade80", fontWeight: 600 }}>
                                        {driverTruck.plate_number}
                                      </span>
                                    </>
                                  )}
                                </div>
                              </div>
                            </div>

                            <button
                              className="dp-btn-assign"
                              disabled={!driverTruck || assignMutation.isPending}
                              onClick={() => assignMutation.mutate({
                                bookingId: selectedBooking.id,
                                driver:    d,
                                truck:     driverTruck,
                                booking:   selectedBooking,
                              })}
                            >
                              <Send size={11} />
                              {assignMutation.isPending ? "Assigning…" : "Assign"}
                            </button>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              </>
            ) : (
              <div className="dp-card" style={{ minHeight: 340 }}>
                <div className="dp-empty">
                  <div style={{
                    width: 48, height: 48, borderRadius: 14, background: G_DIM,
                    border: `1px solid ${G_BRD}`, display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    <Send size={20} style={{ color: "#4ade80" }} />
                  </div>
                  <p style={{ fontSize: 14, fontWeight: 600, color: "#475569", margin: 0 }}>
                    Select a booking to view details
                  </p>
                  <p style={{ fontSize: 12, color: "#334155", margin: 0 }}>
                    Choose from the list on the left
                  </p>
                </div>
              </div>
            )}
          </div>

        </div>
      </div>
    </div>
  );
}