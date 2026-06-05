import React from "react";
import { Link } from "react-router-dom";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import MapView from "@/components/shared/MapView";
import { MapPin, Truck, Users, Activity, ArrowRight, AlertTriangle, Clock } from "lucide-react";

/* ─────────── brand tokens ─────────── */
const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";

/* ─────────── status pill ─────────── */
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

const StatusPill = ({ status }) => {
  const s    = (status || "").toLowerCase().replace(/\s/g, "_");
  const meta = STATUS_META[s] || { color: "#94a3b8", bg: "rgba(148,163,184,0.1)", border: "rgba(148,163,184,0.25)" };
  return (
    <span style={{
      fontSize: 11, fontWeight: 700, color: meta.color, background: meta.bg,
      border: `1px solid ${meta.border}`, borderRadius: 6, padding: "3px 10px",
      display: "inline-flex", alignItems: "center", gap: 5, textTransform: "capitalize",
    }}>
      <span style={{ width: 5, height: 5, borderRadius: "50%", background: meta.color, flexShrink: 0 }} />
      {(status || "-").replace(/_/g, " ")}
    </span>
  );
};

export default function AdminMonitoring() {

  const { data: bookings = [] } = useFirestoreCollection("bookings");
  const { data: users = []    } = useFirestoreCollection("users");
  const { data: trucks = []   } = useFirestoreCollection("trucks");

  /* ── derived sets ── */
  const activeTrips = bookings.filter(b =>
    ["assigned","in_transit","accepted","en_route_to_pickup","arrived_at_pickup"].includes(b.status)
  );
  const activeDrivers = users.filter(u =>
    u.role === "driver" &&
    u.isOnline === true &&
    u.currentLocation?.lat &&
    u.currentLocation?.lng
  );

    // ✅ ADD THIS HERE — before kpis
  const driversOnTrip = users.filter(u =>
    u.role === "driver" &&
    u.isOnline === true &&
    ["on_trip", "busy"].includes(u.availability)
  );
  
  const trucksInUse     = trucks.filter(t => t.status === "in_use");
  const pendingBookings = bookings.filter(b => b.status === "pending");

  /* ── alerts ── */
  const needsReassignment = bookings.filter(b => b.needs_reassignment === true);
  const stalePending = bookings.filter(b => {
    if (b.status !== "pending" || !b.createdAt?.seconds) return false;
    const ageMinutes = (Date.now() / 1000 - b.createdAt.seconds) / 60;
    return ageMinutes > 15;
  });

  const hasAlerts = needsReassignment.length > 0 || stalePending.length > 0;

  /* ── helpers ── */
  const fmtType = (type) => {
    if (!type) return "-";
    if (typeof type === "object") type = type.type || type.name || "";
    if (typeof type !== "string") return "-";
    return type.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  };

  const getCustomerName = (b) => {
    if (b.customer_name) return b.customer_name;
    if (b.customer?.fullName) return b.customer.fullName;
    const u = users.find(u => u.id === b.userId);
    return u?.fullName || u?.name || u?.email || "Unknown";
  };

  const getDriverName = (b) => {
    if (b.assigned_driver_name) return b.assigned_driver_name;
    const d = users.find(u => u.id === b.assigned_driver_id);
    return d?.fullName || d?.name || b.assigned_driver_email || "Unassigned";
  };

  const getTruckType = (b) => {
    if (b.truckType?.type) return fmtType(b.truckType.type);
    if (b.truck?.type)     return fmtType(b.truck.type);
    if (typeof b.truckType === "string") return fmtType(b.truckType);
    if (b.assigned_truck_type) return fmtType(b.assigned_truck_type);
    return "-";
  };

  const getAgeMinutes = (b) => {
    if (!b.createdAt?.seconds) return null;
    return Math.floor((Date.now() / 1000 - b.createdAt.seconds) / 60);
  };

  /* ── kpi cards ── */
  const kpis = [
    { label:"Active Trips",     value:activeTrips.length,     accent:"#fbbf24", bg:"rgba(251,191,36,0.1)",  border:"rgba(251,191,36,0.2)",  Icon:Activity },
    { label:"Drivers On Trip",  value:driversOnTrip.length,   accent:"#4ade80", bg:G_DIM,                   border:G_BRD,                   Icon:Users    },
    { label:"Trucks In Use",    value:trucksInUse.length,     accent:"#60a5fa", bg:"rgba(96,165,250,0.1)",  border:"rgba(96,165,250,0.2)",  Icon:Truck    },
    { label:"Pending Bookings", value:pendingBookings.length, accent:"#f87171", bg:"rgba(248,113,113,0.1)", border:"rgba(248,113,113,0.2)", Icon:MapPin   },
  ];

  

  return (
    <div style={{ fontFamily:"'DM Sans',sans-serif", background:DARK, minHeight:"100vh", padding:"28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .mon * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .mon h1 { font-family:'Sora',sans-serif; }
        .mon-table { width:100%; border-collapse:collapse; }
        .mon-thead th { background:${CARD2}; color:#475569; font-size:10px; font-weight:700;
          text-transform:uppercase; letter-spacing:0.08em; padding:12px 16px; text-align:left;
          border-bottom:1px solid ${BORDER}; white-space:nowrap; }
        .mon-row { border-bottom:1px solid ${BORDER}; transition:background 0.14s; }
        .mon-row:last-child { border-bottom:none; }
        .mon-row:hover { background:rgba(255,255,255,0.025); }
        .mon-td { padding:12px 16px; vertical-align:middle; }
        .kpi-card { border-radius:14px; padding:18px 20px; display:flex; flex-direction:column; gap:12px;
          background:${CARD}; transition:border 0.18s; cursor:default; }
        .kpi-card:hover { border-color:rgba(255,255,255,0.12) !important; }
        .mon-card { background:${CARD}; border:1px solid ${BORDER}; border-radius:16px; overflow:hidden; }
        .mon-card-header { padding:16px 20px; border-bottom:1px solid ${BORDER};
          display:flex; align-items:center; justify-content:space-between; }
        .view-link { display:inline-flex; align-items:center; gap:5px; font-size:12px; font-weight:600;
          color:#60a5fa; text-decoration:none; transition:color 0.15s; }
        .view-link:hover { color:#93c5fd; }
        .alert-row { display:flex; align-items:flex-start; gap:12px; padding:12px 16px;
          border-bottom:1px solid rgba(239,68,68,0.12); }
        .alert-row:last-child { border-bottom:none; }
        @media(max-width:900px){
          .kpi-grid { grid-template-columns:1fr 1fr !important; }
          .alert-grid { grid-template-columns:1fr !important; }
        }
        @media(max-width:500px){
          .kpi-grid { grid-template-columns:1fr !important; }
        }
      `}</style>

      <div className="mon" style={{ display:"flex", flexDirection:"column", gap:20 }}>

        {/* ── HEADER ── */}
        <div>
          <h1 style={{ fontSize:28, fontWeight:800, color:"#f1f5f9", margin:0 }}>
            Real-Time Monitoring
          </h1>
          <p style={{ color:"#64748b", fontSize:14, margin:"4px 0 0" }}>
            Track active deliveries, drivers, and truck activity in real time
          </p>
        </div>

        {/* ── KPI STRIP ── */}
        <div className="kpi-grid" style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12 }}>
          {kpis.map(k => (
            <div key={k.label} className="kpi-card" style={{ border:`1px solid ${k.border}` }}>
              <div style={{ display:"flex", alignItems:"center", gap:10 }}>
                <div style={{
                  width:36, height:36, borderRadius:9, background:k.bg, border:`1px solid ${k.border}`,
                  display:"flex", alignItems:"center", justifyContent:"center", flexShrink:0,
                }}>
                  <k.Icon size={16} style={{ color:k.accent }}/>
                </div>
                <p style={{ fontSize:12, color:"#64748b", fontWeight:600, margin:0, lineHeight:1.3 }}>
                  {k.label}
                </p>
              </div>
              <p style={{ fontSize:30, fontWeight:800, color:k.accent, margin:0,
                fontFamily:"'Sora',sans-serif", lineHeight:1 }}>{k.value}</p>
            </div>
          ))}
        </div>

        {/* ── ALERTS ── */}
        {hasAlerts && (
          <div className="alert-grid" style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>

            {needsReassignment.length > 0 && (
              <div style={{ background:"rgba(239,68,68,0.06)", border:"1px solid rgba(239,68,68,0.25)",
                borderRadius:16, overflow:"hidden" }}>
                <div style={{ padding:"14px 18px", borderBottom:"1px solid rgba(239,68,68,0.15)",
                  display:"flex", alignItems:"center", gap:8 }}>
                  <AlertTriangle size={14} style={{ color:"#f87171", flexShrink:0 }}/>
                  <p style={{ fontSize:13, fontWeight:700, color:"#f87171", margin:0 }}>
                    Needs Reassignment
                    <span style={{ fontSize:11, fontWeight:500, color:"rgba(248,113,113,0.7)", marginLeft:8 }}>
                      ({needsReassignment.length})
                    </span>
                  </p>
                </div>
                <div>
                  {needsReassignment.map(b => (
                    <div key={b.id} className="alert-row">
                      <div style={{ flex:1, minWidth:0 }}>
                        <p style={{ fontSize:13, fontWeight:600, color:"#f1f5f9", margin:"0 0 2px",
                          overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                          {getCustomerName(b)}
                        </p>
                        <p style={{ fontSize:11, color:"#64748b", margin:0,
                          overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                          {b.pickupLocation || "-"} → {b.destination || "-"}
                        </p>
                      </div>
                      <Link to="/admin/bookings" style={{ flexShrink:0, fontSize:11, fontWeight:600,
                        color:"#f87171", textDecoration:"none", opacity:0.8 }}>
                        Assign →
                      </Link>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {stalePending.length > 0 && (
              <div style={{ background:"rgba(251,191,36,0.06)", border:"1px solid rgba(251,191,36,0.25)",
                borderRadius:16, overflow:"hidden" }}>
                <div style={{ padding:"14px 18px", borderBottom:"1px solid rgba(251,191,36,0.15)",
                  display:"flex", alignItems:"center", gap:8 }}>
                  <Clock size={14} style={{ color:"#fbbf24", flexShrink:0 }}/>
                  <p style={{ fontSize:13, fontWeight:700, color:"#fbbf24", margin:0 }}>
                    Pending Too Long
                    <span style={{ fontSize:11, fontWeight:500, color:"rgba(251,191,36,0.7)", marginLeft:8 }}>
                      (no driver after 15 min)
                    </span>
                  </p>
                </div>
                <div>
                  {stalePending.map(b => {
                    const age = getAgeMinutes(b);
                    return (
                      <div key={b.id} className="alert-row">
                        <div style={{ flex:1, minWidth:0 }}>
                          <p style={{ fontSize:13, fontWeight:600, color:"#f1f5f9", margin:"0 0 2px",
                            overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                            {getCustomerName(b)}
                          </p>
                          <p style={{ fontSize:11, color:"#64748b", margin:0,
                            overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                            {b.pickupLocation || "-"} → {b.destination || "-"}
                          </p>
                        </div>
                        <span style={{ flexShrink:0, fontSize:11, fontWeight:700, color:"#fbbf24" }}>
                          {age}m ago
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

          </div>
        )}

        {/* ── LIVE MAP ── */}
        <div className="mon-card">
          <div className="mon-card-header">
            <div>
              <p style={{ fontSize:10, color:"#4ade80", fontWeight:700, letterSpacing:"0.14em",
                textTransform:"uppercase", margin:"0 0 2px" }}>Live</p>
              <p style={{ fontSize:15, fontWeight:700, color:"#f1f5f9", margin:0,
                display:"flex", alignItems:"center", gap:8 }}>
                <MapPin size={15} style={{ color:"#4ade80" }}/> Live Monitoring Map
              </p>
            </div>
            <span style={{ fontSize:11, color:"#475569" }}>
              {activeTrips.length} active trip{activeTrips.length !== 1 ? "s" : ""}
            </span>
          </div>
          <div style={{ padding:20 }}>
            <MapView drivers={activeDrivers} trips={activeTrips} height="500px"/>
          </div>
        </div>

        {/* ── ACTIVE TRIPS TABLE ── */}
        <div className="mon-card">
          <div className="mon-card-header">
            <div>
              <p style={{ fontSize:10, color:"#4ade80", fontWeight:700, letterSpacing:"0.14em",
                textTransform:"uppercase", margin:"0 0 2px" }}>Monitoring</p>
              <p style={{ fontSize:15, fontWeight:700, color:"#f1f5f9", margin:0 }}>
                Active Trips
                <span style={{ fontSize:12, color:"#475569", fontWeight:500, marginLeft:8 }}>
                  ({activeTrips.length})
                </span>
              </p>
            </div>
            <Link to="/admin/bookings" className="view-link">
              View all bookings <ArrowRight size={13}/>
            </Link>
          </div>

          <div style={{ overflowX:"auto" }}>
            <table className="mon-table">
              <thead className="mon-thead">
                <tr>
                  {["Customer", "Driver", "Truck", "Route", "Status"].map(h => (
                    <th key={h}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {activeTrips.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="mon-td" style={{ textAlign:"center", color:"#334155",
                      fontSize:13, padding:"48px 16px" }}>
                      No active trips at the moment
                    </td>
                  </tr>
                ) : activeTrips.map(trip => (
                  <tr key={trip.id} className="mon-row">

                    {/* CUSTOMER */}
                    <td className="mon-td" style={{ whiteSpace:"nowrap" }}>
                      <p style={{ fontSize:13, fontWeight:600, color:"#f1f5f9", margin:0 }}>
                        {getCustomerName(trip)}
                      </p>
                    </td>

                    {/* DRIVER */}
                    <td className="mon-td" style={{ whiteSpace:"nowrap" }}>
                      <p style={{ fontSize:13, fontWeight:500,
                        color: trip.assigned_driver_name ? "#e2e8f0" : "#334155", margin:0 }}>
                        {getDriverName(trip)}
                      </p>
                    </td>

                    {/* TRUCK */}
                    <td className="mon-td">
                      <span style={{
                        fontSize:11, fontWeight:600, color:"#60a5fa",
                        background:"rgba(96,165,250,0.1)", border:"1px solid rgba(96,165,250,0.25)",
                        borderRadius:5, padding:"2px 8px",
                      }}>
                        {getTruckType(trip)}
                      </span>
                    </td>

                    {/* ROUTE */}
                    <td className="mon-td" style={{ maxWidth:220 }}>
                      <div style={{ display:"flex", flexDirection:"column", gap:4 }}>
                        <span style={{ display:"flex", alignItems:"center", gap:5, fontSize:11, color:"#94a3b8" }}>
                          <span style={{ width:6, height:6, borderRadius:"50%", background:"#4ade80", flexShrink:0 }}/>
                          <span style={{ overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                            {trip.pickupLocation || "-"}
                          </span>
                        </span>
                        <span style={{ display:"flex", alignItems:"center", gap:5, fontSize:11, color:"#94a3b8" }}>
                          <span style={{ width:6, height:6, borderRadius:"50%", background:"#f87171", flexShrink:0 }}/>
                          <span style={{ overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                            {trip.destination || "-"}
                          </span>
                        </span>
                      </div>
                    </td>

                    {/* STATUS */}
                    <td className="mon-td">
                      <StatusPill status={trip.status}/>
                    </td>

                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
  );
}