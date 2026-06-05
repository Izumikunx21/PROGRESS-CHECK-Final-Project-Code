import React, { useState, useMemo } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { collection, doc, addDoc, updateDoc, deleteDoc } from "firebase/firestore";
import { db } from "@/firebase/config";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import {
  Plus, Pencil, Trash2, Phone, Mail, User, X, Truck,
  CalendarOff, UserX, RotateCcw, BriefcaseMedical,
} from "lucide-react";

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

const INITIAL_FORM = {
  fullName:         "",
  email:            "",
  phone:            "",
  licenseNumber:    "",
  address:          "",
  emergencyContact: "",
};

const INITIAL_LEAVE_FORM = {
  leaveReason:  "",
  leaveFrom:    "",
  leaveUntil:   "",
};

const STATUS_META = {
  active:     { label: "Available", color: "#4ade80", bg: "rgba(74,222,128,0.1)",  border: "rgba(74,222,128,0.25)"  },
  available:  { label: "Available", color: "#4ade80", bg: "rgba(74,222,128,0.1)",  border: "rgba(74,222,128,0.25)"  }, // ← ADD
  on_trip:    { label: "On Trip",   color: "#fbbf24", bg: "rgba(251,191,36,0.1)",  border: "rgba(251,191,36,0.25)"  },
  on_leave:   { label: "On Leave",  color: "#fb923c", bg: "rgba(251,146,60,0.1)",  border: "rgba(251,146,60,0.25)"  },
  inactive:   { label: "Inactive",  color: "#94a3b8", bg: "rgba(148,163,184,0.1)", border: "rgba(148,163,184,0.25)" },
  blocked:    { label: "Blocked",   color: "#f87171", bg: "rgba(248,113,113,0.1)", border: "rgba(248,113,113,0.25)" },
};

const LEAVE_REASONS = [
  { value: "sick",     label: "Sick Leave" },
  { value: "vacation", label: "Vacation" },
  { value: "personal", label: "Personal Leave" },
  { value: "family",   label: "Family Emergency" },
  { value: "other",    label: "Other" },
];

const fmtType = (type) => {
  if (!type) return "";
  return type.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
};

const fmtDate = (dateStr) => {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  return d.toLocaleDateString("en-PH", { month: "short", day: "numeric", year: "numeric" });
};

export default function AdminDrivers() {
  const [showForm,        setShowForm]        = useState(false);
  const [editingDriver,   setEditingDriver]   = useState(null);
  const [form,            setForm]            = useState(INITIAL_FORM);
  const [statusFilter,    setStatusFilter]    = useState("all");

  /* ── leave modal ── */
  const [showLeaveModal,  setShowLeaveModal]  = useState(false);
  const [leaveTarget,     setLeaveTarget]     = useState(null);
  const [leaveForm,       setLeaveForm]       = useState(INITIAL_LEAVE_FORM);

  /* ── inactive confirm ── */
  const [showInactiveModal, setShowInactiveModal] = useState(false);
  const [inactiveTarget,    setInactiveTarget]    = useState(null);

  const qc = useQueryClient();

  const { data: users  = [], loading } = useFirestoreCollection("users");
  const { data: trucks = []          } = useFirestoreCollection("trucks");

  const drivers = useMemo(() =>
    users.filter((u) => u.role === "driver"),
    [users]
  );

  const getDriverTruck = (driverId) =>
    trucks.find((t) => t.driver_id === driverId) || null;

  /* ── mutations ── */
  const createMutation = useMutation({
    mutationFn: async (data) => {
      await addDoc(collection(db, "users"), {
        ...data,
        role:               "driver",
        status:             "active",
        availability:       "available",
        current_location:   { lat: 0, lng: 0 },
        current_booking_id: null,
        assigned_truck_id:    null,
        assigned_truck_plate: "",
        assigned_truck_type:  "",
      });
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); closeForm(); },
  });

  const updateMutation = useMutation({
    mutationFn: async ({ id, data }) => {
      await updateDoc(doc(db, "users", id), {
        fullName:         data.fullName,
        email:            data.email,
        phone:            data.phone,
        licenseNumber:    data.licenseNumber,
        address:          data.address,
        emergencyContact: data.emergencyContact,
      });
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); closeForm(); },
  });

  const deleteMutation = useMutation({
    mutationFn: async (driver) => {
      await deleteDoc(doc(db, "users", driver.id));
      const truck = getDriverTruck(driver.id);
      if (truck) {
        await updateDoc(doc(db, "trucks", truck.id), { driver_id: "", driver_name: "" });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      qc.invalidateQueries({ queryKey: ["trucks"] });
    },
  });

  /* ── set on leave ── */
  const leaveMutation = useMutation({
    mutationFn: async ({ id, data }) => {
      await updateDoc(doc(db, "users", id), {
        status:      "on_leave",
        leaveReason: data.leaveReason,
        leaveFrom:   data.leaveFrom,
        leaveUntil:  data.leaveUntil,
        leaveSetAt:  new Date().toISOString(),
        leaveSetBy:  "admin",
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      closeLeaveModal();
    },
  });

  /* ── set inactive ── */
  const inactiveMutation = useMutation({
    mutationFn: async (id) => {
      await updateDoc(doc(db, "users", id), {
        status:         "inactive",
        inactiveSince:  new Date().toISOString(),
        inactiveSetBy:  "admin",
        /* clear leave fields if any */
        leaveReason:    null,
        leaveFrom:      null,
        leaveUntil:     null,
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      closeInactiveModal();
    },
  });

  /* ── restore to active ── */
  const restoreMutation = useMutation({
    mutationFn: async (id) => {
      await updateDoc(doc(db, "users", id), {
        status:        "available", // ← was "active"
        leaveReason:   null,
        leaveFrom:     null,
        leaveUntil:    null,
        leaveSetAt:    null,
        leaveSetBy:    null,
        inactiveSince: null,
        inactiveSetBy: null,
      });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["users"] }),
  });

  /* ── helpers ── */
  const handleSubmit = (e) => {
    e.preventDefault();
    editingDriver
      ? updateMutation.mutate({ id: editingDriver.id, data: form })
      : createMutation.mutate(form);
  };

  const openEdit = (driver) => {
    setEditingDriver(driver);
    setForm({
      fullName:         driver.fullName         || "",
      email:            driver.email            || "",
      phone:            driver.phone            || "",
      licenseNumber:    driver.licenseNumber    || "",
      address:          driver.address          || "",
      emergencyContact: driver.emergencyContact || "",
    });
    setShowForm(true);
  };

  const openAdd = () => { setEditingDriver(null); setForm(INITIAL_FORM); setShowForm(true); };
  const closeForm = () => { setShowForm(false); setEditingDriver(null); setForm(INITIAL_FORM); };

  const openLeaveModal = (driver) => {
    setLeaveTarget(driver);
    setLeaveForm({
      leaveReason: driver.leaveReason || "",
      leaveFrom:   driver.leaveFrom   || new Date().toISOString().slice(0, 10),
      leaveUntil:  driver.leaveUntil  || "",
    });
    setShowLeaveModal(true);
  };
  const closeLeaveModal = () => { setShowLeaveModal(false); setLeaveTarget(null); setLeaveForm(INITIAL_LEAVE_FORM); };

  const openInactiveModal = (driver) => { setInactiveTarget(driver); setShowInactiveModal(true); };
  const closeInactiveModal = () => { setShowInactiveModal(false); setInactiveTarget(null); };

  const confirmDelete = (driver) => {
    const truck = getDriverTruck(driver.id);
    const truckWarning = truck ? `\n\nThis will also unlink truck ${truck.plate_number}.` : "";
    if (window.confirm(`Delete driver ${driver.fullName || driver.email}?${truckWarning}\n\nThis cannot be undone.`))
      deleteMutation.mutate(driver);
  };

  const isBusy = createMutation.isPending || updateMutation.isPending;

  const filtered = useMemo(() =>
    drivers.filter((d) => {
      if (statusFilter === "all") return true;
      if (statusFilter === "active") return ["active", "available"].includes(d.status || "active");
      return (d.status || "active") === statusFilter;
    }),
    [drivers, statusFilter]
  );

  const filterTabs = [
    ["all",      "All"      ],
    ["active",   "Available"],
    ["on_trip",  "On Trip"  ],
    ["on_leave", "On Leave" ],
    ["inactive", "Inactive" ],
    ["blocked",  "Blocked"  ],
  ];

  /* ── which action buttons to show per status ── */
  const getStatusActions = (driver) => {
    const s = driver.status || "active";
    const isActive   = s === "active" || s === "available"; // ← ADD available
    const canRestore  = s === "on_leave" || s === "inactive";
    const canLeave    = isActive || s === "on_trip";        // ← use isActive
    const canInactive = !["inactive", "blocked", "on_trip"].includes(s);
    return { canRestore, canLeave, canInactive };
  };

  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .dr * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .dr h1 { font-family:'Sora',sans-serif; }
        .dr-input { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; transition:border-color 0.18s;
          font-family:'DM Sans',sans-serif; }
        .dr-input:focus { border-color:rgba(22,163,74,0.5); }
        .dr-input::placeholder { color:#475569; }
        .dr-btn-primary { display:flex; align-items:center; gap:7px; background:${G_DIM};
          border:1px solid ${G_BRD}; color:#4ade80; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .dr-btn-primary:hover { background:rgba(22,163,74,0.25); }
        .dr-btn-primary:disabled { opacity:0.6; cursor:not-allowed; }
        .dr-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:10px; padding:9px 18px; font-size:13px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .dr-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .dr-btn-icon { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .dr-btn-icon:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .dr-btn-del { background:rgba(239,68,68,0.08); border:1px solid rgba(239,68,68,0.2);
          color:#f87171; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .dr-btn-del:hover { background:rgba(239,68,68,0.15); }
        .dr-btn-leave { background:rgba(251,146,60,0.08); border:1px solid rgba(251,146,60,0.2);
          color:#fb923c; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .dr-btn-leave:hover { background:rgba(251,146,60,0.15); }
        .dr-btn-inactive { background:rgba(148,163,184,0.08); border:1px solid rgba(148,163,184,0.2);
          color:#94a3b8; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .dr-btn-inactive:hover { background:rgba(148,163,184,0.15); }
        .dr-btn-restore { background:rgba(74,222,128,0.08); border:1px solid rgba(74,222,128,0.2);
          color:#4ade80; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .dr-btn-restore:hover { background:rgba(74,222,128,0.15); }
        .dr-btn-danger { display:flex; align-items:center; gap:7px; background:rgba(239,68,68,0.12);
          border:1px solid rgba(239,68,68,0.3); color:#f87171; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .dr-btn-danger:hover { background:rgba(239,68,68,0.2); }
        .dr-btn-orange { display:flex; align-items:center; gap:7px; background:rgba(251,146,60,0.15);
          border:1px solid rgba(251,146,60,0.35); color:#fb923c; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .dr-btn-orange:hover { background:rgba(251,146,60,0.25); }
        .dr-btn-orange:disabled { opacity:0.6; cursor:not-allowed; }
        .filt-dr { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 14px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .filt-dr:hover { color:#cbd5e1; }
        .filt-dr.on { background:${G_DIM}; border-color:${G_BRD}; color:#4ade80; }
        .dr-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px;
          padding:20px; transition:border-color 0.18s; }
        .dr-card:hover { border-color:rgba(255,255,255,0.12); }
        .overlay-dr { position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:50;
          display:flex; align-items:center; justify-content:center; padding:24px; }
        .modal-dr { background:#111827; border:1px solid ${BORDER}; border-radius:20px;
          width:100%; max-width:560px; overflow:hidden; box-shadow:0 24px 64px rgba(0,0,0,0.5);
          max-height:90vh; overflow-y:auto; }
        .modal-sm { max-width:440px; }
        .field-label-dr { font-size:12px; color:#94a3b8; font-weight:600;
          text-transform:uppercase; letter-spacing:0.07em; display:block; margin-bottom:8px; }
        .dr-select { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; cursor:pointer;
          font-family:'DM Sans',sans-serif; appearance:none; }
        .dr-select:focus { border-color:rgba(22,163,74,0.5); }
        .dr-select option { background:#1e293b; }
        @media(max-width:900px){ .dr-grid{ grid-template-columns:1fr 1fr !important; } }
        @media(max-width:580px){ .dr-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="dr" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ── HEADER ── */}
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>Driver Management</h1>
            <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>
              Manage registered drivers and their assigned trucks
            </p>
          </div>
          <button className="dr-btn-primary" onClick={openAdd}>
            <Plus size={14} /> Add Driver
          </button>
        </div>

        {/* ── FILTER TABS ── */}
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {filterTabs.map(([val, label]) => (
            <button
              key={val}
              className={`filt-dr${statusFilter === val ? " on" : ""}`}
              onClick={() => setStatusFilter(val)}
            >
              {label}
              <span style={{ marginLeft: 6, fontSize: 11, opacity: 0.7 }}>
                {val === "all"
                  ? drivers.length
                  : val === "active"
                    ? drivers.filter((d) => ["active", "available"].includes(d.status || "active")).length
                    : drivers.filter((d) => (d.status || "active") === val).length}
              </span>
            </button>
          ))}
        </div>

        {/* ── LOADING ── */}
        {loading && <p style={{ color: "#475569", fontSize: 13 }}>Loading drivers…</p>}

        {/* ── GRID ── */}
        {!loading && filtered.length === 0 ? (
          <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, padding: "60px 24px", textAlign: "center" }}>
            <User size={32} style={{ color: "#334155", margin: "0 auto 12px" }} />
            <p style={{ color: "#475569", fontSize: 14, margin: 0 }}>No drivers found.</p>
          </div>
        ) : (
          <div className="dr-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 14 }}>
            {filtered.map((d) => {
              const meta  = STATUS_META[d.status || "active"] || STATUS_META.inactive;
              const truck = getDriverTruck(d.id);
              const { canRestore, canLeave, canInactive } = getStatusActions(d);

              return (
                <div key={d.id} className="dr-card">

                  {/* top row — avatar + status */}
                  <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 14 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 11, flexShrink: 0,
                      background: G_DIM, border: `1px solid ${G_BRD}`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 16, fontWeight: 700, color: "#4ade80", overflow: "hidden",
                    }}>
                      {d.profileImage
                        ? <img src={d.profileImage} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                        : (d.fullName?.[0]?.toUpperCase() ?? <User size={18} style={{ color: "#4ade80" }} />)}
                    </div>
                    <span style={{
                      fontSize: 11, fontWeight: 700, color: meta.color,
                      background: meta.bg, border: `1px solid ${meta.border}`,
                      borderRadius: 6, padding: "3px 10px",
                      display: "flex", alignItems: "center", gap: 5,
                    }}>
                      <span style={{ width: 6, height: 6, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
                      {meta.label}
                    </span>
                  </div>

                  {/* name */}
                  <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: "0 0 2px" }}>
                    {d.fullName || "—"}
                  </p>

                  {/* contact */}
                  <div style={{ display: "flex", flexDirection: "column", gap: 4, marginTop: 6, marginBottom: 12 }}>
                    <p style={{ fontSize: 12, color: "#64748b", margin: 0, display: "flex", alignItems: "center", gap: 6 }}>
                      <Mail size={12} style={{ flexShrink: 0 }} /> {d.email}
                    </p>
                    {d.phone && (
                      <p style={{ fontSize: 12, color: "#64748b", margin: 0, display: "flex", alignItems: "center", gap: 6 }}>
                        <Phone size={12} style={{ flexShrink: 0 }} /> {d.phone}
                      </p>
                    )}
                  </div>

                  {/* on leave info banner */}
                  {d.status === "on_leave" && (
                    <div style={{
                      background: "rgba(251,146,60,0.07)", border: "1px solid rgba(251,146,60,0.2)",
                      borderRadius: 8, padding: "8px 12px", marginBottom: 12,
                    }}>
                      <p style={{ fontSize: 10, color: "#fb923c", margin: "0 0 3px", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.06em" }}>
                        On Leave
                      </p>
                      <p style={{ fontSize: 12, color: "#fed7aa", margin: 0 }}>
                        {LEAVE_REASONS.find(r => r.value === d.leaveReason)?.label || d.leaveReason || "—"}
                      </p>
                      {d.leaveUntil && (
                        <p style={{ fontSize: 11, color: "#94a3b8", margin: "3px 0 0" }}>
                          Returns: {fmtDate(d.leaveUntil)}
                        </p>
                      )}
                    </div>
                  )}

                  {/* inactive info banner */}
                  {d.status === "inactive" && (
                    <div style={{
                      background: "rgba(148,163,184,0.06)", border: "1px solid rgba(148,163,184,0.15)",
                      borderRadius: 8, padding: "8px 12px", marginBottom: 12,
                    }}>
                      <p style={{ fontSize: 11, color: "#64748b", margin: 0 }}>
                        Deactivated {d.inactiveSince ? `on ${fmtDate(d.inactiveSince)}` : ""}
                      </p>
                    </div>
                  )}

                  {/* assigned truck */}
                  <div style={{
                    background: CARD2, borderRadius: 8, padding: "8px 12px", marginBottom: 12,
                    border: `1px solid ${truck ? G_BRD : BORDER}`,
                  }}>
                    <p style={{ fontSize: 10, color: "#475569", margin: "0 0 4px", textTransform: "uppercase", letterSpacing: "0.06em", fontWeight: 600 }}>
                      Assigned Truck
                    </p>
                    {truck ? (
                      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                        <Truck size={13} style={{ color: "#4ade80", flexShrink: 0 }} />
                        <div>
                          <p style={{ fontSize: 13, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>{truck.plate_number}</p>
                          <p style={{ fontSize: 11, color: "#64748b", margin: "1px 0 0" }}>
                            {fmtType(truck.truck_type)} {truck.model ? `· ${truck.model}` : ""}
                          </p>
                        </div>
                      </div>
                    ) : (
                      <p style={{ fontSize: 12, color: "#475569", margin: 0, fontStyle: "italic" }}>No truck assigned yet</p>
                    )}
                  </div>

                  {/* license */}
                  {d.licenseNumber && (
                    <div style={{ background: CARD2, borderRadius: 8, padding: "8px 12px", marginBottom: 12 }}>
                      <p style={{ fontSize: 10, color: "#475569", margin: "0 0 2px", textTransform: "uppercase", letterSpacing: "0.06em", fontWeight: 600 }}>License</p>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#cbd5e1", margin: 0 }}>{d.licenseNumber}</p>
                    </div>
                  )}

                  {/* actions */}
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                    <button className="dr-btn-icon" onClick={() => openEdit(d)}>
                      <Pencil size={12} /> Edit
                    </button>

                    {canRestore && (
                      <button className="dr-btn-restore" onClick={() => restoreMutation.mutate(d.id)}>
                        <RotateCcw size={12} /> Restore
                      </button>
                    )}

                    {canLeave && (
                      <button className="dr-btn-leave" onClick={() => openLeaveModal(d)}>
                        <BriefcaseMedical size={12} /> On Leave
                      </button>
                    )}

                    {canInactive && (
                      <button className="dr-btn-inactive" onClick={() => openInactiveModal(d)}>
                        <UserX size={12} /> Deactivate
                      </button>
                    )}

                    <button className="dr-btn-del" onClick={() => confirmDelete(d)}>
                      <Trash2 size={12} /> Delete
                    </button>
                  </div>

                </div>
              );
            })}
          </div>
        )}

      </div>

      {/* ── ADD / EDIT MODAL ── */}
      {(showForm || !!editingDriver) && (
        <div className="overlay-dr" onClick={(e) => { if (e.target === e.currentTarget) closeForm(); }}>
          <div className="modal-dr">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>Driver Management</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>
                  {editingDriver ? "Edit Driver Details" : "Add New Driver"}
                </p>
              </div>
              <button className="dr-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeForm}><X size={14} /></button>
            </div>

            {editingDriver && (() => {
              const truck = getDriverTruck(editingDriver.id);
              return truck ? (
                <div style={{ margin: "0 24px", marginTop: 20, background: G_DIM, border: `1px solid ${G_BRD}`, borderRadius: 10, padding: "10px 14px", display: "flex", alignItems: "center", gap: 10 }}>
                  <Truck size={14} style={{ color: "#4ade80", flexShrink: 0 }} />
                  <div>
                    <p style={{ fontSize: 11, color: "#4ade80", fontWeight: 700, margin: 0 }}>Assigned Truck — {truck.plate_number}</p>
                    <p style={{ fontSize: 11, color: "#64748b", margin: "2px 0 0" }}>
                      {fmtType(truck.truck_type)}{truck.model ? ` · ${truck.model}` : ""} · To reassign, go to Truck Management
                    </p>
                  </div>
                </div>
              ) : (
                <div style={{ margin: "0 24px", marginTop: 20, background: "rgba(251,191,36,0.06)", border: "1px solid rgba(251,191,36,0.2)", borderRadius: 10, padding: "10px 14px" }}>
                  <p style={{ fontSize: 11, color: "#fbbf24", margin: 0 }}>⚠️ No truck assigned — go to Truck Management to assign one</p>
                </div>
              );
            })()}

            <form onSubmit={handleSubmit} style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div>
                  <label className="field-label-dr">Full Name *</label>
                  <input className="dr-input" placeholder="e.g. Juan Dela Cruz" value={form.fullName}
                    onChange={(e) => setForm({ ...form, fullName: e.target.value })} required />
                </div>
                <div>
                  <label className="field-label-dr">Email *</label>
                  <input className="dr-input" placeholder="e.g. juan@email.com" value={form.email}
                    onChange={(e) => setForm({ ...form, email: e.target.value })} required />
                </div>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div>
                  <label className="field-label-dr">Phone Number</label>
                  <input className="dr-input" placeholder="e.g. 09XX-XXX-XXXX" value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </div>
                <div>
                  <label className="field-label-dr">License Number</label>
                  <input className="dr-input" placeholder="e.g. N01-23-456789" value={form.licenseNumber}
                    onChange={(e) => setForm({ ...form, licenseNumber: e.target.value })} />
                </div>
              </div>
              <div>
                <label className="field-label-dr">Address</label>
                <input className="dr-input" placeholder="e.g. 123 Main St, Cebu City" value={form.address}
                  onChange={(e) => setForm({ ...form, address: e.target.value })} />
              </div>
              <div>
                <label className="field-label-dr">Emergency Contact</label>
                <input className="dr-input" placeholder="e.g. Maria Dela Cruz – 09XX-XXX-XXXX" value={form.emergencyContact}
                  onChange={(e) => setForm({ ...form, emergencyContact: e.target.value })} />
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 16, borderTop: `1px solid ${BORDER}` }}>
                <button type="button" className="dr-btn-ghost" onClick={closeForm}>Cancel</button>
                <button type="submit" className="dr-btn-primary" disabled={isBusy}>
                  {isBusy ? "Saving…" : editingDriver ? "Update Driver" : "Create Driver"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── ON LEAVE MODAL ── */}
      {showLeaveModal && leaveTarget && (
        <div className="overlay-dr" onClick={(e) => { if (e.target === e.currentTarget) closeLeaveModal(); }}>
          <div className="modal-dr modal-sm">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#fb923c", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>Driver Status</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0, display: "flex", alignItems: "center", gap: 8 }}>
                  <CalendarOff size={16} style={{ color: "#fb923c" }} /> Set On Leave
                </p>
              </div>
              <button className="dr-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeLeaveModal}><X size={14} /></button>
            </div>

            <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>
              <div style={{ background: "rgba(251,146,60,0.06)", border: "1px solid rgba(251,146,60,0.2)", borderRadius: 10, padding: "10px 14px" }}>
                <p style={{ fontSize: 13, color: "#fed7aa", margin: 0 }}>
                  <strong style={{ color: "#fb923c" }}>{leaveTarget.fullName || leaveTarget.email}</strong> will be marked as On Leave and won't receive job assignments.
                </p>
              </div>

              <div>
                <label className="field-label-dr">Reason *</label>
                <select className="dr-select" value={leaveForm.leaveReason} onChange={(e) => setLeaveForm({ ...leaveForm, leaveReason: e.target.value })}>
                  <option value="">Select a reason</option>
                  {LEAVE_REASONS.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
                </select>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div>
                  <label className="field-label-dr">From</label>
                  <input className="dr-input" type="date" value={leaveForm.leaveFrom}
                    onChange={(e) => setLeaveForm({ ...leaveForm, leaveFrom: e.target.value })} />
                </div>
                <div>
                  <label className="field-label-dr">Expected Return</label>
                  <input className="dr-input" type="date" value={leaveForm.leaveUntil}
                    onChange={(e) => setLeaveForm({ ...leaveForm, leaveUntil: e.target.value })} />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 16, borderTop: `1px solid ${BORDER}` }}>
                <button type="button" className="dr-btn-ghost" onClick={closeLeaveModal}>Cancel</button>
                <button
                  className="dr-btn-orange"
                  disabled={!leaveForm.leaveReason || leaveMutation.isPending}
                  onClick={() => leaveMutation.mutate({ id: leaveTarget.id, data: leaveForm })}
                >
                  <CalendarOff size={13} />
                  {leaveMutation.isPending ? "Saving…" : "Confirm Leave"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── DEACTIVATE CONFIRM MODAL ── */}
      {showInactiveModal && inactiveTarget && (
        <div className="overlay-dr" onClick={(e) => { if (e.target === e.currentTarget) closeInactiveModal(); }}>
          <div className="modal-dr modal-sm">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#94a3b8", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>Driver Status</p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0, display: "flex", alignItems: "center", gap: 8 }}>
                  <UserX size={16} style={{ color: "#94a3b8" }} /> Deactivate Driver
                </p>
              </div>
              <button className="dr-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeInactiveModal}><X size={14} /></button>
            </div>

            <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>
              <div style={{ background: "rgba(148,163,184,0.06)", border: "1px solid rgba(148,163,184,0.15)", borderRadius: 10, padding: "12px 14px" }}>
                <p style={{ fontSize: 13, color: "#cbd5e1", margin: "0 0 8px" }}>
                  <strong style={{ color: "#f1f5f9" }}>{inactiveTarget.fullName || inactiveTarget.email}</strong> will be marked as Inactive.
                </p>
                <ul style={{ margin: 0, padding: "0 0 0 16px", display: "flex", flexDirection: "column", gap: 4 }}>
                  <li style={{ fontSize: 12, color: "#64748b" }}>Driver won't receive new job assignments</li>
                  <li style={{ fontSize: 12, color: "#64748b" }}>All trip history and records are preserved</li>
                  <li style={{ fontSize: 12, color: "#64748b" }}>Can be restored to Active at any time</li>
                </ul>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 4 }}>
                <button type="button" className="dr-btn-ghost" onClick={closeInactiveModal}>Cancel</button>
                <button
                  className="dr-btn-inactive"
                  style={{ padding: "9px 18px", borderRadius: 10, fontSize: 13, fontWeight: 600 }}
                  disabled={inactiveMutation.isPending}
                  onClick={() => inactiveMutation.mutate(inactiveTarget.id)}
                >
                  <UserX size={13} />
                  {inactiveMutation.isPending ? "Saving…" : "Deactivate Driver"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}