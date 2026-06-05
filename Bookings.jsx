import React, { useState, useEffect, useRef, useMemo } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "@/firebase/config";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";

import {
  Eye, Check, X, Filter, ChevronDown, Phone, Mail,
  Search, Calendar, ArrowUpDown, ArrowUp, ArrowDown,
  AlertCircle, Loader2, ChevronLeft, ChevronRight,
} from "lucide-react";
import { format, startOfDay, endOfDay, subDays } from "date-fns";

/* ─────────── brand tokens ─────────── */
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";

const FILTER_OPTIONS = [
  { value: "all",                label: "All Status"          },
  { value: "pending",            label: "Pending"             },
  { value: "approved",           label: "Approved"            },
  { value: "assigned",           label: "Assigned"            },
  { value: "accepted",           label: "Accepted"            },
  { value: "en_route_to_pickup", label: "En Route to Pickup"  },
  { value: "arrived_at_pickup",  label: "Arrived at Pickup"   },
  { value: "in_transit",         label: "In Transit"          },
  { value: "delivered",          label: "Delivered"           },
  { value: "completed",          label: "Completed"           },
  { value: "rejected",           label: "Rejected"            },
  { value: "cancelled",          label: "Cancelled"           },
];

const DATE_PRESETS = [
  { value: "all",    label: "All Time"      },
  { value: "today",  label: "Today"         },
  { value: "7d",     label: "Last 7 Days"   },
  { value: "30d",    label: "Last 30 Days"  },
  { value: "custom", label: "Custom Range"  },
];

const STATUS_META = {
  pending:            { color: "#fbbf24", bg: "rgba(251,191,36,0.1)",  border: "rgba(251,191,36,0.25)"  },
  approved:           { color: "#4ade80", bg: G_DIM,                   border: G_BRD                    },
  assigned:           { color: "#60a5fa", bg: "rgba(96,165,250,0.1)",  border: "rgba(96,165,250,0.25)"  },
  accepted:           { color: "#34d399", bg: "rgba(52,211,153,0.1)",  border: "rgba(52,211,153,0.25)"  },
  en_route_to_pickup: { color: "#a78bfa", bg: "rgba(167,139,250,0.1)", border: "rgba(167,139,250,0.25)" },
  arrived_at_pickup:  { color: "#fb923c", bg: "rgba(251,146,60,0.1)",  border: "rgba(251,146,60,0.25)"  },
  in_transit:         { color: "#c084fc", bg: "rgba(192,132,252,0.1)", border: "rgba(192,132,252,0.25)" },
  delivered:          { color: "#34d399", bg: "rgba(52,211,153,0.1)",  border: "rgba(52,211,153,0.25)"  },
  completed:          { color: "#4ade80", bg: G_DIM,                   border: G_BRD                    },
  rejected:           { color: "#f87171", bg: "rgba(248,113,113,0.1)", border: "rgba(248,113,113,0.25)" },
  cancelled:          { color: "#f87171", bg: "rgba(248,113,113,0.1)", border: "rgba(248,113,113,0.25)" },
};

const PAGE_SIZE = 15;

const toDate = (ts) => (ts?.seconds ? new Date(ts.seconds * 1000) : null);

/* ─────────── sub-components ─────────── */

const StatusPill = ({ status }) => {
  const s    = (status || "").toLowerCase().replace(/\s/g, "_");
  const meta = STATUS_META[s] || { color: "#94a3b8", bg: "rgba(148,163,184,0.1)", border: "rgba(148,163,184,0.25)" };
  const label = (status || "-").replace(/_/g, " ");
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, color: meta.color, background: meta.bg,
      border: `1px solid ${meta.border}`, borderRadius: 6, padding: "3px 10px",
      display: "inline-flex", alignItems: "center", gap: 5, textTransform: "capitalize",
    }}>
      <span style={{ width: 5, height: 5, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
      {label}
    </span>
  );
};

const SortIcon = ({ col, sortCol, sortDir }) => {
  if (sortCol !== col) return <ArrowUpDown size={11} style={{ color: "#334155", marginLeft: 4 }} />;
  return sortDir === "asc"
    ? <ArrowUp   size={11} style={{ color: "#4ade80", marginLeft: 4 }} />
    : <ArrowDown size={11} style={{ color: "#4ade80", marginLeft: 4 }} />;
};

/* ─────────── main component ─────────── */

export default function AdminBookings() {
  const [filter, setFilter]               = useState("all");
  const [filterOpen, setFilterOpen]       = useState(false);
  const [datePreset, setDatePreset]       = useState("all");
  const [dateOpen, setDateOpen]           = useState(false);
  const [customFrom, setCustomFrom]       = useState("");
  const [customTo, setCustomTo]           = useState("");
  const [search, setSearch]               = useState("");
  const [sortCol, setSortCol]             = useState("createdAt");
  const [sortDir, setSortDir]             = useState("desc");
  const [page, setPage]                   = useState(1);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [rejectModal, setRejectModal]     = useState(false);
  const [rejectReason, setRejectReason]   = useState("");
  const [rejectTarget, setRejectTarget]   = useState(null);

  const filterRef = useRef(null);
  const dateRef   = useRef(null);

  useEffect(() => {
    const handle = (e) => {
      if (filterOpen && filterRef.current && !filterRef.current.contains(e.target)) setFilterOpen(false);
      if (dateOpen   && dateRef.current   && !dateRef.current.contains(e.target))   setDateOpen(false);
    };
    document.addEventListener("mousedown", handle);
    return () => document.removeEventListener("mousedown", handle);
  }, [filterOpen, dateOpen]);

  useEffect(() => { setPage(1); }, [filter, datePreset, customFrom, customTo, search, sortCol, sortDir]);

  const queryClient = useQueryClient();
  const { data: bookings = [], loading } = useFirestoreCollection("bookings");
  const { data: users    = []          } = useFirestoreCollection("users");

  /* ── mutations ── */
  const updateStatus = useMutation({
    mutationFn: async ({ id, status, reason }) => {
      const payload = { status };
      if (reason) payload.rejection_reason = reason;
      await updateDoc(doc(db, "bookings", id), payload);
    },
    onSuccess: () => queryClient.invalidateQueries(["bookings"]),
  });

  /* ── helpers ── */
  const formatTruckType = (type) => {
    if (!type) return "-";
    if (typeof type === "object") type = type.type || type.name || "";
    if (typeof type !== "string") return "-";
    return type.split("_").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  };

  const getCustomer             = (id) => users.find((u) => u.id === id)?.fullName || "N/A";
  const getBookingCustomer      = (b)  => b.customer?.fullName || b.customer_name || b.customerName || getCustomer(b.userId);
  const getBookingCustomerPhone = (b)  => b.customer?.phone || null;
  const getBookingCustomerEmail = (b)  => b.customer?.email || null;
  const getBookingType          = (b)  => formatTruckType(b.truckType?.type || b.truck?.type || b.truckType || b.assigned_truck_type);
  const getBookingDate          = (b)  =>
    b.schedule_date ||
    (b.schedule?.seconds ? format(new Date(b.schedule.seconds * 1000), "MMM d, yyyy hh:mm a") : "-");
  const getBookingDriver        = (b)  => b.assigned_driver_name || b.driverName || "Not Assigned";
  const getBookingCost          = (b)  =>
    b.estimatedCost != null
      ? `₱${Number(b.estimatedCost).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
      : "-";
  const getBookingDistance      = (b)  =>
    b.estimatedDistance != null ? `${Number(b.estimatedDistance).toFixed(2)} km` : "-";
  const getBookingStatusNote    = (b)  => {
    if (b.status === "rejected")  return b.rejection_reason || b.rejectionNote || b.notes;
    if (b.status === "cancelled") return b.cancelledReason  || b.notes;
    return null;
  };
  const formatTimestamp = (ts) =>
    ts?.seconds ? format(new Date(ts.seconds * 1000), "MMM d, yyyy hh:mm a") : null;

  /* ── date window ── */
  const dateWindow = useMemo(() => {
    const now = new Date();
    if (datePreset === "today") return { from: startOfDay(now), to: endOfDay(now) };
    if (datePreset === "7d")    return { from: startOfDay(subDays(now, 6)), to: endOfDay(now) };
    if (datePreset === "30d")   return { from: startOfDay(subDays(now, 29)), to: endOfDay(now) };
    if (datePreset === "custom" && customFrom && customTo) {
      const from = startOfDay(new Date(customFrom + "T00:00"));
      const to   = endOfDay(new Date(customTo + "T00:00"));
      if (from <= to) return { from, to };
    }
    return null;
  }, [datePreset, customFrom, customTo]);

  /* ── filter + search + sort + paginate ── */
  const processed = useMemo(() => {
    let arr = [...bookings];

    if (filter !== "all")
      arr = arr.filter((b) => (b.status || "").toLowerCase().replace(/\s/g, "_") === filter);

    if (dateWindow)
      arr = arr.filter((b) => {
        const d = toDate(b.createdAt);
        if (!d) return false;
        return d >= dateWindow.from && d <= dateWindow.to;
      });

    const q = search.trim().toLowerCase();
    if (q)
      arr = arr.filter((b) =>
        [
          getBookingCustomer(b),
          getBookingType(b),
          getBookingDriver(b),
          b.pickupLocation,
          b.destination,
          b.id,
        ].some((v) => (v || "").toLowerCase().includes(q))
      );

    arr.sort((a, b_) => {
      let va, vb;
      if (sortCol === "createdAt") {
        va = a.createdAt?.seconds || 0;
        vb = b_.createdAt?.seconds || 0;
      } else if (sortCol === "customer") {
        va = getBookingCustomer(a).toLowerCase();
        vb = getBookingCustomer(b_).toLowerCase();
      } else if (sortCol === "driver") {
        va = getBookingDriver(a).toLowerCase();
        vb = getBookingDriver(b_).toLowerCase();
      } else if (sortCol === "cost") {
        va = a.estimatedCost ?? -1;
        vb = b_.estimatedCost ?? -1;
      } else if (sortCol === "status") {
        va = (a.status || "").toLowerCase();
        vb = (b_.status || "").toLowerCase();
      } else {
        va = (a[sortCol] || "").toString().toLowerCase();
        vb = (b_[sortCol] || "").toString().toLowerCase();
      }
      if (va < vb) return sortDir === "asc" ? -1 : 1;
      if (va > vb) return sortDir === "asc" ? 1  : -1;
      return 0;
    });

    return arr;
  }, [bookings, filter, dateWindow, search, sortCol, sortDir]);

  const totalPages = Math.max(1, Math.ceil(processed.length / PAGE_SIZE));
  const paginated  = processed.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const handleSort = (col) => {
    if (sortCol === col) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else { setSortCol(col); setSortDir("desc"); }
  };

  /* ── reject ── */
  const openReject   = (booking) => { setRejectTarget(booking); setRejectReason(""); setRejectModal(true); };
  const confirmReject = () => {
    if (!rejectTarget) return;
    updateStatus.mutate({ id: rejectTarget.id, status: "rejected", reason: rejectReason || "No reason provided" });
    setRejectModal(false); setRejectTarget(null); setRejectReason("");
  };

  /* ── timeline ── */
  const getTimeline = (b) => [
    { label: "Booking Created",    ts: b.createdAt         },
    { label: "Driver Accepted",    ts: b.acceptedAt        },
    { label: "En Route to Pickup", ts: b.enRouteAt         },
    { label: "Arrived at Pickup",  ts: b.arrivedAtPickupAt },
    { label: "In Transit",         ts: b.inTransitAt       },
    { label: "Delivered",          ts: b.deliveredAt       },
  ].filter((t) => t.ts);

  const COLS = [
    { key: "customer",  label: "Customer",  sortable: true  },
    { key: "truck",     label: "Truck",     sortable: false },
    { key: "route",     label: "Route",     sortable: false },
    { key: "createdAt", label: "Schedule",  sortable: true  },
    { key: "driver",    label: "Driver",    sortable: true  },
    { key: "cost",      label: "Cost",      sortable: true  },
    { key: "status",    label: "Status",    sortable: true  },
    { key: "actions",   label: "Actions",   sortable: false },
  ];

  /* ══════════════ RENDER ══════════════ */
  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .ab * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .ab h1 { font-family:'Sora',sans-serif; }
        .ab-table { width:100%; border-collapse:collapse; }
        .ab-thead th { background:${CARD2}; color:#475569; font-size:10px; font-weight:700;
          text-transform:uppercase; letter-spacing:0.08em; padding:12px 16px; text-align:left;
          border-bottom:1px solid ${BORDER}; white-space:nowrap; }
        .ab-thead th.sortable { cursor:pointer; user-select:none; }
        .ab-thead th.sortable:hover { color:#94a3b8; }
        .ab-row { border-bottom:1px solid ${BORDER}; transition:background 0.14s; }
        .ab-row:last-child { border-bottom:none; }
        .ab-row:hover { background:rgba(255,255,255,0.025); }
        .ab-td { padding:12px 16px; vertical-align:middle; }
        .ab-btn-icon { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 9px; cursor:pointer; transition:all 0.18s;
          display:inline-flex; align-items:center; }
        .ab-btn-icon:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .ab-btn-approve { background:rgba(74,222,128,0.1); border:1px solid rgba(74,222,128,0.25); color:#4ade80;
          border-radius:8px; padding:6px 9px; cursor:pointer; transition:all 0.18s; display:inline-flex; align-items:center; }
        .ab-btn-approve:hover { background:rgba(74,222,128,0.2); }
        .ab-btn-reject { background:rgba(248,113,113,0.1); border:1px solid rgba(248,113,113,0.25); color:#f87171;
          border-radius:8px; padding:6px 9px; cursor:pointer; transition:all 0.18s; display:inline-flex; align-items:center; }
        .ab-btn-reject:hover { background:rgba(248,113,113,0.2); }
        .ab-filter-btn { display:flex; align-items:center; gap:8px; background:${CARD};
          border:1px solid ${BORDER}; color:#94a3b8; border-radius:10px; padding:8px 14px;
          font-size:13px; font-weight:500; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .ab-filter-btn:hover { border-color:rgba(255,255,255,0.14); color:#cbd5e1; }
        .ab-dropdown { position:absolute; right:0; top:calc(100% + 6px); background:#1e293b;
          border:1px solid ${BORDER}; border-radius:12px; z-index:50; overflow:hidden;
          box-shadow:0 16px 40px rgba(0,0,0,0.4); min-width:200px; }
        .ab-dropdown-item { width:100%; text-align:left; padding:10px 16px; font-size:13px;
          color:#94a3b8; background:none; border:none; cursor:pointer; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; justify-content:space-between; transition:background 0.14s; }
        .ab-dropdown-item:hover { background:rgba(255,255,255,0.05); color:#f1f5f9; }
        .ab-dropdown-item.on { color:#4ade80; }
        .ab-search { background:${CARD}; border:1px solid ${BORDER}; border-radius:10px;
          color:#f1f5f9; font-size:13px; padding:8px 13px 8px 36px; outline:none;
          font-family:'DM Sans',sans-serif; transition:border-color 0.15s; width:260px; }
        .ab-search::placeholder { color:#334155; }
        .ab-search:focus { border-color:rgba(74,222,128,0.35); }
        .ab-date-input { background:#0f172a; border:1px solid ${BORDER}; border-radius:8px;
          color:#94a3b8; font-size:12px; padding:6px 10px; outline:none;
          font-family:'DM Sans',sans-serif; color-scheme:dark; }
        .ab-date-input:focus { border-color:rgba(74,222,128,0.3); }
        .overlay-ab { position:fixed; inset:0; background:rgba(0,0,0,0.75); z-index:50;
          display:flex; align-items:center; justify-content:center; padding:24px; }
        .modal-ab { background:#111827; border:1px solid ${BORDER}; border-radius:20px;
          width:100%; max-width:960px; max-height:90vh; overflow:hidden;
          display:flex; flex-direction:column; box-shadow:0 24px 64px rgba(0,0,0,0.5); }
        .modal-sm { background:#111827; border:1px solid ${BORDER}; border-radius:16px;
          width:100%; max-width:440px; box-shadow:0 24px 64px rgba(0,0,0,0.5); overflow:hidden; }
        .modal-ab-body { overflow-y:auto; flex:1; }
        .ab-info-chip { background:${CARD2}; border:1px solid ${BORDER}; border-radius:10px; padding:12px 14px; }
        .field-label-ab { font-size:10px; color:#64748b; font-weight:600; text-transform:uppercase; letter-spacing:0.07em; }
        .ab-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:8px; padding:6px 10px; font-size:12px; cursor:pointer; transition:all 0.18s;
          font-family:'DM Sans',sans-serif; display:flex; align-items:center; }
        .ab-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .ab-textarea { width:100%; background:${CARD2}; border:1px solid ${BORDER}; border-radius:10px;
          padding:12px; color:#e2e8f0; font-size:13px; font-family:'DM Sans',sans-serif;
          min-height:110px; resize:vertical; outline:none; transition:border 0.18s; }
        .ab-textarea:focus { border-color:rgba(248,113,113,0.4); }
        .ab-textarea::placeholder { color:#334155; }
        .pg-btn { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:7px; padding:5px 9px; cursor:pointer; transition:all 0.14s;
          display:inline-flex; align-items:center; font-family:'DM Sans',sans-serif; font-size:12px; }
        .pg-btn:hover:not(:disabled) { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .pg-btn:disabled { opacity:0.35; cursor:default; }
        @keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }
        @media(max-width:768px){ .ab-modal-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="ab" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ══ HEADER ══ */}
        <div>
          <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0, fontFamily: "'Sora',sans-serif" }}>
            Booking Management
          </h1>
          <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>Manage all truck bookings</p>
        </div>

        {/* ══ FILTERS ROW ══ */}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>

          {/* search */}
          <div style={{ position: "relative" }}>
            <Search size={13} style={{ position: "absolute", left: 11, top: "50%", transform: "translateY(-50%)", color: "#334155", pointerEvents: "none" }} />
            <input
              className="ab-search"
              placeholder="Search customer, driver, route…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            {search && (
              <button
                onClick={() => setSearch("")}
                style={{ position: "absolute", right: 9, top: "50%", transform: "translateY(-50%)", background: "none", border: "none", cursor: "pointer", color: "#475569", padding: 0, display: "flex" }}
              >
                <X size={12} />
              </button>
            )}
          </div>

          {/* status filter */}
          <div style={{ position: "relative" }} ref={filterRef}>
            <button className="ab-filter-btn" onClick={() => setFilterOpen((v) => !v)}>
              <Filter size={14} style={{ color: "#64748b" }} />
              <span>{FILTER_OPTIONS.find((o) => o.value === filter)?.label || "All Status"}</span>
              <ChevronDown size={13} style={{ color: "#475569" }} />
            </button>
            {filterOpen && (
              <div className="ab-dropdown">
                {FILTER_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    className={`ab-dropdown-item${filter === opt.value ? " on" : ""}`}
                    onClick={() => { setFilter(opt.value); setFilterOpen(false); }}
                  >
                    <span>{opt.label}</span>
                    {filter === opt.value && <Check size={13} style={{ color: "#4ade80" }} />}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* date filter */}
          <div style={{ position: "relative" }} ref={dateRef}>
            <button className="ab-filter-btn" onClick={() => setDateOpen((v) => !v)}>
              <Calendar size={13} style={{ color: "#64748b" }} />
              <span>{DATE_PRESETS.find((o) => o.value === datePreset)?.label}</span>
              <ChevronDown size={13} style={{ color: "#475569" }} />
            </button>
            {dateOpen && (
              <div className="ab-dropdown" style={{ minWidth: 210 }}>
                {DATE_PRESETS.map(({ value, label }) => (
                  <button
                    key={value}
                    className={`ab-dropdown-item${datePreset === value ? " on" : ""}`}
                    onClick={() => { setDatePreset(value); if (value !== "custom") setDateOpen(false); }}
                  >
                    <span>{label}</span>
                    {datePreset === value && <Check size={13} style={{ color: "#4ade80" }} />}
                  </button>
                ))}
                {datePreset === "custom" && (
                  <div style={{ padding: "10px 14px 12px", borderTop: `1px solid ${BORDER}`, display: "flex", flexDirection: "column", gap: 8 }}>
                    <div>
                      <p style={{ fontSize: 10, color: "#475569", margin: "0 0 4px", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>From</p>
                      <input type="date" className="ab-date-input" value={customFrom} onChange={(e) => setCustomFrom(e.target.value)} />
                    </div>
                    <div>
                      <p style={{ fontSize: 10, color: "#475569", margin: "0 0 4px", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>To</p>
                      <input type="date" className="ab-date-input" value={customTo} onChange={(e) => setCustomTo(e.target.value)} />
                    </div>
                    <button className="ab-filter-btn" style={{ width: "100%", justifyContent: "center", fontSize: 12, marginTop: 2 }} onClick={() => setDateOpen(false)}>
                      Apply
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          <span style={{ fontSize: 12, color: "#334155", marginLeft: "auto" }}>
            {loading ? "Loading…" : `${processed.length} booking${processed.length !== 1 ? "s" : ""}`}
          </span>
        </div>

        {/* ══ TABLE ══ */}
        <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, overflow: "hidden" }}>
          <div style={{ overflowX: "auto" }}>
            <table className="ab-table">
              <thead className="ab-thead">
                <tr>
                  {COLS.map(({ key, label, sortable }) => (
                    <th
                      key={key}
                      className={sortable ? "sortable" : ""}
                      onClick={() => sortable && handleSort(key)}
                    >
                      <span style={{ display: "inline-flex", alignItems: "center" }}>
                        {label}
                        {sortable && <SortIcon col={key} sortCol={sortCol} sortDir={sortDir} />}
                      </span>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {loading && (
                  <tr>
                    <td colSpan={COLS.length} className="ab-td" style={{ textAlign: "center", padding: "52px 16px" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8, color: "#334155" }}>
                        <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} />
                        <span style={{ fontSize: 13 }}>Loading bookings…</span>
                      </div>
                    </td>
                  </tr>
                )}
                {!loading && paginated.length === 0 && (
                  <tr>
                    <td colSpan={COLS.length} className="ab-td" style={{ textAlign: "center", padding: "52px 16px" }}>
                      <AlertCircle size={20} style={{ color: "#1e293b", display: "block", margin: "0 auto 8px" }} />
                      <p style={{ color: "#334155", fontSize: 13, margin: 0 }}>
                        {search ? "No results match your search." : "No bookings found."}
                      </p>
                    </td>
                  </tr>
                )}
                {!loading && paginated.map((b) => (
                  <tr key={b.id} className="ab-row">

                    {/* CUSTOMER */}
                    <td className="ab-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                        {getBookingCustomer(b)}
                      </p>
                    </td>

                    {/* TRUCK */}
                    <td className="ab-td">
                      <span style={{
                        fontSize: 11, fontWeight: 600, color: "#60a5fa",
                        background: "rgba(96,165,250,0.1)", border: "1px solid rgba(96,165,250,0.25)",
                        borderRadius: 5, padding: "2px 8px",
                      }}>
                        {getBookingType(b)}
                      </span>
                    </td>

                    {/* ROUTE */}
                    <td className="ab-td" style={{ maxWidth: 180 }}>
                      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                        <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 11, color: "#94a3b8" }}>
                          <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                            {b.pickupLocation || "-"}
                          </span>
                        </span>
                        <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 11, color: "#94a3b8" }}>
                          <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#f87171", flexShrink: 0 }} />
                          <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                            {b.destination || "-"}
                          </span>
                        </span>
                      </div>
                    </td>

                    {/* DATE */}
                    <td className="ab-td" style={{ fontSize: 11, color: "#64748b", whiteSpace: "nowrap" }}>
                      {getBookingDate(b)}
                    </td>

                    {/* DRIVER */}
                    <td className="ab-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 500, color: b.assigned_driver_name ? "#e2e8f0" : "#334155", margin: 0 }}>
                        {getBookingDriver(b)}
                      </p>
                    </td>

                    {/* COST */}
                    <td className="ab-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>{getBookingCost(b)}</p>
                      <p style={{ fontSize: 11, color: "#475569", margin: "2px 0 0" }}>{getBookingDistance(b)}</p>
                    </td>

                    {/* STATUS */}
                    <td className="ab-td">
                      <StatusPill status={b.status} />
                    </td>

                    {/* ACTIONS */}
                    <td className="ab-td">
                      <div style={{ display: "flex", gap: 6 }}>
                        <button className="ab-btn-icon" onClick={() => setSelectedBooking(b)}>
                          <Eye size={14} />
                        </button>
                        {b.status === "pending" && (
                          <>
                            <button className="ab-btn-approve" onClick={() => updateStatus.mutate({ id: b.id, status: "approved" })}>
                              <Check size={14} />
                            </button>
                            <button className="ab-btn-reject" onClick={() => openReject(b)}>
                              <X size={14} />
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

          {/* ══ PAGINATION ══ */}
          {!loading && processed.length > PAGE_SIZE && (
            <div style={{
              display: "flex", alignItems: "center", justifyContent: "space-between",
              padding: "12px 16px", borderTop: `1px solid ${BORDER}`, background: CARD2,
            }}>
              <span style={{ fontSize: 12, color: "#334155" }}>
                Page {page} of {totalPages} · {processed.length} entries
              </span>
              <div style={{ display: "flex", gap: 6 }}>
                <button className="pg-btn" disabled={page === 1} onClick={() => setPage(1)}>
                  <ChevronLeft size={12} /><ChevronLeft size={12} style={{ marginLeft: -4 }} />
                </button>
                <button className="pg-btn" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
                  <ChevronLeft size={12} />
                </button>
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const start = Math.max(1, Math.min(page - 2, totalPages - 4));
                  const pg    = start + i;
                  return pg <= totalPages ? (
                    <button
                      key={pg}
                      className="pg-btn"
                      onClick={() => setPage(pg)}
                      style={pg === page ? { color: "#4ade80", borderColor: "rgba(74,222,128,0.3)", background: "rgba(74,222,128,0.06)" } : {}}
                    >
                      {pg}
                    </button>
                  ) : null;
                })}
                <button className="pg-btn" disabled={page === totalPages} onClick={() => setPage((p) => p + 1)}>
                  <ChevronRight size={12} />
                </button>
                <button className="pg-btn" disabled={page === totalPages} onClick={() => setPage(totalPages)}>
                  <ChevronRight size={12} /><ChevronRight size={12} style={{ marginLeft: -4 }} />
                </button>
              </div>
            </div>
          )}
        </div>

      </div>

      {/* ══ REJECT MODAL ══ */}
      {rejectModal && (
        <div className="overlay-ab" onClick={(e) => { if (e.target === e.currentTarget) setRejectModal(false); }}>
          <div className="modal-sm">
            <div style={{ padding: "18px 22px 14px", borderBottom: `1px solid ${BORDER}`,
              display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#f87171", fontWeight: 700, letterSpacing: "0.18em",
                  textTransform: "uppercase", margin: "0 0 4px" }}>Booking</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Reject Booking</p>
                <p style={{ fontSize: 12, color: "#64748b", margin: "3px 0 0" }}>Please provide a reason before rejecting</p>
              </div>
              <button className="ab-btn-ghost" onClick={() => setRejectModal(false)}>
                <X size={14} />
              </button>
            </div>
            <div style={{ padding: "20px 22px" }}>
              <p className="field-label-ab" style={{ margin: "0 0 8px" }}>Rejection Reason</p>
              <textarea
                className="ab-textarea"
                placeholder="Enter rejection reason..."
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
              />
              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, marginTop: 16 }}>
                <button className="ab-btn-ghost" onClick={() => setRejectModal(false)}>Cancel</button>
                <button
                  onClick={confirmReject}
                  style={{
                    background: "rgba(248,113,113,0.1)", border: "1px solid rgba(248,113,113,0.3)",
                    color: "#f87171", borderRadius: 8, padding: "7px 18px", fontSize: 13, fontWeight: 600,
                    cursor: "pointer", fontFamily: "'DM Sans',sans-serif", transition: "all 0.18s",
                  }}
                >
                  Confirm Reject
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ══ DETAILS MODAL ══ */}
      {selectedBooking && (
        <div className="overlay-ab" onClick={(e) => { if (e.target === e.currentTarget) setSelectedBooking(null); }}>
          <div className="modal-ab">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`,
              display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
              <div>
                <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.18em",
                  textTransform: "uppercase", margin: "0 0 4px" }}>Booking</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Booking Details</p>
                <p style={{ fontSize: 12, color: "#64748b", margin: "3px 0 0" }}>Full booking information and tracking overview</p>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <StatusPill status={selectedBooking.status} />
                <button className="ab-btn-ghost" onClick={() => setSelectedBooking(null)}>
                  <X size={14} />
                </button>
              </div>
            </div>

            <div className="modal-ab-body">
              <div
                className="ab-modal-grid"
                style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20, padding: 24 }}
              >
                {/* ── LEFT ── */}
                <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
                  <div>
                    <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                      letterSpacing: "0.14em", margin: "0 0 12px" }}>Booking Info</p>
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                      {[
                        ["Customer",   getBookingCustomer(selectedBooking)],
                        ["Truck Type", getBookingType(selectedBooking)],
                        ["Schedule",   getBookingDate(selectedBooking)],
                        ["Driver",     getBookingDriver(selectedBooking)],
                        ["Est. Cost",  getBookingCost(selectedBooking)],
                        ["Distance",   getBookingDistance(selectedBooking)],
                        ["Plate No.",  selectedBooking.assigned_truck_plate_number || "-"],
                      ].map(([label, value]) => (
                        <div key={label} className="ab-info-chip">
                          <p className="field-label-ab" style={{ margin: "0 0 4px" }}>{label}</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0, wordBreak: "break-word" }}>{value}</p>
                        </div>
                      ))}
                    </div>
                  </div>

                  {(getBookingCustomerPhone(selectedBooking) || getBookingCustomerEmail(selectedBooking)) && (
                    <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                      <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 10px" }}>Customer Contact</p>
                      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                        {getBookingCustomerPhone(selectedBooking) && (
                          <p style={{ fontSize: 13, color: "#94a3b8", margin: 0, display: "flex", alignItems: "center", gap: 8 }}>
                            <Phone size={12} style={{ flexShrink: 0, color: "#475569" }} />
                            {getBookingCustomerPhone(selectedBooking)}
                          </p>
                        )}
                        {getBookingCustomerEmail(selectedBooking) && (
                          <p style={{ fontSize: 13, color: "#94a3b8", margin: 0, display: "flex", alignItems: "center", gap: 8 }}>
                            <Mail size={12} style={{ flexShrink: 0, color: "#475569" }} />
                            {getBookingCustomerEmail(selectedBooking)}
                          </p>
                        )}
                      </div>
                    </div>
                  )}

                  {selectedBooking.notes && (
                    <div style={{ background: "rgba(251,191,36,0.06)", border: "1px solid rgba(251,191,36,0.15)",
                      borderRadius: 12, padding: "14px 16px" }}>
                      <p style={{ fontSize: 10, color: "#fbbf24", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 6px" }}>Customer Notes</p>
                      <p style={{ fontSize: 12, color: "#fde68a", margin: 0, fontStyle: "italic" }}>
                        "{selectedBooking.notes}"
                      </p>
                    </div>
                  )}
                </div>

                {/* ── RIGHT ── */}
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                  <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                    <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                      letterSpacing: "0.14em", margin: "0 0 12px" }}>Route</p>
                    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                        <span style={{ marginTop: 4, width: 8, height: 8, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                        <div>
                          <p className="field-label-ab" style={{ margin: "0 0 2px" }}>Pickup</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                            {selectedBooking.pickupLocation || "-"}
                          </p>
                        </div>
                      </div>
                      <div style={{ marginLeft: 3, borderLeft: "2px dashed rgba(255,255,255,0.07)", height: 12 }} />
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                        <span style={{ marginTop: 4, width: 8, height: 8, borderRadius: "50%", background: "#f87171", flexShrink: 0 }} />
                        <div>
                          <p className="field-label-ab" style={{ margin: "0 0 2px" }}>Destination</p>
                          <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                            {selectedBooking.destination || "-"}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                    <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                      letterSpacing: "0.14em", margin: "0 0 12px" }}>Booking Summary</p>
                    {[
                      ["Status",   selectedBooking.status],
                      ["Type",     getBookingType(selectedBooking)],
                      ["Driver",   getBookingDriver(selectedBooking)],
                      ["Cost",     getBookingCost(selectedBooking)],
                      ["Distance", getBookingDistance(selectedBooking)],
                    ].map(([label, value]) => (
                      <div key={label} style={{ display: "flex", justifyContent: "space-between",
                        alignItems: "center", padding: "6px 0", borderBottom: `1px solid ${BORDER}` }}>
                        <span style={{ fontSize: 12, color: "#475569" }}>{label}</span>
                        <span style={{ fontSize: 12, fontWeight: 600, color: "#e2e8f0", textTransform: "capitalize" }}>{value}</span>
                      </div>
                    ))}
                  </div>

                  {(selectedBooking.status === "rejected" || selectedBooking.status === "cancelled") &&
                    getBookingStatusNote(selectedBooking) && (
                      <div style={{ background: "rgba(248,113,113,0.06)", border: "1px solid rgba(248,113,113,0.2)",
                        borderRadius: 12, padding: "14px 16px" }}>
                        <p style={{ fontSize: 10, color: "#f87171", fontWeight: 700, textTransform: "uppercase",
                          letterSpacing: "0.14em", margin: "0 0 6px" }}>
                          {selectedBooking.status === "rejected" ? "Rejection Notes" : "Cancellation Notes"}
                        </p>
                        <p style={{ fontSize: 12, color: "#fca5a5", margin: 0, fontStyle: "italic" }}>
                          "{getBookingStatusNote(selectedBooking)}"
                        </p>
                      </div>
                    )}

                  {getTimeline(selectedBooking).length > 0 && (
                    <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                      <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 14px" }}>Delivery Timeline</p>
                      <div style={{ position: "relative" }}>
                        {getTimeline(selectedBooking).map((t, i, arr) => (
                          <div key={i} style={{ display: "flex", alignItems: "flex-start", gap: 12, position: "relative" }}>
                            {i < arr.length - 1 && (
                              <div style={{ position: "absolute", left: 6, top: 16, width: 1,
                                height: "100%", background: BORDER }} />
                            )}
                            <div style={{ marginTop: 3, width: 13, height: 13, borderRadius: "50%",
                              background: G_DIM, border: `2px solid #4ade80`, flexShrink: 0, zIndex: 1 }} />
                            <div style={{ paddingBottom: 16 }}>
                              <p style={{ fontSize: 12, fontWeight: 600, color: "#cbd5e1", margin: 0 }}>{t.label}</p>
                              <p style={{ fontSize: 11, color: "#475569", margin: "2px 0 0" }}>{formatTimestamp(t.ts)}</p>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}