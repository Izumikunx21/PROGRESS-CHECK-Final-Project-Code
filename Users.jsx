import React, { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { collection, addDoc, updateDoc, deleteDoc, doc } from "firebase/firestore";
import { db } from "@/firebase/config";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import {
  Plus, Pencil, Trash2, Phone, Mail, Ban,
  CheckCircle, ShieldCheck, ShieldAlert, Users, X,
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
  fullName: "",
  email: "",
  phone: "",
  role: "customer",
  status: "active",
};

const STATUS_META = {
  active:  { label: "Active",  color: "#4ade80", bg: "rgba(74,222,128,0.1)",  border: "rgba(74,222,128,0.25)"  },
  blocked: { label: "Blocked", color: "#f87171", bg: "rgba(248,113,113,0.1)", border: "rgba(248,113,113,0.25)" },
};

const ROLE_META = {
  driver:   { label: "Driver",   color: "#60a5fa", bg: "rgba(96,165,250,0.1)",  border: "rgba(96,165,250,0.25)"  },
  customer: { label: "Customer", color: "#4ade80", bg: "rgba(74,222,128,0.1)",  border: "rgba(74,222,128,0.25)"  },
  admin:    { label: "Admin",    color: "#c084fc", bg: "rgba(192,132,252,0.1)", border: "rgba(192,132,252,0.25)" },
};

export default function AdminUsers() {
  const [showForm, setShowForm]           = useState(false);
  const [editing, setEditing]             = useState(null);
  const [form, setForm]                   = useState(INITIAL_FORM);
  const [roleFilter, setRoleFilter]       = useState("all");
  const [showBlockDialog, setShowBlockDialog] = useState(false);
  const [blockTarget, setBlockTarget]     = useState(null);
  const [blockReason, setBlockReason]     = useState("");
  const [blockDuration, setBlockDuration] = useState("30");

  const qc = useQueryClient();
  const { data: users = [] } = useFirestoreCollection("users");

  /* ── mutations ── */
  const createMutation = useMutation({
    mutationFn: async (data) => { await addDoc(collection(db, "users"), data); },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); closeForm(); },
  });

  const updateMutation = useMutation({
    mutationFn: async ({ id, data }) => { await updateDoc(doc(db, "users", id), data); },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); closeForm(); },
  });

  const blockMutation = useMutation({
    mutationFn: async ({ id, data }) => { await updateDoc(doc(db, "users", id), data); },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); },
  });

  const deleteMutation = useMutation({
    mutationFn: async (id) => { await deleteDoc(doc(db, "users", id)); },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["users"] }),
  });

  /* ── helpers ── */
  const closeForm = () => { setShowForm(false); setEditing(null); setForm(INITIAL_FORM); };

  const openEdit = (u) => {
    setEditing(u);
    setForm({ fullName: u.fullName, email: u.email, phone: u.phone || "", role: u.role || "customer", status: u.status || "active" });
    setShowForm(true);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    editing ? updateMutation.mutate({ id: editing.id, data: form }) : createMutation.mutate(form);
  };

  const toggleBlock = (user) => {
    const isBlocked = user.blockedUntil != null || user.status === "blocked";
    if (isBlocked) {
      if (!window.confirm(`Unblock ${user.fullName || user.email}?`)) return;
      blockMutation.mutate({ id: user.id, data: { status: "active", cancellationCount: 0, blockedUntil: null, blockReason: null } });
    } else {
      setBlockTarget(user);
      setShowBlockDialog(true);
    }
  };

  const confirmDeleteUser = (user) => {
    if (window.confirm(`Delete user ${user.fullName || user.email}? This action cannot be undone.`))
      deleteMutation.mutate(user.id);
  };

  const closeBlockDialog = () => { setShowBlockDialog(false); setBlockTarget(null); setBlockReason(""); setBlockDuration("30"); };

  const filteredUsers =
    roleFilter === "all"        ? users
    : roleFilter === "blocked"   ? users.filter((u) => u.blockedUntil != null || u.status === "blocked")
    : roleFilter === "unverified"? users.filter((u) => !u.isEmailVerified)
    : users.filter((u) => u.role === roleFilter);

  const filterTabs = [
    ["all", "All"], ["driver", "Drivers"], ["customer", "Customers"],
    ["admin", "Admins"], ["blocked", "Blocked"], ["unverified", "Unverified"],
  ];

  const isBusy = createMutation.isPending || updateMutation.isPending;

  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .us * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .us h1 { font-family:'Sora',sans-serif; }
        .us-input { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; transition:border-color 0.18s;
          font-family:'DM Sans',sans-serif; }
        .us-input:focus { border-color:rgba(22,163,74,0.5); }
        .us-input::placeholder { color:#475569; }
        .us-select { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; cursor:pointer;
          font-family:'DM Sans',sans-serif; appearance:none; }
        .us-select:focus { border-color:rgba(22,163,74,0.5); }
        .us-select option { background:#1e293b; }
        .us-btn-primary { display:flex; align-items:center; gap:7px; background:${G_DIM};
          border:1px solid ${G_BRD}; color:#4ade80; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .us-btn-primary:hover { background:rgba(22,163,74,0.25); }
        .us-btn-primary:disabled { opacity:0.6; cursor:not-allowed; }
        .us-btn-danger { display:flex; align-items:center; gap:7px; background:rgba(239,68,68,0.12);
          border:1px solid rgba(239,68,68,0.3); color:#f87171; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .us-btn-danger:hover { background:rgba(239,68,68,0.2); }
        .us-btn-danger:disabled { opacity:0.6; cursor:not-allowed; }
        .us-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:10px; padding:9px 18px; font-size:13px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .us-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .us-btn-icon { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .us-btn-icon:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .us-btn-block { background:rgba(251,191,36,0.08); border:1px solid rgba(251,191,36,0.2);
          color:#fbbf24; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .us-btn-block:hover { background:rgba(251,191,36,0.15); }
        .us-btn-unblock { background:rgba(74,222,128,0.08); border:1px solid rgba(74,222,128,0.2);
          color:#4ade80; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .us-btn-unblock:hover { background:rgba(74,222,128,0.15); }
        .us-btn-del { background:rgba(239,68,68,0.08); border:1px solid rgba(239,68,68,0.2);
          color:#f87171; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .us-btn-del:hover { background:rgba(239,68,68,0.15); }
        .filt-us { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 14px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .filt-us:hover { color:#cbd5e1; }
        .filt-us.on { background:${G_DIM}; border-color:${G_BRD}; color:#4ade80; }
        .us-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px;
          padding:20px; transition:border-color 0.18s; }
        .us-card:hover { border-color:rgba(255,255,255,0.12); }
        .overlay-us { position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:50;
          display:flex; align-items:center; justify-content:center; padding:24px; }
        .modal-us { background:#111827; border:1px solid ${BORDER}; border-radius:20px;
          width:100%; max-width:560px; overflow:hidden; box-shadow:0 24px 64px rgba(0,0,0,0.5);
          max-height:90vh; overflow-y:auto; }
        .modal-sm { max-width:460px; }
        .field-label-us { font-size:12px; color:#94a3b8; font-weight:600;
          text-transform:uppercase; letter-spacing:0.07em; display:block; margin-bottom:8px; }
        @media(max-width:900px){ .us-grid{ grid-template-columns:1fr 1fr !important; } }
        @media(max-width:580px){ .us-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="us" style={{ display: "flex", flexDirection: "column", gap: 20 }}>

        {/* ── HEADER ── */}
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>User Management</h1>
            <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>
              Manage drivers, customers, and system users
            </p>
          </div>
          <button className="us-btn-primary" onClick={() => { setEditing(null); setForm(INITIAL_FORM); setShowForm(true); }}>
            <Plus size={14} /> Add User
          </button>
        </div>

        {/* ── FILTER TABS ── */}
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {filterTabs.map(([val, label]) => (
            <button key={val} className={`filt-us${roleFilter === val ? " on" : ""}`} onClick={() => setRoleFilter(val)}>
              {label}
              <span style={{ marginLeft: 6, fontSize: 11, opacity: 0.7 }}>
                {val === "all"         ? users.length
                : val === "blocked"    ? users.filter(u => u.blockedUntil != null || u.status === "blocked").length
                : val === "unverified" ? users.filter(u => !u.isEmailVerified).length
                : users.filter(u => u.role === val).length}
              </span>
            </button>
          ))}
        </div>

        {/* ── EMPTY STATE ── */}
        {filteredUsers.length === 0 && (
          <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, padding: "60px 24px", textAlign: "center" }}>
            <Users size={32} style={{ color: "#334155", margin: "0 auto 12px" }} />
            <p style={{ color: "#475569", fontSize: 14, margin: 0 }}>No users found.</p>
          </div>
        )}

        {/* ── GRID ── */}
        {filteredUsers.length > 0 && (
          <div className="us-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 14 }}>
            {filteredUsers.map((u) => {
              const statusMeta = STATUS_META[u.status] || STATUS_META.active;
              const roleMeta   = ROLE_META[u.role]     || { label: u.role, color: "#94a3b8", bg: "rgba(148,163,184,0.1)", border: "rgba(148,163,184,0.25)" };
              const isBlocked  = u.blockedUntil != null || u.status === "blocked";

              return (
                <div key={u.id} className="us-card">

                  {/* top row */}
                  <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 14 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 11, flexShrink: 0,
                      background: G_DIM, border: `1px solid ${G_BRD}`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 16, fontWeight: 700, color: "#4ade80",
                      overflow: "hidden",
                    }}>
                      {u.profileImage
                        ? <img src={u.profileImage} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                        : (u.fullName?.[0]?.toUpperCase() ?? "?")}
                    </div>
                    <span style={{
                      fontSize: 11, fontWeight: 700, color: statusMeta.color,
                      background: statusMeta.bg, border: `1px solid ${statusMeta.border}`,
                      borderRadius: 6, padding: "3px 10px",
                      display: "flex", alignItems: "center", gap: 5,
                    }}>
                      <span style={{ width: 6, height: 6, borderRadius: "50%", background: statusMeta.color, flexShrink: 0 }} />
                      {statusMeta.label}
                    </span>
                  </div>

                  {/* name */}
                  <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: "0 0 8px" }}>
                    {u.fullName || "—"}
                  </p>

                  {/* role + verified badges */}
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginBottom: 10 }}>
                    <span style={{
                      fontSize: 11, fontWeight: 600, color: roleMeta.color,
                      background: roleMeta.bg, border: `1px solid ${roleMeta.border}`,
                      borderRadius: 6, padding: "2px 8px",
                    }}>
                      {roleMeta.label}
                    </span>
                    {u.isEmailVerified ? (
                      <span style={{ fontSize: 11, fontWeight: 600, color: "#38bdf8", background: "rgba(56,189,248,0.1)", border: "1px solid rgba(56,189,248,0.25)", borderRadius: 6, padding: "2px 8px", display: "flex", alignItems: "center", gap: 4 }}>
                        <ShieldCheck size={10} /> Verified
                      </span>
                    ) : (
                      <span style={{ fontSize: 11, fontWeight: 600, color: "#fbbf24", background: "rgba(251,191,36,0.1)", border: "1px solid rgba(251,191,36,0.25)", borderRadius: 6, padding: "2px 8px", display: "flex", alignItems: "center", gap: 4 }}>
                        <ShieldAlert size={10} /> Unverified
                      </span>
                    )}
                  </div>

                  {/* cancellations */}
                  {u.role === "customer" && (
                    <div style={{ marginBottom: 8 }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12 }}>
                        <Ban size={12} style={{ color: "#f87171", flexShrink: 0 }} />
                        <span style={{ color: u.cancellationCount >= 3 ? "#f87171" : "#64748b", fontWeight: u.cancellationCount >= 3 ? 600 : 400 }}>
                          {u.cancellationCount ?? 0} cancellation{u.cancellationCount !== 1 ? "s" : ""}
                        </span>
                      </div>
                      {u.blockedUntil && (
                        <p style={{ fontSize: 11, color: "#f87171", margin: "4px 0 0" }}>
                          Blocked until {new Date(u.blockedUntil.seconds * 1000).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                  )}

                  {/* block reason */}
                  {u.blockReason && (
                    <div style={{ background: "rgba(239,68,68,0.06)", border: "1px solid rgba(239,68,68,0.15)", borderRadius: 8, padding: "6px 10px", marginBottom: 10 }}>
                      <p style={{ fontSize: 11, color: "#f87171", margin: 0 }}>
                        {u.blockReason} • by {u.blockedBy ?? "system"}
                      </p>
                    </div>
                  )}

                  {/* contact */}
                  <div style={{ display: "flex", flexDirection: "column", gap: 4, marginBottom: 14 }}>
                    <p style={{ fontSize: 12, color: "#64748b", margin: 0, display: "flex", alignItems: "center", gap: 6 }}>
                      <Mail size={12} style={{ flexShrink: 0 }} /> {u.email}
                    </p>
                    {u.phone && (
                      <p style={{ fontSize: 12, color: "#64748b", margin: 0, display: "flex", alignItems: "center", gap: 6 }}>
                        <Phone size={12} style={{ flexShrink: 0 }} /> {u.phone}
                      </p>
                    )}
                  </div>

                  {/* actions */}
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    <button className="us-btn-icon" onClick={() => openEdit(u)}>
                      <Pencil size={12} /> Edit
                    </button>
                    <button className={isBlocked ? "us-btn-unblock" : "us-btn-block"} onClick={() => toggleBlock(u)}>
                      {isBlocked ? <><CheckCircle size={12} /> Unblock</> : <><Ban size={12} /> Block</>}
                    </button>
                    <button className="us-btn-del" onClick={() => confirmDeleteUser(u)}>
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
      {showForm && (
        <div className="overlay-us" onClick={(e) => { if (e.target === e.currentTarget) closeForm(); }}>
          <div className="modal-us">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>
                  User Management
                </p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>
                  {editing ? "Edit User Details" : "Add New User"}
                </p>
              </div>
              <button className="us-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeForm}>
                <X size={14} />
              </button>
            </div>

            <form onSubmit={handleSubmit} style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <div>
                  <label className="field-label-us">Full Name *</label>
                  <input className="us-input" placeholder="e.g. Juan Dela Cruz" value={form.fullName}
                    onChange={(e) => setForm({ ...form, fullName: e.target.value })} required />
                </div>
                <div>
                  <label className="field-label-us">Email *</label>
                  <input className="us-input" placeholder="e.g. user@email.com" value={form.email}
                    onChange={(e) => setForm({ ...form, email: e.target.value })} required />
                </div>
              </div>

              <div>
                <label className="field-label-us">Phone</label>
                <input className="us-input" placeholder="e.g. 09XX-XXX-XXXX" value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })} />
              </div>

              <div>
                <label className="field-label-us">Role</label>
                <select className="us-select" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                  <option value="customer">Customer</option>
                  <option value="driver">Driver</option>
                  <option value="admin">Admin</option>
                </select>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 16, borderTop: `1px solid ${BORDER}` }}>
                <button type="button" className="us-btn-ghost" onClick={closeForm}>Cancel</button>
                <button type="submit" className="us-btn-primary" disabled={isBusy}>
                  {isBusy ? "Saving…" : editing ? "Update User" : "Create User"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── BLOCK DIALOG ── */}
      {showBlockDialog && (
        <div className="overlay-us" onClick={(e) => { if (e.target === e.currentTarget) closeBlockDialog(); }}>
          <div className="modal-us modal-sm">
            <div style={{ padding: "20px 24px 16px", borderBottom: `1px solid ${BORDER}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div>
                <p style={{ fontSize: 10, color: "#f87171", fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", margin: "0 0 4px" }}>
                  Suspend User
                </p>
                <p style={{ fontSize: 16, fontWeight: 700, color: "#f1f5f9", margin: 0, display: "flex", alignItems: "center", gap: 8 }}>
                  <Ban size={16} style={{ color: "#f87171" }} /> Block User
                </p>
              </div>
              <button className="us-btn-ghost" style={{ padding: "6px 10px", borderRadius: 8 }} onClick={closeBlockDialog}>
                <X size={14} />
              </button>
            </div>

            <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 18 }}>
              {blockTarget && (
                <div style={{ background: "rgba(239,68,68,0.06)", border: "1px solid rgba(239,68,68,0.15)", borderRadius: 10, padding: "10px 14px" }}>
                  <p style={{ fontSize: 13, color: "#fca5a5", margin: 0 }}>
                    <strong style={{ color: "#f87171" }}>{blockTarget.fullName || blockTarget.email}</strong> will be suspended from using the app.
                  </p>
                </div>
              )}

              <div>
                <label className="field-label-us">Reason *</label>
                <select className="us-select" value={blockReason} onChange={(e) => setBlockReason(e.target.value)}>
                  <option value="">Select a reason</option>
                  <option value="fraud">Fraudulent activity</option>
                  <option value="abuse">Abusive behavior</option>
                  <option value="complaint">Multiple complaints</option>
                  <option value="fake_booking">Fake bookings</option>
                  <option value="violation">Policy violation</option>
                  <option value="other">Other</option>
                </select>
              </div>

              <div>
                <label className="field-label-us">Duration</label>
                <select className="us-select" value={blockDuration} onChange={(e) => setBlockDuration(e.target.value)}>
                  <option value="7">7 days</option>
                  <option value="14">14 days</option>
                  <option value="30">30 days</option>
                  <option value="90">90 days</option>
                  <option value="permanent">Permanent</option>
                </select>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: 10, paddingTop: 16, borderTop: `1px solid ${BORDER}` }}>
                <button type="button" className="us-btn-ghost" onClick={closeBlockDialog}>Cancel</button>
                <button
                  className="us-btn-danger"
                  disabled={!blockReason}
                  onClick={() => {
                    const days = blockDuration === "permanent" ? 365 * 10 : parseInt(blockDuration);
                    const blockedUntil = new Date();
                    blockedUntil.setDate(blockedUntil.getDate() + days);
                    blockMutation.mutate({ id: blockTarget.id, data: { status: "blocked", blockReason, blockedUntil, blockedAt: new Date(), blockedBy: "admin" } });
                    closeBlockDialog();
                  }}
                >
                  <Ban size={13} /> Confirm Block
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}