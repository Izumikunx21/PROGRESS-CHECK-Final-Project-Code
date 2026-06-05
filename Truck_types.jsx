import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { collection, doc, updateDoc, addDoc, deleteDoc } from "firebase/firestore";
import { db } from "@/firebase/config";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import { Pencil, Trash2, Plus, Truck, X } from "lucide-react";

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

const INITIAL_FORM = { type:"", base_price:"", per_km:"", capacity_tons:"" };

const fmtType = (type) => {
  if (!type) return "";
  return type.trim().toLowerCase().replace(/-/g,"_").split("_").filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
};

const toKey = (s) => s.trim().toLowerCase().replace(/\s+/g,"_");

export default function AdminTruckTypes() {
  const { data: types  = [] } = useFirestoreCollection("truck_types");
  const { data: trucks = [] } = useFirestoreCollection("trucks");

  const [form, setForm]       = useState(INITIAL_FORM);
  const [editing, setEditing] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [err, setErr]         = useState({});

  /* ── available types ── */
  const availableTypes = (() => {
    const used       = new Set(trucks.map(t => t.truck_type).filter(Boolean));
    const configured = new Set(types.map(t => t.type));
    return Array.from(new Set([...used, ...configured])).sort()
      .map(v => ({ value:v, label:fmtType(v), configured:configured.has(v) }));
  })();

  const closeForm = () => { setForm(INITIAL_FORM); setEditing(null); setShowForm(false); setErr({}); };

  /* ── validation ── */
  const validate = () => {
    const e = {};
    if (!form.type.trim()) e.type = "Select a truck type";
    const dup = types.find(t => {
      if (editing?.id && t.id === editing.id) return false;
      return t.type.trim().toLowerCase() === form.type.trim().toLowerCase();
    });
    if (dup) e.type = "This truck type is already configured";
    if (Number(form.base_price) <= 0) e.base_price = "Enter a valid base price";
    if (Number(form.per_km)     <= 0) e.per_km     = "Enter a valid price per km";
    if (Number(form.capacity_tons) <= 0) e.capacity_tons = "Enter a valid capacity";
    setErr(e);
    return Object.keys(e).length === 0;
  };

  const createMutation = useMutation({
    mutationFn: async (data) => {
      await addDoc(collection(db, "truck_types"), {
        type: toKey(data.type),
        base_price: Number(data.base_price),
        per_km: Number(data.per_km),
        capacity_tons: Number(data.capacity_tons),
        createdAt: new Date(),
      });
    },
    onSuccess: closeForm,
  });

  const updateMutation = useMutation({
    mutationFn: async ({ id, data }) => {
      await updateDoc(doc(db, "truck_types", id), {
        type: toKey(data.type),
        base_price: Number(data.base_price),
        per_km: Number(data.per_km),
        capacity_tons: Number(data.capacity_tons),
      });
    },
    onSuccess: closeForm,
  });

  const deleteMutation = useMutation({
    mutationFn: async (id) => { await deleteDoc(doc(db, "truck_types", id)); },
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;
    editing?.id
      ? updateMutation.mutate({ id:editing.id, data:form })
      : createMutation.mutate(form);
  };

  const isBusy = createMutation.isPending || updateMutation.isPending;

  return (
    <div style={{ fontFamily:"'DM Sans',sans-serif", background:DARK, minHeight:"100vh", padding:"28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .tt * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .tt h1 { font-family:'Sora',sans-serif; }
        .tt-input { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; transition:border-color 0.18s;
          font-family:'DM Sans',sans-serif; }
        .tt-input:focus { border-color:rgba(22,163,74,0.5); }
        .tt-input::placeholder { color:#475569; }
        .tt-input.err { border-color:rgba(239,68,68,0.5); }
        .tt-select { width:100%; background:#0f172a; border:1px solid ${BORDER}; border-radius:10px;
          padding:10px 14px; color:#f1f5f9; font-size:13px; outline:none; cursor:pointer;
          font-family:'DM Sans',sans-serif; appearance:none; }
        .tt-select:focus { border-color:rgba(22,163,74,0.5); }
        .tt-select.err { border-color:rgba(239,68,68,0.5); }
        .tt-select option { background:#1e293b; }
        .tt-btn-primary { display:flex; align-items:center; gap:7px; background:${G_DIM};
          border:1px solid ${G_BRD}; color:#4ade80; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s;
          font-family:'DM Sans',sans-serif; }
        .tt-btn-primary:hover { background:rgba(22,163,74,0.25); }
        .tt-btn-ghost { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#94a3b8;
          border-radius:10px; padding:9px 18px; font-size:13px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .tt-btn-ghost:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .tt-btn-icon { background:rgba(255,255,255,0.04); border:1px solid ${BORDER}; color:#64748b;
          border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tt-btn-icon:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .tt-btn-del { background:rgba(239,68,68,0.08); border:1px solid rgba(239,68,68,0.2);
          color:#f87171; border-radius:8px; padding:6px 10px; font-size:12px; font-weight:500;
          cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif;
          display:flex; align-items:center; gap:5px; }
        .tt-btn-del:hover { background:rgba(239,68,68,0.15); }
        .tt-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px;
          padding:20px; transition:border-color 0.18s; }
        .tt-card:hover { border-color:rgba(255,255,255,0.12); }
        .overlay { position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:50;
          display:flex; align-items:center; justify-content:center; padding:24px; }
        .modal { background:#111827; border:1px solid ${BORDER}; border-radius:20px;
          width:100%; max-width:480px; overflow:hidden; box-shadow:0 24px 64px rgba(0,0,0,0.5); }
        .errmsg { font-size:11px; color:#f87171; margin:4px 0 0; }
        @media(max-width:900px){ .tt-grid{ grid-template-columns:1fr 1fr !important; } }
        @media(max-width:580px){ .tt-grid{ grid-template-columns:1fr !important; } }
      `}</style>

      <div className="tt" style={{ display:"flex", flexDirection:"column", gap:20 }}>

        {/* ── HEADER ── */}
        <div style={{ display:"flex", alignItems:"flex-start", justifyContent:"space-between", flexWrap:"wrap", gap:16 }}>
          <div>
            <h1 style={{ fontSize:28, fontWeight:800, color:"#f1f5f9", margin:0 }}>Truck Types</h1>
            <p style={{ color:"#64748b", fontSize:14, margin:"4px 0 0" }}>
              Manage pricing categories for trucks
            </p>
          </div>
          <button className="tt-btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={14}/> Add Type
          </button>
        </div>

        {/* ── GRID ── */}
        {types.length === 0 ? (
          <div style={{ background:CARD, border:`1px solid ${BORDER}`, borderRadius:16,
            padding:"60px 24px", textAlign:"center" }}>
            <Truck size={32} style={{ color:"#334155", margin:"0 auto 12px" }}/>
            <p style={{ color:"#475569", fontSize:14, margin:0 }}>No truck types configured yet.</p>
            <p style={{ color:"#334155", fontSize:13, margin:"4px 0 0" }}>
              Add a type to define pricing for your fleet.
            </p>
          </div>
        ) : (
          <div className="tt-grid" style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:14 }}>
            {types.map(t => (
              <div key={t.id} className="tt-card">
                {/* icon + name */}
                <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:16 }}>
                  <div style={{ width:40, height:40, borderRadius:11, flexShrink:0,
                    background:G_DIM, border:`1px solid ${G_BRD}`,
                    display:"flex", alignItems:"center", justifyContent:"center" }}>
                    <Truck size={18} style={{ color:"#4ade80" }}/>
                  </div>
                  <div>
                    <p style={{ fontSize:15, fontWeight:700, color:"#f1f5f9", margin:0 }}>
                      {fmtType(t.type)}
                    </p>
                    <p style={{ fontSize:11, color:"#475569", margin:0 }}>
                      {t.capacity_tons} ton capacity
                    </p>
                  </div>
                </div>

                {/* pricing */}
                <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:8, marginBottom:16 }}>
                  {[
                    { label:"Base Price", value:`₱${t.base_price?.toLocaleString()}` },
                    { label:"Per KM",     value:`₱${t.per_km}/km` },
                  ].map(m => (
                    <div key={m.label} style={{ background:CARD2, borderRadius:8, padding:"10px 12px" }}>
                      <p style={{ fontSize:10, color:"#475569", margin:"0 0 3px",
                        textTransform:"uppercase", letterSpacing:"0.06em", fontWeight:600 }}>{m.label}</p>
                      <p style={{ fontSize:14, fontWeight:700, color:"#4ade80", margin:0 }}>{m.value}</p>
                    </div>
                  ))}
                </div>

                {/* actions */}
                <div style={{ display:"flex", gap:8 }}>
                  <button className="tt-btn-icon" onClick={() => {
                    setEditing(t);
                    setForm({ type:t.type||"", base_price:t.base_price||"",
                      per_km:t.per_km||"", capacity_tons:t.capacity_tons||"" });
                    setShowForm(true);
                  }}>
                    <Pencil size={12}/> Edit
                  </button>
                  <button className="tt-btn-del" onClick={() => {
                    if (window.confirm(`Delete ${fmtType(t.type)} pricing?\n\nThis cannot be undone.`))
                      deleteMutation.mutate(t.id);
                  }}>
                    <Trash2 size={12}/> Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

      </div>

      {/* ── MODAL ── */}
      {showForm && (
        <div className="overlay" onClick={e => { if (e.target === e.currentTarget) closeForm(); }}>
          <div className="modal">

            {/* modal header */}
            <div style={{ padding:"20px 24px 16px", borderBottom:`1px solid ${BORDER}`,
              display:"flex", alignItems:"center", justifyContent:"space-between" }}>
              <div>
                <p style={{ fontSize:10, color:"#4ade80", fontWeight:700, letterSpacing:"0.18em",
                  textTransform:"uppercase", margin:"0 0 4px" }}>Fleet Config</p>
                <p style={{ fontSize:16, fontWeight:700, color:"#f1f5f9", margin:0 }}>
                  {editing ? "Edit Truck Type" : "Add Truck Type"}
                </p>
              </div>
              <button className="tt-btn-ghost" style={{ padding:"6px 10px", borderRadius:8 }}
                onClick={closeForm}>
                <X size={14}/>
              </button>
            </div>

            {/* modal body */}
            <form onSubmit={handleSubmit} style={{ padding:24, display:"flex", flexDirection:"column", gap:18 }}>

              {/* type select */}
              <div>
                <label style={{ fontSize:12, color:"#94a3b8", fontWeight:600,
                  textTransform:"uppercase", letterSpacing:"0.07em", display:"block", marginBottom:8 }}>
                  Truck Type *
                </label>
                <div style={{ position:"relative" }}>
                  <select className={`tt-select${err.type?" err":""}`}
                    value={form.type} onChange={e => setForm({...form, type:e.target.value})}>
                    <option value="">Select a truck type</option>
                    {availableTypes.map(o => (
                      <option key={o.value} value={o.value}>
                        {o.label}{o.configured ? " ✓" : ""}
                      </option>
                    ))}
                  </select>
                </div>
                {err.type && <p className="errmsg">{err.type}</p>}
                <p style={{ fontSize:11, color:"#475569", margin:"5px 0 0" }}>
                  Types are pulled from trucks you've added. Don't see one? Add it in the Trucks page first.
                </p>
              </div>

              {/* base price + per km */}
              <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:12 }}>
                {[
                  { key:"base_price", label:"Base Price (₱)", placeholder:"e.g. 1500" },
                  { key:"per_km",     label:"Price per KM (₱)", placeholder:"e.g. 45" },
                ].map(f => (
                  <div key={f.key}>
                    <label style={{ fontSize:12, color:"#94a3b8", fontWeight:600,
                      textTransform:"uppercase", letterSpacing:"0.07em", display:"block", marginBottom:8 }}>
                      {f.label} *
                    </label>
                    <input type="number" className={`tt-input${err[f.key]?" err":""}`}
                      placeholder={f.placeholder} value={form[f.key]}
                      onChange={e => setForm({...form, [f.key]:e.target.value})}/>
                    {err[f.key] && <p className="errmsg">{err[f.key]}</p>}
                  </div>
                ))}
              </div>

              {/* capacity */}
              <div>
                <label style={{ fontSize:12, color:"#94a3b8", fontWeight:600,
                  textTransform:"uppercase", letterSpacing:"0.07em", display:"block", marginBottom:8 }}>
                  Capacity (Tons) *
                </label>
                <input type="number" className={`tt-input${err.capacity_tons?" err":""}`}
                  placeholder="e.g. 2" value={form.capacity_tons}
                  onChange={e => setForm({...form, capacity_tons:e.target.value})}/>
                {err.capacity_tons && <p className="errmsg">{err.capacity_tons}</p>}
              </div>

              {/* actions */}
              <div style={{ display:"flex", justifyContent:"flex-end", gap:10,
                paddingTop:16, borderTop:`1px solid ${BORDER}` }}>
                <button type="button" className="tt-btn-ghost" onClick={closeForm}>
                  Cancel
                </button>
                <button type="submit" className="tt-btn-primary" disabled={isBusy}
                  style={{ opacity:isBusy?0.6:1 }}>
                  {isBusy ? "Saving…" : editing ? "Update Type" : "Create Type"}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}
    </div>
  );
}