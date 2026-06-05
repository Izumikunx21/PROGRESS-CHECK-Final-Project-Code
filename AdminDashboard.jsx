import React from "react";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import { ClipboardList, Truck, Users, MapPin, ArrowRight } from "lucide-react";
import { Link } from "react-router-dom";
import { format } from "date-fns";

/* ─────────── brand tokens ─────────── */
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";

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

const STAT_CONFIG = [
  {
    key: "total",
    title: "Total Bookings",
    icon: ClipboardList,
    color: "#60a5fa",
    bg: "rgba(96,165,250,0.1)",
    border: "rgba(96,165,250,0.2)",
  },
  {
    key: "pending",
    title: "Pending Approval",
    icon: ClipboardList,
    color: "#fbbf24",
    bg: "rgba(251,191,36,0.1)",
    border: "rgba(251,191,36,0.2)",
  },
  {
    key: "active",
    title: "Active Trips",
    icon: MapPin,
    color: "#fb923c",
    bg: "rgba(251,146,60,0.1)",
    border: "rgba(251,146,60,0.2)",
  },
  {
    key: "drivers",
    title: "Available Drivers",
    icon: Users,
    color: "#4ade80",
    bg: G_DIM,
    border: G_BRD,
  },
  {
    key: "trucks",
    title: "Available Trucks",
    icon: Truck,
    color: "#a78bfa",
    bg: "rgba(167,139,250,0.1)",
    border: "rgba(167,139,250,0.2)",
  },
];

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

/* ─────────── main component ─────────── */

export default function AdminDashboard() {

  const { data: bookings  = [] } = useFirestoreCollection("bookings");
  const { data: allUsers  = [] } = useFirestoreCollection("users");
  const { data: trucks    = [] } = useFirestoreCollection("trucks");

  const users   = allUsers;
  const drivers = allUsers.filter((u) => u.role === "driver");

  /* ── helpers ── */
  const formatTruckType = (type) => {
    if (!type) return "-";
    const safeType = typeof type === "string" ? type : type?.type || "-";
    if (typeof safeType !== "string") return "-";
    return safeType.split("_").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  };

  const getCustomerName = (b) =>
    b.customer?.fullName || b.customer_name || b.customerName ||
    users.find((u) => u.id === b.userId)?.fullName || "N/A";

  const getBookingType = (b) =>
    formatTruckType(b.truckType?.type || b.truck?.type || b.truckType || b.assigned_truck_type);

  const getBookingDate = (b) =>
    b.schedule_date ||
    (b.schedule?.seconds ? format(new Date(b.schedule.seconds * 1000), "MMM d, yyyy") : "-");

  /* ── stats ── */
  const activeTrips = bookings.filter((b) =>
    ["approved", "assigned", "accepted", "en_route_to_pickup", "arrived_at_pickup", "in_transit"].includes(b.status)
  ).length;

  const statValues = {
    total:   bookings.length,
    pending: bookings.filter((b) => b.status === "pending").length,
    active:  activeTrips,
    drivers: drivers.filter((d) => d.availability === "available").length,
    trucks:  trucks.filter((t) => t.status === "available").length,
  };

  /* ── recent bookings ── */
  const recentBookings = [...bookings]
    .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
    .slice(0, 5);

  /* ══════════════ RENDER ══════════════ */
  return (
    <div style={{ fontFamily: "'DM Sans',sans-serif", background: DARK, minHeight: "100vh", padding: "28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .adash * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .adash h1 { font-family:'Sora',sans-serif; }
        .adash-table { width:100%; border-collapse:collapse; }
        .adash-thead th { background:${CARD2}; color:#475569; font-size:10px; font-weight:700;
          text-transform:uppercase; letter-spacing:0.08em; padding:12px 16px; text-align:left;
          border-bottom:1px solid ${BORDER}; white-space:nowrap; }
        .adash-row { border-bottom:1px solid ${BORDER}; transition:background 0.14s; }
        .adash-row:last-child { border-bottom:none; }
        .adash-row:hover { background:rgba(255,255,255,0.025); }
        .adash-td { padding:12px 16px; vertical-align:middle; }
        .adash-stat { display:flex; flex-direction:column; gap:12px;
          background:${CARD}; border-radius:14px; padding:18px 20px;
          transition:border 0.18s; cursor:default; }
        .adash-stat:hover { border-color:rgba(255,255,255,0.12) !important; }
        .adash-view-link { display:inline-flex; align-items:center; gap:5px;
          font-size:12px; font-weight:600; color:#60a5fa; text-decoration:none;
          transition:color 0.15s; }
        .adash-view-link:hover { color:#93c5fd; }
      `}</style>

      <div className="adash" style={{ display: "flex", flexDirection: "column", gap: 24 }}>

        {/* ══ HEADER ══ */}
        <div>
          <h1 style={{ fontSize: 28, fontWeight: 800, color: "#f1f5f9", margin: 0 }}>Admin Dashboard</h1>
          <p style={{ color: "#64748b", fontSize: 14, margin: "4px 0 0" }}>
            Monitor bookings, fleet activity, and driver performance in real time
          </p>
        </div>

        {/* ══ STAT CARDS ══ */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 14 }}>
          {STAT_CONFIG.map(({ key, title, icon: Icon, color, bg, border }) => (
            <div
              key={key}
              className="adash-stat"
              style={{ border: `1px solid ${border}` }}
            >
              {/* icon + title */}
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 9,
                  background: bg, border: `1px solid ${border}`,
                  display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                }}>
                  <Icon size={16} style={{ color }} />
                </div>
                <p style={{ fontSize: 12, color: "#64748b", fontWeight: 600, margin: 0, lineHeight: 1.3 }}>
                  {title}
                </p>
              </div>

              {/* value */}
              <p style={{ fontSize: 30, fontWeight: 800, color, margin: 0, fontFamily: "'Sora',sans-serif", lineHeight: 1 }}>
                {statValues[key]}
              </p>
            </div>
          ))}
        </div>

        {/* ══ RECENT BOOKINGS ══ */}
        <div style={{ background: CARD, border: `1px solid ${BORDER}`, borderRadius: 16, overflow: "hidden" }}>

          {/* section header */}
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "space-between",
            padding: "16px 20px", borderBottom: `1px solid ${BORDER}`,
          }}>
            <div>
              <p style={{ fontSize: 10, color: "#4ade80", fontWeight: 700, letterSpacing: "0.14em",
                textTransform: "uppercase", margin: "0 0 2px" }}>Overview</p>
              <p style={{ fontSize: 15, fontWeight: 700, color: "#f1f5f9", margin: 0 }}>Recent Bookings</p>
            </div>
            <Link to="/admin/bookings" className="adash-view-link">
              View all
              <ArrowRight size={13} />
            </Link>
          </div>

          {/* table */}
          <div style={{ overflowX: "auto" }}>
            <table className="adash-table">
              <thead className="adash-thead">
                <tr>
                  {["Customer", "Route", "Date", "Truck", "Status"].map((h) => (
                    <th key={h}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {recentBookings.length === 0 && (
                  <tr>
                    <td colSpan={5} className="adash-td" style={{ textAlign: "center", color: "#334155", fontSize: 13, padding: "48px 16px" }}>
                      No recent bookings available.
                    </td>
                  </tr>
                )}
                {recentBookings.map((b) => (
                  <tr key={b.id} className="adash-row">

                    {/* CUSTOMER */}
                    <td className="adash-td" style={{ whiteSpace: "nowrap" }}>
                      <p style={{ fontSize: 13, fontWeight: 600, color: "#f1f5f9", margin: 0 }}>
                        {getCustomerName(b)}
                      </p>
                    </td>

                    {/* ROUTE */}
                    <td className="adash-td" style={{ maxWidth: 200 }}>
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
                    <td className="adash-td" style={{ fontSize: 11, color: "#64748b", whiteSpace: "nowrap" }}>
                      {getBookingDate(b)}
                    </td>

                    {/* TRUCK */}
                    <td className="adash-td">
                      <span style={{
                        fontSize: 11, fontWeight: 600, color: "#60a5fa",
                        background: "rgba(96,165,250,0.1)", border: "1px solid rgba(96,165,250,0.25)",
                        borderRadius: 5, padding: "2px 8px",
                      }}>
                        {getBookingType(b)}
                      </span>
                    </td>

                    {/* STATUS */}
                    <td className="adash-td">
                      <StatusPill status={b.status} />
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