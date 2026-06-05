import React, { useState, useEffect, useRef, useMemo } from "react";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import {
  Eye, Filter, ChevronDown, Check, X, Search,
  Calendar, Download, ArrowUpDown, ArrowUp, ArrowDown,
  AlertCircle, Loader2, UserCheck, RefreshCw, XCircle,
  ClipboardList, ChevronLeft, ChevronRight,
} from "lucide-react";
import { format, startOfDay, endOfDay, subDays } from "date-fns";

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

const FILTER_OPTIONS = [
  { value: "all",        label: "All Decisions", Icon: ClipboardList },
  { value: "assigned",   label: "Assigned",      Icon: UserCheck     },
  { value: "reassigned", label: "Reassigned",    Icon: RefreshCw     },
  { value: "rejected",   label: "Rejected",      Icon: XCircle       },
];

const DATE_PRESETS = [
  { value: "all",    label: "All Time"     },
  { value: "today",  label: "Today"        },
  { value: "7d",     label: "Last 7 Days"  },
  { value: "30d",    label: "Last 30 Days" },
  { value: "custom", label: "Custom Range" },
];

const DECISION_META = {
  assigned:   { color: "#34d399", bg: "rgba(52,211,153,0.08)",  border: "rgba(52,211,153,0.22)"  },
  reassigned: { color: "#fbbf24", bg: "rgba(251,191,36,0.08)",  border: "rgba(251,191,36,0.22)"  },
  rejected:   { color: "#f87171", bg: "rgba(248,113,113,0.08)", border: "rgba(248,113,113,0.22)" },
};

const BOOKING_STATUS_META = {
  approved:           { color: "#4ade80", bg: G_DIM,                        border: G_BRD                        },
  assigned:           { color: "#60a5fa", bg: "rgba(96,165,250,0.1)",       border: "rgba(96,165,250,0.25)"      },
  pending:            { color: "#fbbf24", bg: "rgba(251,191,36,0.1)",       border: "rgba(251,191,36,0.25)"      },
  cancelled:          { color: "#f87171", bg: "rgba(248,113,113,0.1)",      border: "rgba(248,113,113,0.25)"     },
  delivered:          { color: "#34d399", bg: "rgba(52,211,153,0.1)",       border: "rgba(52,211,153,0.25)"      },
  in_transit:         { color: "#a78bfa", bg: "rgba(167,139,250,0.1)",      border: "rgba(167,139,250,0.25)"     },
  pending_assignment: { color: "#fbbf24", bg: "rgba(251,191,36,0.1)",       border: "rgba(251,191,36,0.25)"      },
  completed:          { color: "#34d399", bg: "rgba(52,211,153,0.1)",       border: "rgba(52,211,153,0.25)"      },
};

const PAGE_SIZE = 15;

/* ─── Helpers ─── */
const fmtTs = (ts) =>
  ts?.seconds ? format(new Date(ts.seconds * 1000), "MMM d, yyyy hh:mm a") : "-";

const fmtTruckType = (val) => {
  if (!val) return "-";
  return String(val).split("_").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
};

const fmtCost = (val) =>
  val != null ? `₱${Number(val).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : "-";

const fmtDistance = (val) =>
  val != null ? `${Number(val).toFixed(2)} km` : "-";

const toDate = (ts) => ts?.seconds ? new Date(ts.seconds * 1000) : null;

/* ─── Sub-components ─── */
const DecisionPill = ({ decision, size = "sm" }) => {
  const d    = (decision || "").toLowerCase();
  const meta = DECISION_META[d] || { color: "#94a3b8", bg: "rgba(148,163,184,0.08)", border: "rgba(148,163,184,0.22)" };
  const pad  = size === "lg" ? "5px 14px" : "3px 10px";
  const fs   = size === "lg" ? 12 : 11;
  return (
    <span style={{
      fontSize: fs, fontWeight: 700, color: meta.color, background: meta.bg,
      border: `1px solid ${meta.border}`, borderRadius: 6, padding: pad,
      display: "inline-flex", alignItems: "center", gap: 5, textTransform: "capitalize",
      letterSpacing: "0.03em",
    }}>
      <span style={{ width: 5, height: 5, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
      {decision || "-"}
    </span>
  );
};

const BookingStatusPill = ({ status }) => {
  const s    = (status || "").toLowerCase();
  const meta = BOOKING_STATUS_META[s] || { color: "#94a3b8", bg: "rgba(148,163,184,0.08)", border: "rgba(148,163,184,0.22)" };
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, color: meta.color, background: meta.bg,
      border: `1px solid ${meta.border}`, borderRadius: 6, padding: "3px 10px",
      display: "inline-flex", alignItems: "center", gap: 5, textTransform: "capitalize",
      letterSpacing: "0.03em",
    }}>
      <span style={{ width: 5, height: 5, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
      {(status || "-").replace(/_/g, " ")}
    </span>
  );
};

const InfoChip = ({ label, value, mono }) => (
  <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 10, padding: "12px 14px" }}>
    <p style={{ fontSize: 10, color: "#475569", fontWeight: 700, textTransform: "uppercase",
      letterSpacing: "0.07em", margin: "0 0 4px" }}>{label}</p>
    <p style={{
      fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0, wordBreak: "break-all",
      fontFamily: mono ? "monospace" : "inherit",
    }}>
      {value || "-"}
    </p>
  </div>
);

const SortIcon = ({ col, sortCol, sortDir }) => {
  if (sortCol !== col) return <ArrowUpDown size={11} style={{ color: "#334155", marginLeft: 4 }} />;
  return sortDir === "asc"
    ? <ArrowUp size={11} style={{ color: "#4ade80", marginLeft: 4 }} />
    : <ArrowDown size={11} style={{ color: "#4ade80", marginLeft: 4 }} />;
};

/* ─── CSV Export ─── */
const exportCSV = (rows) => {
  const headers = ["Timestamp","Driver","Driver Email","Truck Type","Plate No.","Booking ID","Decision","Customer","Pickup","Destination","Est. Cost","Est. Distance","Booking Status"];
  const body = rows.map((l) => [
    fmtTs(l.timestamp),
    l.assigned_driver_name        || "",
    l.assigned_driver_email       || "",
    fmtTruckType(l.assigned_truck_type),
    l.assigned_truck_plate_number || "",
    l.booking_id                  || "",
    l.decision                    || "",
    l.booking?.customerName       || "",
    l.booking?.pickupLocation     || "",
    l.booking?.destination        || "",
    fmtCost(l.booking?.estimatedCost),
    fmtDistance(l.booking?.estimatedDistance),
    l.booking_status_at_log       || "",
  ].map((v) => `"${String(v).replace(/"/g, '""')}"`).join(","));
  const csv  = [headers.join(","), ...body].join("\n");
  const blob = new Blob([csv], { type: "text/csv" });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement("a"); a.href = url;
  a.download = `dispatch_log_${format(new Date(), "yyyy-MM-dd")}.csv`;
  a.click(); URL.revokeObjectURL(url);
};

/* ══════════════════════════════════════════════════════════
   MAIN COMPONENT
══════════════════════════════════════════════════════════ */
export default function AdminDispatchLog() {
  const { data: logs     = [], loading: logsLoading     } = useFirestoreCollection("dispatch_logs");
  const { data: bookings = [], loading: bookingsLoading } = useFirestoreCollection("bookings");
  const { data: users    = []                           } = useFirestoreCollection("users");

  const loading = logsLoading || bookingsLoading;

  const enrichedLogs = useMemo(() => logs.map((log) => {
    const booking      = bookings.find((b) => b.id === log.booking_id) || null;
    const customer     = booking?.userId ? users.find((u) => u.id === booking.userId) : null;
    const customerName = customer?.fullName || customer?.name || booking?.customerName || "-";
    return { ...log, booking: booking ? { ...booking, customerName } : null };
  }), [logs, bookings, users]);

  const [decisionFilter, setDecisionFilter] = useState("all");
  const [filterOpen,     setFilterOpen]     = useState(false);
  const [datePreset,     setDatePreset]     = useState("all");
  const [dateOpen,       setDateOpen]       = useState(false);
  const [customFrom,     setCustomFrom]     = useState("");
  const [customTo,       setCustomTo]       = useState("");
  const [search,         setSearch]         = useState("");
  const [sortCol,        setSortCol]        = useState("timestamp");
  const [sortDir,        setSortDir]        = useState("desc");
  const [page,           setPage]           = useState(1);
  const [selectedLog,    setSelectedLog]    = useState(null);

  const filterRef = useRef(null);
  const dateRef   = useRef(null);

  useEffect(() => {
    const h = (e) => {
      if (filterOpen && filterRef.current && !filterRef.current.contains(e.target)) setFilterOpen(false);
      if (dateOpen   && dateRef.current   && !dateRef.current.contains(e.target))   setDateOpen(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, [filterOpen, dateOpen]);

  useEffect(() => { setPage(1); }, [decisionFilter, datePreset, customFrom, customTo, search, sortCol, sortDir]);

  const dateWindow = useMemo(() => {
    const now = new Date();
    if (datePreset === "today")  return { from: startOfDay(now), to: endOfDay(now) };
    if (datePreset === "7d")     return { from: startOfDay(subDays(now, 6)), to: endOfDay(now) };
    if (datePreset === "30d")    return { from: startOfDay(subDays(now, 29)), to: endOfDay(now) };
    if (datePreset === "custom" && customFrom && customTo) {
      const from = startOfDay(new Date(customFrom + "T00:00"));
      const to   = endOfDay(new Date(customTo + "T00:00"));
      if (from <= to) return { from, to };
    }
    return null;
  }, [datePreset, customFrom, customTo]);

  const processed = useMemo(() => {
    let arr = [...enrichedLogs];

    if (decisionFilter !== "all")
      arr = arr.filter((l) => (l.decision || "").toLowerCase() === decisionFilter);

  if (dateWindow)
    arr = arr.filter((l) => {
      const d = toDate(l.timestamp);
      if (!d) return false;
      return d >= dateWindow.from && d <= dateWindow.to;
    });

    const q = search.trim().toLowerCase();
    if (q)
      arr = arr.filter((l) =>
        [
          l.assigned_driver_name,
          l.assigned_driver_email,
          l.booking_id,
          l.assigned_truck_plate_number,
          l.booking?.customerName,
          l.booking?.pickupLocation,
          l.booking?.destination,
        ].some((v) => (v || "").toLowerCase().includes(q))
      );

    arr.sort((a, b) => {
      let va, vb;
      if (sortCol === "timestamp") {
        va = a.timestamp?.seconds || 0;
        vb = b.timestamp?.seconds || 0;
      } else if (sortCol === "driver") {
        va = (a.assigned_driver_name || "").toLowerCase();
        vb = (b.assigned_driver_name || "").toLowerCase();
      } else if (sortCol === "decision") {
        va = (a.decision || "").toLowerCase();
        vb = (b.decision || "").toLowerCase();
      } else if (sortCol === "customer") {
        va = (a.booking?.customerName || "").toLowerCase();
        vb = (b.booking?.customerName || "").toLowerCase();
      } else {
        va = (a[sortCol] || "").toString().toLowerCase();
        vb = (b[sortCol] || "").toString().toLowerCase();
      }
      if (va < vb) return sortDir === "asc" ? -1 : 1;
      if (va > vb) return sortDir === "asc" ? 1 : -1;
      return 0;
    });

    return arr;
  }, [enrichedLogs, decisionFilter, dateWindow, search, sortCol, sortDir]);

  const totalPages = Math.max(1, Math.ceil(processed.length / PAGE_SIZE));
  const paginated  = processed.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const handleSort = (col) => {
    if (sortCol === col) setSortDir((d) => d === "asc" ? "desc" : "asc");
    else { setSortCol(col); setSortDir("desc"); }
  };

  const stats = useMemo(() => ({
    total:      enrichedLogs.length,
    assigned:   enrichedLogs.filter((l) => (l.decision || "").toLowerCase() === "assigned").length,
    reassigned: enrichedLogs.filter((l) => (l.decision || "").toLowerCase() === "reassigned").length,
    rejected:   enrichedLogs.filter((l) => (l.decision || "").toLowerCase() === "rejected").length,
  }), [enrichedLogs]);

  const getTimeline = (log) => {
    const b = log.booking;
    if (!b) return [];

    const isRejected = (log.decision || "").toLowerCase() === "rejected";

    const all = [
      { label: "Booking Created",    ts: b.createdAt         },
      { label: "Driver Assigned",    ts: log.timestamp       },
      // ── only show these for non-rejected logs ──
      ...(!isRejected ? [
        { label: "Driver Accepted",    ts: b.acceptedAt        },
        { label: "En Route to Pickup", ts: b.enRouteAt         },
        { label: "Arrived at Pickup",  ts: b.arrivedAtPickupAt },
        { label: "In Transit",         ts: b.inTransitAt       },
        { label: "Delivered",          ts: b.deliveredAt       },
      ] : [
        { label: "Driver Rejected",    ts: b.rejectedAt        },
      ]),
    ];

    return all.filter((t) => t.ts);
  };

  const COLS = [
    { key: "timestamp", label: "Timestamp",     sortable: true  },
    { key: "driver",    label: "Driver",         sortable: true  },
    { key: "truck",     label: "Truck",          sortable: false },
    { key: "route",     label: "Route",          sortable: false },
    { key: "customer",  label: "Customer",       sortable: true  },
    { key: "cost",      label: "Cost / Dist",    sortable: false },
    { key: "decision",  label: "Decision",       sortable: true  },
    { key: "bstatus",   label: "Booking Status", sortable: false },
    { key: "action",    label: "",               sortable: false },
  ];

  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .dl*{font-family:'DM Sans',sans-serif;box-sizing:border-box;}
        .dl h1{font-family:'Sora',sans-serif;}
        .dl-table{width:100%;border-collapse:collapse;}
        .dl-th{background:${CARD2};color:#475569;font-size:10px;font-weight:700;
          text-transform:uppercase;letter-spacing:0.08em;padding:11px 14px;text-align:left;
          border-bottom:1px solid ${BORDER};white-space:nowrap;}
        .dl-th.sortable{cursor:pointer;user-select:none;}
        .dl-th.sortable:hover{color:#94a3b8;}
        .dl-row{border-bottom:1px solid ${BORDER};transition:background 0.13s;cursor:pointer;}
        .dl-row:last-child{border-bottom:none;}
        .dl-row:hover{background:rgba(255,255,255,0.025);}
        .dl-td{padding:11px 14px;vertical-align:middle;}
        .dl-icon-btn{background:rgba(255,255,255,0.04);border:1px solid ${BORDER};color:#64748b;
          border-radius:8px;padding:6px 9px;cursor:pointer;transition:all 0.15s;
          display:inline-flex;align-items:center;font-family:'DM Sans',sans-serif;}
        .dl-icon-btn:hover{color:#cbd5e1;border-color:rgba(255,255,255,0.14);}
        .dl-dropdown-wrap{position:absolute;right:0;top:calc(100% + 6px);background:#1e293b;
          border:1px solid ${BORDER};border-radius:12px;z-index:60;overflow:hidden;
          box-shadow:0 16px 40px rgba(0,0,0,0.45);min-width:190px;}
        .dl-ddi{width:100%;text-align:left;padding:10px 16px;font-size:13px;color:#94a3b8;
          background:none;border:none;cursor:pointer;font-family:'DM Sans',sans-serif;
          display:flex;align-items:center;gap:8px;transition:background 0.13s;}
        .dl-ddi:hover{background:rgba(255,255,255,0.05);color:#f1f5f9;}
        .dl-ddi.on{color:#4ade80;}
        .dl-ddi .check{margin-left:auto;}
        .dl-filter-btn{display:flex;align-items:center;gap:7px;background:${CARD};
          border:1px solid ${BORDER};color:#94a3b8;border-radius:10px;padding:8px 13px;
          font-size:13px;font-weight:500;cursor:pointer;transition:all 0.15s;
          font-family:'DM Sans',sans-serif;}
        .dl-filter-btn:hover{border-color:rgba(255,255,255,0.14);color:#cbd5e1;}
        .dl-search{background:${CARD};border:1px solid ${BORDER};border-radius:10px;
          color:#f1f5f9;font-size:13px;padding:8px 13px 8px 36px;outline:none;
          font-family:'DM Sans',sans-serif;transition:border-color 0.15s;width:260px;}
        .dl-search::placeholder{color:#334155;}
        .dl-search:focus{border-color:rgba(74,222,128,0.35);}
        .dl-date-input{background:#0f172a;border:1px solid ${BORDER};border-radius:8px;
          color:#94a3b8;font-size:12px;padding:6px 10px;outline:none;
          font-family:'DM Sans',sans-serif;color-scheme:dark;}
        .dl-date-input:focus{border-color:rgba(74,222,128,0.3);}
        .overlay-dl{position:fixed;inset:0;background:rgba(0,0,0,0.78);z-index:50;
          display:flex;align-items:center;justify-content:center;padding:24px;}
        .modal-dl{background:#111827;border:1px solid ${BORDER};border-radius:20px;
          width:100%;max-width:960px;max-height:92vh;overflow:hidden;
          display:flex;flex-direction:column;box-shadow:0 24px 64px rgba(0,0,0,0.55);}
        .modal-dl-body{overflow-y:auto;flex:1;}
        .dl-info-chip{background:${CARD2};border:1px solid ${BORDER};border-radius:10px;padding:12px 14px;}
        .field-label-dl{font-size:10px;color:#64748b;font-weight:600;text-transform:uppercase;letter-spacing:0.07em;}
        .pg-btn{background:rgba(255,255,255,0.04);border:1px solid ${BORDER};color:#64748b;
          border-radius:7px;padding:5px 9px;cursor:pointer;transition:all 0.14s;
          display:inline-flex;align-items:center;font-family:'DM Sans',sans-serif;font-size:12px;}
        .pg-btn:hover:not(:disabled){color:#cbd5e1;border-color:rgba(255,255,255,0.14);}
        .pg-btn:disabled{opacity:0.35;cursor:default;}
        .stat-card{background:${CARD};border:1px solid ${BORDER};border-radius:12px;padding:14px 18px;flex:1;min-width:120px;}
        .dl-btn-ghost{background:rgba(255,255,255,0.04);border:1px solid ${BORDER};color:#94a3b8;
          border-radius:8px;padding:6px 10px;font-size:12px;cursor:pointer;
          transition:all 0.18s;font-family:'DM Sans',sans-serif;display:flex;align-items:center;}
        .dl-btn-ghost:hover{color:#cbd5e1;border-color:rgba(255,255,255,0.14);}
        @keyframes spin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}
        @media(max-width:768px){.dl-modal-grid{grid-template-columns:1fr !important;}}
      `}</style>

      <div className="dl" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ── HEADER ── */}
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexWrap: "wrap", gap: 12 }}>
          <div>
            <h1 style={{ fontSize: 26, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>Dispatch Log</h1>
            <p style={{ color: "#475569", fontSize: 13, margin: "4px 0 0" }}>
              Full audit trail of all driver assignment events and linked booking details
            </p>
          </div>
          <button
            className="dl-filter-btn"
            onClick={() => exportCSV(processed)}
            style={{ borderColor: "rgba(74,222,128,0.2)", color: "#4ade80" }}
          >
            <Download size={13} />
            Export CSV
          </button>
        </div>

        {/* ── STAT CARDS ── */}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          {[
            { label: "Total Events", value: stats.total,      color: "#94a3b8" },
            { label: "Assigned",     value: stats.assigned,   color: "#34d399" },
            { label: "Reassigned",   value: stats.reassigned, color: "#fbbf24" },
            { label: "Rejected",     value: stats.rejected,   color: "#f87171" },
          ].map(({ label, value, color }) => (
            <div key={label} className="stat-card">
              <p style={{ fontSize: 10, color: "#475569", fontWeight: 700, textTransform: "uppercase",
                letterSpacing: "0.08em", margin: "0 0 6px" }}>{label}</p>
              <p style={{ fontSize: 22, fontWeight: 800, color, margin: 0, fontFamily: "'Sora',sans-serif" }}>
                {loading ? "—" : value}
              </p>
            </div>
          ))}
        </div>

        {/* ── FILTERS ROW ── */}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>

          {/* search */}
          <div style={{ position: "relative" }}>
            <Search size={13} style={{ position: "absolute", left: 11, top: "50%", transform: "translateY(-50%)", color: "#334155", pointerEvents: "none" }} />
            <input
              className="dl-search"
              placeholder="Search driver, customer, booking, plate…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            {search && (
              <button onClick={() => setSearch("")} style={{ position: "absolute", right: 9, top: "50%", transform: "translateY(-50%)", background: "none", border: "none", cursor: "pointer", color: "#475569", padding: 0, display: "flex" }}>
                <X size={12} />
              </button>
            )}
          </div>

          {/* decision filter */}
          <div style={{ position: "relative" }} ref={filterRef}>
            <button className="dl-filter-btn" onClick={() => setFilterOpen((v) => !v)}>
              <Filter size={13} style={{ color: "#64748b" }} />
              <span>{FILTER_OPTIONS.find((o) => o.value === decisionFilter)?.label}</span>
              <ChevronDown size={12} style={{ color: "#475569" }} />
            </button>
            {filterOpen && (
              <div className="dl-dropdown-wrap">
                {FILTER_OPTIONS.map(({ value, label, Icon }) => (
                  <button
                    key={value}
                    className={`dl-ddi${decisionFilter === value ? " on" : ""}`}
                    onClick={() => { setDecisionFilter(value); setFilterOpen(false); }}
                  >
                    <Icon size={13} style={{ opacity: 0.7 }} />
                    <span>{label}</span>
                    {decisionFilter === value && <Check size={12} style={{ color: "#4ade80" }} className="check" />}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* date filter */}
          <div style={{ position: "relative" }} ref={dateRef}>
            <button className="dl-filter-btn" onClick={() => setDateOpen((v) => !v)}>
              <Calendar size={13} style={{ color: "#64748b" }} />
              <span>{DATE_PRESETS.find((o) => o.value === datePreset)?.label}</span>
              <ChevronDown size={12} style={{ color: "#475569" }} />
            </button>
            {dateOpen && (
              <div className="dl-dropdown-wrap" style={{ minWidth: 210 }}>
                {DATE_PRESETS.map(({ value, label }) => (
                  <button
                    key={value}
                    className={`dl-ddi${datePreset === value ? " on" : ""}`}
                    onClick={() => { setDatePreset(value); if (value !== "custom") setDateOpen(false); }}
                  >
                    <span>{label}</span>
                    {datePreset === value && <Check size={12} style={{ color: "#4ade80" }} className="check" />}
                  </button>
                ))}
                {datePreset === "custom" && (
                  <div style={{ padding: "10px 14px 12px", borderTop: `1px solid ${BORDER}`, display: "flex", flexDirection: "column", gap: 8 }}>
                    <div>
                      <p style={{ fontSize: 10, color: "#475569", margin: "0 0 4px", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>From</p>
                      <input type="date" className="dl-date-input" value={customFrom} onChange={(e) => setCustomFrom(e.target.value)} />
                    </div>
                    <div>
                      <p style={{ fontSize: 10, color: "#475569", margin: "0 0 4px", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>To</p>
                      <input type="date" className="dl-date-input" value={customTo} onChange={(e) => setCustomTo(e.target.value)} />
                    </div>
                    <button className="dl-filter-btn" style={{ width: "100%", justifyContent: "center", fontSize: 12, marginTop: 2 }} onClick={() => setDateOpen(false)}>
                      Apply
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          <span style={{ fontSize: 12, color: "#334155", marginLeft: "auto" }}>
            {loading ? "Loading…" : `${processed.length} result${processed.length !== 1 ? "s" : ""}`}
          </span>
        </div>

        {/* ── TABLE ── */}
        <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, overflow: "hidden" }}>
          <div style={{ overflowX: "auto" }}>
            <table className="dl-table">
              <thead>
                <tr>
                  {COLS.map(({ key, label, sortable }) => (
                    <th
                      key={key}
                      className={`dl-th${sortable ? " sortable" : ""}`}
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
                    <td colSpan={COLS.length} className="dl-td" style={{ textAlign: "center", padding: "52px 16px" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8, color: "#334155" }}>
                        <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} />
                        <span style={{ fontSize: 13 }}>Loading dispatch logs…</span>
                      </div>
                    </td>
                  </tr>
                )}
                {!loading && paginated.length === 0 && (
                  <tr>
                    <td colSpan={COLS.length} className="dl-td" style={{ textAlign: "center", padding: "52px 16px" }}>
                      <AlertCircle size={20} style={{ color: "#1e293b", display: "block", margin: "0 auto 8px" }} />
                      <p style={{ color: "#334155", fontSize: 13, margin: 0 }}>
                        {search ? "No results match your search." : "No dispatch log entries found."}
                      </p>
                    </td>
                  </tr>
                )}
                {!loading && paginated.map((log) => (
                  <tr key={log.id} className="dl-row" onClick={() => setSelectedLog(log)}>

                    <td className="dl-td" style={{ fontSize: 11, color: "#64748b", whiteSpace: "nowrap" }}>
                      {fmtTs(log.timestamp)}
                    </td>

                    <td className="dl-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                        {log.assigned_driver_name || "-"}
                      </p>
                      <p style={{ fontSize: 11, color: "#475569", margin: "2px 0 0" }}>
                        {log.assigned_driver_email || ""}
                      </p>
                    </td>

                    <td className="dl-td" style={{ whiteSpace: "nowrap" }}>
                      <span style={{
                        fontSize: 11, fontWeight: 600, color: "#60a5fa",
                        background: "rgba(96,165,250,0.08)", border: "1px solid rgba(96,165,250,0.22)",
                        borderRadius: 5, padding: "2px 8px",
                      }}>
                        {fmtTruckType(log.assigned_truck_type)}
                      </span>
                      <p style={{ fontSize: 11, color: "#475569", margin: "4px 0 0" }}>
                        {log.assigned_truck_plate_number || ""}
                      </p>
                    </td>

                    <td className="dl-td" style={{ maxWidth: 180 }}>
                      {log.booking ? (
                        <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 11, color: "#94a3b8" }}>
                            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 150 }}>
                              {log.booking.pickupLocation || "-"}
                            </span>
                          </span>
                          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 11, color: "#94a3b8" }}>
                            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#f87171", flexShrink: 0 }} />
                            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 150 }}>
                              {log.booking.destination || "-"}
                            </span>
                          </span>
                        </div>
                      ) : (
                        <span style={{ fontSize: 11, color: "#334155" }}>—</span>
                      )}
                    </td>

                    <td className="dl-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                        {log.booking?.customerName || "-"}
                      </p>
                    </td>

                    <td className="dl-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                        {fmtCost(log.booking?.estimatedCost)}
                      </p>
                      <p style={{ fontSize: 11, color: "#475569", margin: "2px 0 0" }}>
                        {fmtDistance(log.booking?.estimatedDistance)}
                      </p>
                    </td>

                    <td className="dl-td">
                      <DecisionPill decision={log.decision} />
                    </td>

                    <td className="dl-td">
                      {log.booking_status_at_log
                        ? <BookingStatusPill status={log.booking_status_at_log} />
                        : <span style={{ fontSize: 11, color: "#334155" }}>—</span>}
                    </td>

                    <td className="dl-td" onClick={(e) => e.stopPropagation()}>
                      <button className="dl-icon-btn" onClick={() => setSelectedLog(log)} title="View details">
                        <Eye size={13} />
                      </button>
                    </td>

                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* ── PAGINATION ── */}
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

      {/* ── DETAILS MODAL ── */}
      {selectedLog && (
        <div className="overlay-dl" onClick={(e) => { if (e.target === e.currentTarget) setSelectedLog(null); }}>
          <div className="modal-dl">

            <div style={{
              padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`,
              display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexShrink: 0,
            }}>
              <div>
                <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.18em",
                  textTransform: "uppercase", margin: "0 0 4px" }}>Dispatch Log</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Log Details</p>
                <p style={{ fontSize: 12, color: "#64748b", margin: "3px 0 0" }}>
                  Assignment event · {fmtTs(selectedLog.timestamp)}
                </p>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap", justifyContent: "flex-end" }}>
                <DecisionPill decision={selectedLog.decision} size="lg" />
                {selectedLog.booking_status_at_log && (
                  <BookingStatusPill status={selectedLog.booking_status_at_log} />
                )}
                <button className="dl-btn-ghost" onClick={() => setSelectedLog(null)}>
                  <X size={14} />
                </button>
              </div>
            </div>

            <div className="modal-dl-body">
              <div
                className="dl-modal-grid"
                style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20, padding: 24 }}
              >

                {/* ── LEFT ── */}
                <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>

                  <section>
                    <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                      letterSpacing: "0.14em", margin: "0 0 10px" }}>Assignment Info</p>
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                      <InfoChip label="Driver"       value={selectedLog.assigned_driver_name} />
                      <InfoChip label="Driver Email"  value={selectedLog.assigned_driver_email} />
                      <InfoChip label="Truck Type"    value={fmtTruckType(selectedLog.assigned_truck_type)} />
                      <InfoChip label="Plate No."     value={selectedLog.assigned_truck_plate_number} />
                      <InfoChip label="Booking ID"    value={selectedLog.booking_id} mono />
                      <InfoChip label="Assigned At"   value={fmtTs(selectedLog.timestamp)} />
                    </div>
                  </section>

                  {selectedLog.booking && (
                    <section>
                      <p style={{ fontSize: 10, color: "#60a5fa", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 10px" }}>Linked Booking</p>
                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                        <InfoChip label="Customer" value={selectedLog.booking.customerName} />
                        <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 10, padding: "12px 14px" }}>
                          <p style={{ fontSize: 10, color: "#475569", fontWeight: 700, textTransform: "uppercase",
                            letterSpacing: "0.07em", margin: "0 0 6px" }}>Status</p>
                          {selectedLog.booking_status_at_log
                            ? <BookingStatusPill status={selectedLog.booking_status_at_log} />
                            : <span style={{ fontSize: 13, color: "#334155" }}>—</span>}
                        </div>
                        <InfoChip label="Est. Cost" value={fmtCost(selectedLog.booking.estimatedCost)} />
                        <InfoChip label="Distance"  value={fmtDistance(selectedLog.booking.estimatedDistance)} />
                      </div>
                    </section>
                  )}

                  <section>
                    <p style={{ fontSize: 10, color: "#334155", fontWeight: 700, textTransform: "uppercase",
                      letterSpacing: "0.14em", margin: "0 0 10px" }}>Technical IDs</p>
                    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
                      <InfoChip label="Driver ID" value={selectedLog.assigned_driver_id} mono />
                      <InfoChip label="Truck ID"  value={selectedLog.assigned_truck_id} mono />
                    </div>
                  </section>

                </div>

                {/* ── RIGHT ── */}
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>

                  {selectedLog.booking && (
                    <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                      <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 12px" }}>Route</p>
                      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                        <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                          <span style={{ marginTop: 4, width: 8, height: 8, borderRadius: "50%", background: "#4ade80", flexShrink: 0 }} />
                          <div>
                            <p className="field-label-dl" style={{ margin: "0 0 2px" }}>Pickup</p>
                            <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                              {selectedLog.booking.pickupLocation || "-"}
                            </p>
                          </div>
                        </div>
                        <div style={{ marginLeft: 3, borderLeft: "2px dashed rgba(255,255,255,0.07)", height: 12 }} />
                        <div style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                          <span style={{ marginTop: 4, width: 8, height: 8, borderRadius: "50%", background: "#f87171", flexShrink: 0 }} />
                          <div>
                            <p className="field-label-dl" style={{ margin: "0 0 2px" }}>Destination</p>
                            <p style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", margin: 0 }}>
                              {selectedLog.booking.destination || "-"}
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {selectedLog.booking?.notes && (
                    <div style={{
                      background: "rgba(251,191,36,0.05)", border: "1px solid rgba(251,191,36,0.15)",
                      borderRadius: 12, padding: "14px 16px",
                    }}>
                      <p style={{ fontSize: 10, color: "#fbbf24", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 6px" }}>Customer Notes</p>
                      <p style={{ fontSize: 12, color: "#fde68a", margin: 0, fontStyle: "italic" }}>
                        "{selectedLog.booking.notes}"
                      </p>
                    </div>
                  )}

                  {(selectedLog.decision || "").toLowerCase() === "reassigned" && (
                    <div style={{
                      background: "rgba(251,191,36,0.05)", border: "1px solid rgba(251,191,36,0.15)",
                      borderRadius: 12, padding: "12px 14px", display: "flex", alignItems: "center", gap: 10,
                    }}>
                      <RefreshCw size={14} style={{ color: "#fbbf24", flexShrink: 0 }} />
                      <p style={{ fontSize: 12, color: "#fde68a", margin: 0 }}>
                        This booking was previously assigned to another driver and then reassigned.
                      </p>
                    </div>
                  )}

                  {getTimeline(selectedLog).length > 0 && (
                    <div style={{ background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12, padding: "14px 16px" }}>
                      <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, textTransform: "uppercase",
                        letterSpacing: "0.14em", margin: "0 0 14px" }}>Delivery Timeline</p>
                      <div style={{ position: "relative" }}>
                        {getTimeline(selectedLog).map((t, i, arr) => (
                          <div key={i} style={{ display: "flex", alignItems: "flex-start", gap: 12, position: "relative" }}>
                            {i < arr.length - 1 && (
                              <div style={{ position: "absolute", left: 6, top: 16, width: 1,
                                height: "100%", background: BORDER }} />
                            )}
                            <div style={{
                              marginTop: 3, width: 13, height: 13, borderRadius: "50%",
                              background: G_DIM, border: `2px solid #4ade80`, flexShrink: 0, zIndex: 1,
                            }} />
                            <div style={{ paddingBottom: 16 }}>
                              <p style={{ fontSize: 12, fontWeight: 600, color: "#cbd5e1", margin: 0 }}>{t.label}</p>
                              <p style={{ fontSize: 11, color: "#475569", margin: "2px 0 0" }}>{fmtTs(t.ts)}</p>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {!selectedLog.booking && (
                    <div style={{
                      background: CARD2, border: `1px solid ${BORDER}`, borderRadius: 12,
                      padding: "24px 16px", textAlign: "center",
                    }}>
                      <AlertCircle size={20} style={{ color: "#334155", marginBottom: 8 }} />
                      <p style={{ fontSize: 12, color: "#475569", margin: 0 }}>No linked booking found</p>
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