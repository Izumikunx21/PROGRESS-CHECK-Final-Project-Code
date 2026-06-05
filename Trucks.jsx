import React, { useState, useMemo } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { collection, doc, updateDoc, addDoc, deleteDoc } from "firebase/firestore";
import { db } from "@/firebase/config";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import { Plus, Pencil, Trash2, Truck, X, User, Wrench, CheckCircle } from "lucide-react";

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

const INITIAL_FORM = {
  plate_number: "",
  truck_type: "",
  custom_truck_type: "",
  model: "",
  driver_id: "",
};

const fmtType = (type) => {
  if (!type) return "";
  return type.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
};

const STATUS_META = {
  available:   { label: "Available",   color: "#4ade80", bg: "rgba(74,222,128,0.1)",  border: "rgba(74,222,128,0.25)"  },
  reserved:    { label: "Reserved",    color: "#60a5fa", bg: "rgba(96,165,250,0.1)",  border: "rgba(96,165,250,0.25)"  },
  in_use:      { label: "In Use",      color: "#fbbf24", bg: "rgba(251,191,36,0.1)",  border: "rgba(251,191,36,0.25)"  },
  maintenance: { label: "Maintenance", color: "#f87171", bg: "rgba(248,113,113,0.1)", border: "rgba(248,113,113,0.25)" },
};

const TRUCK_TYPES = [
  { value: "flat_bed",      label: "Flatbed"      },
  { value: "closed_van",    label: "Closed Van"   },
  { value: "wing_van",      label: "Wing Van"     },
  { value: "open_truck",    label: "Open Truck"   },
  { value: "6w_fwd_truck",  label: "6W Fwd Truck" },
  { value: "custom",        label: "Custom Type"  },
];

/* ── Statuses where a truck CANNOT be deleted ── */
const UNDELETABLE = ["maintenance", "in_use", "reserved"];

/* ── Statuses where maintenance toggle is blocked ── */
const MAINTENANCE_BLOCKED = ["in_use", "reserved"];

export default function AdminTrucks() {
  const qc = useQueryClient();

  const { data: trucks = [], loading } = useFirestoreCollection("trucks");
  const { data: users  = []          } = useFirestoreCollection("users");

  const [showForm,     setShowForm]     = useState(false);
  const [editing,      setEditing]      = useState(null);
  const [form,         setForm]         = useState(INITIAL_FORM);
  const [statusFilter, setStatusFilter] = useState("all");
  const [err,          setErr]          = useState({});

  /* ── only drivers ── */
  const drivers = useMemo(() => users.filter(u => u.role === "driver"), [users]);

  const takenDriverIds = useMemo(() =>
    trucks
      .filter(t => t.driver_id && (!editing || t.id !== editing.id))
      .map(t => t.driver_id),
    [trucks, editing]
  );

  const availableDrivers = useMemo(() =>
    drivers.filter(d => !takenDriverIds.includes(d.id)),
    [drivers, takenDriverIds]
  );

  /* ── helpers ── */
  const closeForm = () => {
    setShowForm(false);
    setEditing(null);
    setForm(INITIAL_FORM);
    setErr({});
  };

  const openAdd = () => {
    setEditing(null);
    setForm(INITIAL_FORM);
    setShowForm(true);
  };

  const openEdit = (t) => {
    setEditing(t);
    setForm({
      plate_number:      t.plate_number      || "",
      truck_type:        t.truck_type        || "",
      custom_truck_type: t.custom_truck_type || "",
      model:             t.model             || "",
      driver_id:         t.driver_id         || "",
    });
    setShowForm(true);
  };

  /* ── validation ── */
  const validate = () => {
    const e = {};
    if (!form.plate_number.trim())
      e.plate_number = "Plate number is required";
    if (!form.truck_type)
      e.truck_type = "Truck type is required";
    if (form.truck_type === "custom" && !form.custom_truck_type.trim())
      e.custom_truck_type = "Enter a custom truck type";
    const dup = trucks.find(t => {
      if (editing?.id && t.id === editing.id) return false;
      return t.plate_number.trim().toLowerCase() === form.plate_number.trim().toLowerCase();
    });
    if (dup) e.plate_number = "Plate number already exists";
    setErr(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;

    const finalType = form.truck_type === "custom"
      ? form.custom_truck_type.toLowerCase().trim().replace(/\s+/g, "_")
      : form.truck_type;

    const selectedDriver = drivers.find(d => d.id === form.driver_id);

    const truckPayload = {
      plate_number: form.plate_number.trim(),
      truck_type:   finalType,
      model:        form.model.trim(),
      driver_id:    form.driver_id || "",
      driver_name:  selectedDriver?.fullName || selectedDriver?.name || "",
    };

    const driverPayload = {
      assigned_truck_id:    null,
      assigned_truck_plate: form.plate_number.trim(),
      assigned_truck_type:  finalType,
    };

    editing?.id
      ? updateMutation.mutate({ id: editing.id, truckPayload, driverPayload, selectedDriver, previousDriverId: editing.driver_id })
      : createMutation.mutate({ truckPayload, driverPayload, selectedDriver });
  };

  /* ── mutations ── */

  const createMutation = useMutation({
    mutationFn: async ({ truckPayload, driverPayload, selectedDriver }) => {
      const truckRef = await addDoc(collection(db, "trucks"), {
        ...truckPayload,
        status: "available",
        current_booking_id: null,
      });
      if (selectedDriver) {
        await updateDoc(doc(db, "users", selectedDriver.id), {
          ...driverPayload,
          assigned_truck_id: truckRef.id,
        });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trucks"] });
      qc.invalidateQueries({ queryKey: ["users"] });
      closeForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: async ({ id, truckPayload, driverPayload, selectedDriver, previousDriverId }) => {
      const driverChanged = previousDriverId !== truckPayload.driver_id;
      await updateDoc(doc(db, "trucks", id), truckPayload);
      if (driverChanged && previousDriverId) {
        await updateDoc(doc(db, "users", previousDriverId), {
          assigned_truck_id:    null,
          assigned_truck_plate: "",
          assigned_truck_type:  "",
        });
      }
      if (selectedDriver) {
        await updateDoc(doc(db, "users", selectedDriver.id), {
          ...driverPayload,
          assigned_truck_id: id,
        });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trucks"] });
      qc.invalidateQueries({ queryKey: ["users"] });
      closeForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (truck) => {
      await deleteDoc(doc(db, "trucks", truck.id));
      if (truck.driver_id) {
        await updateDoc(doc(db, "users", truck.driver_id), {
          assigned_truck_id:    null,
          assigned_truck_plate: "",
          assigned_truck_type:  "",
        });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trucks"] });
      qc.invalidateQueries({ queryKey: ["users"] });
    },
  });

  /* ─────────────────────────────────────────────────────────
     MAINTENANCE TOGGLE MUTATION
     Mark as Maintenance:
       - Sets truck status → "maintenance"
       - Sets driver status → "on_leave" (removes them from dispatch pool)
     Mark as Available:
       - Sets truck status → "available"
       - Sets driver status → "available" (returns them to dispatch pool)
  ───────────────────────────────────────────────────────── */
  const maintenanceMutation = useMutation({
    mutationFn: async (truck) => {
      const goingToMaintenance = truck.status !== "maintenance";

      // Safety check — block if truck has an active booking
      if (goingToMaintenance && truck.current_booking_id) {
        throw new Error(
          `Truck ${truck.plate_number} has an active booking (ID: ${truck.current_booking_id}). ` +
          `Resolve or reassign the booking before marking this truck as under maintenance.`
        );
      }

      // 1. Update truck status
      await updateDoc(doc(db, "trucks", truck.id), {
        status: goingToMaintenance ? "maintenance" : "available",
      });

      // 2. Update assigned driver's status if they exist
      if (truck.driver_id) {
        await updateDoc(doc(db, "users", truck.driver_id), {
          status: goingToMaintenance ? "on_leave" : "available",
        });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trucks"] });
      qc.invalidateQueries({ queryKey: ["users"] });
    },
    onError: (err) => {
      alert(err.message || "Failed to update maintenance status.");
    },
  });

  const isBusy = createMutation.isPending || updateMutation.isPending;

  const filtered = trucks.filter(t => statusFilter === "all" || t.status === statusFilter);

  const filterTabs = [
    ["all",         "All"        ],
    ["available",   "Available"  ],
    ["reserved",    "Reserved"   ],
    ["in_use",      "In Use"     ],
    ["maintenance", "Maintenance"],
  ];

  /* ── Delete guard ── */
  const handleDelete = (t) => {
    if (UNDELETABLE.includes(t.status)) {
      const reason = {
        maintenance: "This truck is currently under maintenance.",
        in_use:      "This truck is currently in use.",
        reserved:    "This truck has an active reservation.",
      }[t.status];
      alert(`Cannot delete truck ${t.plate_number}.\n\n${reason}\n\nResolve its status before deleting.`);
      return;
    }
    if (window.confirm(
      `Delete truck ${t.plate_number}?\n\nThis will also unlink the assigned driver.\n\nThis cannot be undone.`
    )) {
      deleteMutation.mutate(t);
    }
  };

  /* ── Maintenance toggle guard ── */
  const handleMaintenanceToggle = (t) => {
    if (MAINTENANCE_BLOCKED.includes(t.status)) {
      const reason = {
        in_use:   "This truck is currently in use on an active trip.",
        reserved: "This truck has an active reservation pending.",
      }[t.status];
      alert(`Cannot change status of truck ${t.plate_number}.\n\n${reason}`);
      return;
    }

    const goingToMaintenance = t.status !== "maintenance";
    const confirmMsg = goingToMaintenance
      ? `Mark truck ${t.plate_number} as Under Maintenance?\n\n` +
        `• Truck will be hidden from dispatch\n` +
        (t.driver_name ? `• Driver "${t.driver_name}" will be set to On Leave\n` : "") +
        `\nConfirm?`
      : `Mark truck ${t.plate_number} as Available?\n\n` +
        `• Truck will return to the dispatch pool\n` +
        (t.driver_name ? `• Driver "${t.driver_name}" will be set to Available\n` : "") +
        `\nConfirm?`;

    if (window.confirm(confirmMsg)) {
      maintenanceMutation.mutate(t);
    }
  };

  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .tr * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .tr h1 { font-family:'Sora',sans-serif; }
        .tr-input { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; transition:border-color 0.18s;
          font-family:'DM Sans',sans-serif; }
        .tr-input:focus { border-color:rgba(22,163,74,0.5); }
        .tr-input::placeholder { color:#475569; }
        .tr-input.err { border-color:rgba(239,68,68,0.5); }
        .tr-select { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; cursor:pointer;
          font-family:'DM Sans',sans-serif; appearance:none; }
        .tr-select:focus { border-color:rgba(22,163,74,0.5); }
        .tr-select.err { border-color:rgba(239,68,68,0.5); }
        .tr-select option { background:#1e293b; }
        .tr-btn-primary { display:flex; align-items:center; gap:7px; background:${G_DIM};
          border:1px solid ${G_BRD}; color:#4ade80; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .tr-btn-primary:hover { background:rgba(22,163,74,0.25); }
        .tr-btn-primary:disabled { opacity:0.6; cursor:not-allowed; }
        .tr-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:10px; padding:9px 18px; font-size:13px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .tr-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .tr-btn-icon { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tr-btn-icon:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .tr-btn-del { background:rgba(239,68,68,0.08); border:1px solid rgba(239,68,68,0.2);
          color:#f87171; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tr-btn-del:hover:not(:disabled) { background:rgba(239,68,68,0.15); }
        .tr-btn-del:disabled { opacity:0.35; cursor:not-allowed; }
        .tr-btn-maint { background:rgba(248,113,113,0.08); border:1px solid rgba(248,113,113,0.25);
          color:#f87171; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tr-btn-maint:hover:not(:disabled) { background:rgba(248,113,113,0.16); }
        .tr-btn-maint:disabled { opacity:0.35; cursor:not-allowed; }
        .tr-btn-restore { background:rgba(22,163,74,0.1); border:1px solid rgba(22,163,74,0.3);
          color:#4ade80; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tr-btn-restore:hover:not(:disabled) { background:rgba(22,163,74,0.2); }
        .tr-btn-restore:disabled { opacity:0.35; cursor:not-allowed; }
        .filt { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 14px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .filt:hover { color:#cbd5e1; }
        .filt.on { background:${G_DIM}; border-color:${G_BRD}; color:#4ade80; }
        .tr-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px;
          padding:20px; transition:border-color 0.18s; }
        .tr-card:hover { border-color:rgba(255,255,255,0.12); }
        .tr-card.maintenance-card { border-color:rgba(248,113,113,0.2); background:#120f0f; }
        .tr-card.maintenance-card:hover { border-color:rgba(248,113,113,0.35); }
        .overlay { position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:50;
          display:flex; align-items:center; justify-content:center; padding:24px; }
        .modal { background:#111827; border:1px solid ${BORDER}; border-radius:20px;
          width:100%; max-width:520px; overflow:hidden; box-shadow:0 24px 64px rgba(0,0,0,0.5);
          max-height:90vh; overflow-y:auto; }
        .errmsg { font-size:11px; color:#f87171; margin:4px 0 0; }
        .field-label { font-size:12px; color:#94a3b8; font-weight:600;
          text-transform:uppercase; letter-spacing:0.07em; display:block; margin-bottom:8px; }
        @media(max-width:900px){ .tr-grid{ grid-template-columns:1fr 1fr !important; } }
        @media(max-width:580px){ .tr-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="tr" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ── HEADER ── */}
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>Truck Management</h1>
            <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>
              Manage your fleet — each truck is permanently assigned to one driver
            </p>
          </div>
          <button className="tr-btn-primary" onClick={openAdd}>
            <Plus size={14} /> Add Truck
          </button>
        </div>

        {/* ── FILTER TABS ── */}
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {filterTabs.map(([val, label]) => (
            <button
              key={val}
              className={`filt${statusFilter === val ? " on" : ""}`}
              onClick={() => setStatusFilter(val)}
            >
              {label}
              <span style={{ marginLeft: 6, fontSize: 11, opacity: 0.7 }}>
                {val === "all" ? trucks.length : trucks.filter(t => t.status === val).length}
              </span>
            </button>
          ))}
        </div>

        {/* ── LOADING ── */}
        {loading && <p style={{ color: "#475569", fontSize: 13 }}>Loading trucks…</p>}

        {/* ── GRID ── */}
        {!loading && filtered.length === 0 ? (
          <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, padding: "60px 24px", textAlign: "center" }}>
            <Truck size={32} style={{ color: "#334155", margin: "0 auto 12px" }} />
            <p style={{ color: "#475569", fontSize: 14, margin: 0 }}>No trucks found.</p>
          </div>
        ) : (
          <div className="tr-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 14 }}>
            {filtered.map(t => {
              const meta = STATUS_META[t.status] || { label: t.status, color: "#94a3b8", bg: "rgba(255,255,255,0.05)", border: BORDER };
              const isUnderMaintenance = t.status === "maintenance";
              const isBlocked          = MAINTENANCE_BLOCKED.includes(t.status);
              const isUndeletable      = UNDELETABLE.includes(t.status);
              const isMaintPending     = maintenanceMutation.isPending;

              return (
                <div key={t.id} className={`tr-card${isUnderMaintenance ? " maintenance-card" : ""}`}>

                  {/* top row — icon + status */}
                  <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 14 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 11, flexShrink: 0,
                      background: isUnderMaintenance ? "rgba(248,113,113,0.12)" : G_DIM,
                      border: `1px solid ${isUnderMaintenance ? "rgba(248,113,113,0.3)" : G_BRD}`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                    }}>
                      {isUnderMaintenance
                        ? <Wrench size={18} style={{ color: "#f87171" }} />
                        : <Truck  size={18} style={{ color: "#4ade80" }} />
                      }
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

                  {/* plate + type + model */}
                  <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: "0 0 2px" }}>
                    {t.plate_number}
                  </p>
                  <p style={{ fontSize: 13, color: "#64748b", margin: "0 0 2px" }}>
                    {t.truck_type ? fmtType(t.truck_type) : "Type not specified"}
                  </p>
                  {t.model && (
                    <p style={{ fontSize: 12, color: "#475569", margin: "0 0 12px" }}>{t.model}</p>
                  )}

                  {/* maintenance warning banner — shown when truck has active booking */}
                  {isBlocked && (
                    <div style={{
                      background: "rgba(251,191,36,0.06)", border: "1px solid rgba(251,191,36,0.18)",
                      borderRadius: 8, padding: "7px 10px", marginBottom: 10,
                      display: "flex", alignItems: "center", gap: 6,
                    }}>
                      <span style={{ fontSize: 10, color: "#fbbf24", fontWeight: 600 }}>
                        ⚠ Cannot modify — truck is {t.status === "in_use" ? "in use" : "reserved"}
                      </span>
                    </div>
                  )}

                  {/* permanent driver chip */}
                  <div style={{
                    background: CARD2, borderRadius: 8, padding: "8px 12px", marginBottom: 14,
                    border: `1px solid ${t.driver_id ? (isUnderMaintenance ? "rgba(248,113,113,0.2)" : G_BRD) : BORDER}`,
                  }}>
                    <p style={{ fontSize: 10, color: "#475569", margin: "0 0 3px", textTransform: "uppercase", letterSpacing: "0.06em", fontWeight: 600 }}>
                      Assigned Driver
                    </p>
                    {t.driver_name ? (
                      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                        <div style={{
                          width: 20, height: 20, borderRadius: "50%",
                          background: isUnderMaintenance ? "rgba(248,113,113,0.12)" : G_DIM,
                          border: `1px solid ${isUnderMaintenance ? "rgba(248,113,113,0.3)" : G_BRD}`,
                          display: "flex", alignItems: "center", justifyContent: "center",
                          fontSize: 10, fontWeight: 700,
                          color: isUnderMaintenance ? "#f87171" : "#4ade80",
                          flexShrink: 0,
                        }}>
                          {t.driver_name[0]?.toUpperCase()}
                        </div>
                        <p style={{ fontSize: 13, fontWeight: 600, color: "#cbd5e1", margin: 0 }}>
                          {t.driver_name}
                        </p>
                        {isUnderMaintenance && (
                          <span style={{
                            fontSize: 10, color: "#f87171",
                            background: "rgba(248,113,113,0.1)",
                            border: "1px solid rgba(248,113,113,0.2)",
                            borderRadius: 4, padding: "1px 6px", marginLeft: "auto",
                          }}>
                            On Leave
                          </span>
                        )}
                      </div>
                    ) : (
                      <p style={{ fontSize: 12, color: "#475569", margin: 0, fontStyle: "italic" }}>
                        No driver assigned
                      </p>
                    )}
                  </div>

                  {/* actions */}
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    {/* Edit — blocked during maintenance */}
                    <button
                      className="tr-btn-icon"
                      disabled={isUnderMaintenance}
                      title={isUnderMaintenance ? "Cannot edit while under maintenance" : "Edit truck"}
                      onClick={() => openEdit(t)}
                    >
                      <Pencil size={12} /> Edit
                    </button>

                    {/* Maintenance toggle */}
                    {isUnderMaintenance ? (
                      <button
                        className="tr-btn-restore"
                        disabled={isMaintPending}
                        title="Mark as Available"
                        onClick={() => handleMaintenanceToggle(t)}
                      >
                        <CheckCircle size={12} />
                        {isMaintPending ? "Updating…" : "Mark Available"}
                      </button>
                    ) : (
                      <button
                        className="tr-btn-maint"
                        disabled={isBlocked || isMaintPending}
                        title={isBlocked ? `Cannot set to maintenance while ${t.status}` : "Mark as Under Maintenance"}
                        onClick={() => handleMaintenanceToggle(t)}
                      >
                        <Wrench size={12} />
                        {isMaintPending ? "Updating…" : "Maintenance"}
                      </button>
                    )}

                    {/* Delete — blocked unless available */}
                    <button
                      className="tr-btn-del"
                      disabled={isUndeletable}
                      title={isUndeletable ? `Cannot delete truck with status "${t.status}"` : "Delete truck"}
                      onClick={() => handleDelete(t)}
                    >
                      <Trash2 size={12} /> Delete
                    </button>
                  </div>

                </div>
              );
            })}
          </div>
        )}

      </div>

      {/* ── MODAL ── */}
      {showForm && (
        <div className="overlay" onClick={e => { if (e.target === e.currentTarget) closeForm(); }}>
          <div className="modal">

            {/* modal header */}
            <div style={{
              padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`,
              display: "flex", alignItems: "center", justifyContent: "space-between",
            }}>
              <div>
                <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>
                  Fleet Management
                </p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>
                  {editing ? "Edit Truck" : "Add New Truck"}
                </p>
              </div>
              <button className="tr-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeForm}>
                <X size={14} />
              </button>
            </div>

            {/* form */}
            <form onSubmit={handleSubmit} style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>

              {/* plate + model */}
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div>
                  <label className="field-label">Plate Number *</label>
                  <input
                    className={`tr-input${err.plate_number ? " err" : ""}`}
                    placeholder="e.g. ABC-1234"
                    value={form.plate_number}
                    onChange={e => setForm({ ...form, plate_number: e.target.value })}
                  />
                  {err.plate_number && <p className="errmsg">{err.plate_number}</p>}
                </div>
                <div>
                  <label className="field-label">Model</label>
                  <input
                    className="tr-input"
                    placeholder="e.g. Isuzu Elf"
                    value={form.model}
                    onChange={e => setForm({ ...form, model: e.target.value })}
                  />
                </div>
              </div>

              {/* truck type */}
              <div>
                <label className="field-label">Truck Type *</label>
                <select
                  className={`tr-select${err.truck_type ? " err" : ""}`}
                  value={form.truck_type}
                  onChange={e => setForm({ ...form, truck_type: e.target.value, custom_truck_type: e.target.value !== "custom" ? "" : form.custom_truck_type })}
                >
                  <option value="">Select type</option>
                  {TRUCK_TYPES.map(o => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
                {err.truck_type && <p className="errmsg">{err.truck_type}</p>}
              </div>

              {/* custom type */}
              {form.truck_type === "custom" && (
                <div>
                  <label className="field-label">Custom Truck Type *</label>
                  <input
                    className={`tr-input${err.custom_truck_type ? " err" : ""}`}
                    placeholder="e.g. Lowbed Trailer, Mini Truck"
                    value={form.custom_truck_type}
                    onChange={e => setForm({ ...form, custom_truck_type: e.target.value })}
                  />
                  {err.custom_truck_type && <p className="errmsg">{err.custom_truck_type}</p>}
                </div>
              )}

              {/* driver assignment */}
              <div>
                <label className="field-label">Assigned Driver</label>
                <select
                  className={`tr-select${err.driver_id ? " err" : ""}`}
                  value={form.driver_id}
                  onChange={e => setForm({ ...form, driver_id: e.target.value })}
                >
                  <option value="">— No Driver (Unassign) —</option>
                  {editing?.driver_id && !availableDrivers.find(d => d.id === editing.driver_id) && (() => {
                    const currentDriver = drivers.find(d => d.id === editing.driver_id);
                    return currentDriver ? (
                      <option key={currentDriver.id} value={currentDriver.id}>
                        {currentDriver.fullName || currentDriver.name} (current)
                      </option>
                    ) : null;
                  })()}
                  {availableDrivers.map(d => (
                    <option key={d.id} value={d.id}>
                      {d.fullName || d.name}
                    </option>
                  ))}
                </select>
                {err.driver_id && <p className="errmsg">{err.driver_id}</p>}
                {availableDrivers.length === 0 && !editing && (
                  <p style={{ fontSize: 11, color: "#475569", margin: "6px 0 0", fontStyle: "italic" }}>
                    All drivers already have a truck assigned. Add a new driver first.
                  </p>
                )}
              </div>

              {/* status note */}
              <div style={{
                background: "rgba(96,165,250,0.05)", border: "1px solid rgba(96,165,250,0.15)",
                borderRadius: 10, padding: "10px 14px",
              }}>
                <p style={{ fontSize: 11, color: "#60a5fa", margin: 0 }}>
                  ℹ️ Truck status is managed automatically by the dispatch system. Use the <strong>Maintenance</strong> button on the truck card to manually mark a truck as under maintenance.
                </p>
              </div>

              {/* footer */}
              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 16, borderTop: `1px solid ${BORDER}` }}>
                <button type="button" className="tr-btn-ghost" onClick={closeForm}>Cancel</button>
                <button type="submit" className="tr-btn-primary" disabled={isBusy}>
                  {isBusy ? "Saving…" : editing ? "Update Truck" : "Create Truck"}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}
    </div>
  );
}