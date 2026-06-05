import React, { useState, useMemo } from "react";
import { useFirestoreCollection } from "@/lib/useFirestoreCollection";
import {
  ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  AreaChart, Area, Tooltip, Legend,
} from "recharts";
import {
  ClipboardList, CheckCircle2, XCircle, TrendingUp, PhilippinePeso,
  Truck, Download, Calendar, MapPin, Activity,
  Users, UserCheck, Star,
} from "lucide-react";

const G      = "#16A34A";
const G_DIM  = "rgba(22,163,74,0.15)";
const G_BRD  = "rgba(22,163,74,0.30)";
const DARK   = "#0B0F1A";
const CARD   = "#111827";
const CARD2  = "#0f172a";
const BORDER = "rgba(255,255,255,0.07)";
const MONTHS_ORDER = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const DAYS = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

const fmt = (n) =>
  new Intl.NumberFormat("en-PH",{ style:"currency", currency:"PHP", maximumFractionDigits:0 }).format(n);
const fmtShort = (n) => n >= 1000 ? `₱${(n/1000).toFixed(1)}k` : `₱${n.toFixed(0)}`;
const fmtType = (type) => {
  if (!type) return "-";
  if (typeof type === "object") type = type.type || type.name || "";
  if (typeof type !== "string") return "-";
  return type.split("_").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
};
const pct = (a, b) => (b > 0 ? ((a / b) * 100).toFixed(1) : "0.0");

const DarkTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{ background:"#1e293b", border:`1px solid ${BORDER}`, borderRadius:10, padding:"10px 14px", minWidth:120 }}>
      {label && <p style={{ color:"#94a3b8", fontSize:11, marginBottom:6 }}>{label}</p>}
      {payload.map((p,i) => (
        <p key={i} style={{ color: p.color||"#4ade80", fontSize:13, fontWeight:600, margin:"2px 0" }}>
          {p.name}:{" "}
          {typeof p.value === "number" && (p.name?.toLowerCase().includes("revenue") || p.name?.toLowerCase().includes("₱"))
            ? fmt(p.value) : p.value}
        </p>
      ))}
    </div>
  );
};

const Section = ({ label, title, icon: Icon, children, style={} }) => (
  <div style={{ background:CARD, border:`1px solid ${BORDER}`, borderRadius:16,
    boxShadow:"0 4px 24px rgba(0,0,0,0.3)", ...style }}>
    <div style={{ padding:"18px 20px 14px", borderBottom:`1px solid ${BORDER}` }}>
      <p style={{ color:"#4ade80", fontSize:10, fontWeight:700, letterSpacing:"0.18em",
        textTransform:"uppercase", margin:"0 0 6px" }}>{label}</p>
      <p style={{ fontSize:15, fontWeight:700, color:"#f1f5f9", margin:0,
        display:"flex", alignItems:"center", gap:8 }}>
        {Icon && <Icon size={15} style={{ color:"#4ade80" }} />}{title}
      </p>
    </div>
    <div style={{ padding:20 }}>{children}</div>
  </div>
);

const RankRow = ({ rank, label, sub, value, valueSub, max, accent=false }) => (
  <div style={{ marginBottom:14 }}>
    <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:6 }}>
      <div style={{ display:"flex", alignItems:"center", gap:10, minWidth:0 }}>
        <span style={{ width:22, height:22, borderRadius:6, flexShrink:0, display:"flex",
          alignItems:"center", justifyContent:"center", fontSize:10, fontWeight:700,
          background: accent ? G_DIM : "rgba(255,255,255,0.05)",
          border:`1px solid ${accent ? G_BRD : BORDER}`,
          color: accent ? "#4ade80" : "#64748b" }}>
          {rank}
        </span>
        <div style={{ minWidth:0 }}>
          <p style={{ fontSize:13, color:"#cbd5e1", fontWeight:600, margin:0,
            overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", maxWidth:260 }}
            title={label}>{label}</p>
          {sub && <p style={{ fontSize:11, color:"#475569", margin:0 }}>{sub}</p>}
        </div>
      </div>
      <div style={{ flexShrink:0, textAlign:"right", marginLeft:12 }}>
        <p style={{ fontSize:13, fontWeight:700, color: accent ? "#4ade80" : "#94a3b8", margin:0 }}>{value}</p>
        {valueSub && <p style={{ fontSize:11, color:"#475569", margin:0 }}>{valueSub}</p>}
      </div>
    </div>
    <div style={{ height:5, background:"rgba(255,255,255,0.05)", borderRadius:4 }}>
      <div style={{ height:"100%", borderRadius:4, width:`${Math.min((value/(max||1))*100,100)}%`,
        background:`linear-gradient(90deg, ${G}, #4ade80)`, transition:"width 0.6s ease" }} />
    </div>
  </div>
);

export default function AdminReports() {
  const { data: bookings = [] } = useFirestoreCollection("bookings");
  const { data: dispatchLogs = [] } = useFirestoreCollection("dispatch_log");

  const now = new Date();
  const [range, setRange] = useState("all");
  const rangeOptions = [
    { label:"All Time",      value:"all"     },
    { label:"This Month",    value:"month"   },
    { label:"Last 3 Months", value:"3months" },
    { label:"This Year",     value:"year"    },
  ];

  const filtered = useMemo(() => {
    if (range === "all") return bookings;
    return bookings.filter((b) => {
      if (!b.createdAt?.seconds) return false;
      const d = new Date(b.createdAt.seconds * 1000);
      if (range === "month")   return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
      if (range === "3months") return d >= new Date(now.getFullYear(), now.getMonth()-2, 1);
      if (range === "year")    return d.getFullYear() === now.getFullYear();
      return true;
    });
  }, [bookings, range]);

  const total     = filtered.length;
  const completed = filtered.filter(b => b.status === "completed" || b.status === "delivered").length;
  const cancelled = filtered.filter(b => b.status === "cancelled").length;
  const active    = filtered.filter(b =>
    ["assigned","accepted","en_route_to_pickup","arrived_at_pickup","in_transit"].includes(b.status)
  ).length;
  const revenue = filtered
    .filter(b => b.status === "completed" || b.status === "delivered")
    .reduce((s,b) => s + (b.estimatedCost||0), 0);
  const completeRate = pct(completed, total);

  const monthlyData = useMemo(() => {
    const monthMap = {};
    filtered.forEach(b => {
      if (!b.createdAt?.seconds) return;
      const key = new Date(b.createdAt.seconds * 1000).toLocaleString("default", { month: "short" });
      if (!monthMap[key]) monthMap[key] = { bookings: 0, revenue: 0 };
      monthMap[key].bookings++;
      const revenueDate = b.completedAt?.seconds
        ? new Date(b.completedAt.seconds * 1000)
        : new Date(b.createdAt.seconds * 1000);
      const revenueKey = revenueDate.toLocaleString("default", { month: "short" });
      if (b.status === "completed" || b.status === "delivered") {
        if (!monthMap[revenueKey]) monthMap[revenueKey] = { bookings: 0, revenue: 0 };
        monthMap[revenueKey].revenue += b.estimatedCost || 0;
      }
    });
    return MONTHS_ORDER.filter(m => monthMap[m]).map(m => ({ month: m, ...monthMap[m] }));
  }, [filtered]);

  const funnelStages = [
    { label:"Pending",    count: filtered.filter(b=>b.status==="pending").length,     color:"#FBBF24" },
    { label:"Assigned",   count: filtered.filter(b=>["assigned","accepted"].includes(b.status)).length, color:"#3B82F6" },
    { label:"In Transit", count: filtered.filter(b=>["en_route_to_pickup","arrived_at_pickup","in_transit"].includes(b.status)).length, color:"#A78BFA" },
    { label:"Completed",  count: completed, color:G },
    { label:"Cancelled",  count: cancelled, color:"#EF4444" },
  ];
  const funnelMax = total||1;

  const dayMap = { Sun:0,Mon:0,Tue:0,Wed:0,Thu:0,Fri:0,Sat:0 };
  filtered.forEach(b => {
    if (!b.createdAt?.seconds) return;
    dayMap[DAYS[new Date(b.createdAt.seconds*1000).getDay()]]++;
  });
  const dayData = DAYS.map(d => ({ day:d, bookings:dayMap[d] }));

  const truckMap = {};
  filtered.forEach(b => {
    const t = fmtType(b.truckType?.type || b.truckType || b.assigned_truck_type || b.truck?.type);
    if (!t||t==="-") return;
    if (!truckMap[t]) truckMap[t] = { bookings:0 };
    truckMap[t].bookings++;
  });
  const truckData = Object.entries(truckMap)
    .map(([name,v]) => ({ name, ...v }))
    .sort((a,b) => b.bookings - a.bookings);

  const routeMap = {};
  filtered.forEach(b => {
    const pickup = b.pickupLocation||b.pickup;
    const dest   = b.destination;
    if (!pickup||!dest) return;
    const key = `${pickup} → ${dest}`;
    if (!routeMap[key]) routeMap[key] = { count:0 };
    routeMap[key].count++;
  });
  const topRoutes = Object.entries(routeMap)
    .map(([route,v]) => ({ route, ...v }))
    .sort((a,b) => b.count - a.count)
    .slice(0,5);
  const maxFreq = topRoutes[0]?.count||1;

  const custMap = {};
  filtered.forEach(b => {
    const id   = b.userId||b.customer?.email||"unknown";
    const name = b.customer?.fullName||b.customerName||"Unknown";
    if (!custMap[id]) custMap[id] = { name, bookings:0, cancelled:0 };
    custMap[id].bookings++;
    if (b.status==="cancelled") custMap[id].cancelled++;
  });
  const topCustomers = Object.values(custMap).sort((a,b)=>b.bookings-a.bookings).slice(0,5);
  const maxCustBookings = topCustomers[0]?.bookings||1;

  /* ══ TOP DRIVERS ══
   *
   * SOURCE OF TRUTH: dispatch_log events, replayed per booking in time order.
   *
   * Desired behaviour (your spec):
   *
   *   Scenario A — driver rejects:
   *     Before reject : 3 assigned, 3 completed → 100%
   *     After reject  : 4 assigned, 3 completed → 75%   (assigned stays, rate drops)
   *
   *   Scenario B — rejected trip gets reassigned to Driver B:
   *     Driver A stays : 4 assigned, 3 completed → 75%  (no change — they did get that assignment)
   *     Driver B gets  : 1 assigned, 1 completed → 100% (fresh slate)
   *
   *   Scenario C — admin silently re-routes trip (no rejection log):
   *     Driver A loses : assigned-- (the trip was taken without a rejection, so it shouldn't count)
   *
   * Rules implemented:
   *   1. Every time a driver appears as assignee in a log row → assigned++
   *      REGARDLESS of decision, because the system did assign it to them.
   *   2. decision === "rejected" → rejected++   (assigned already incremented above)
   *   3. If a NEW driver takes over and the PREVIOUS driver did NOT reject
   *      (i.e. was silently reassigned away) → previous driver's assigned--
   *      because they never got a real chance to act on it.
   *   4. completed + revenue → credited to whoever holds assigned_driver_id
   *      on the final booking document.
   ══ */
  const topDrivers = useMemo(() => {
    const filteredIds = new Set(filtered.map(b => b.id));

    const nameById = {};
    filtered.forEach(b => {
      const id = b.assigned_driver_id || b.assigned_driver_email;
      if (id) nameById[id] = b.assigned_driver_name || id;
    });

    const logsByBooking = {};
    dispatchLogs.forEach(log => {
      const bid = log.bookingId || log.booking_id;
      if (!bid || !filteredIds.has(bid)) return;
      if (!logsByBooking[bid]) logsByBooking[bid] = [];
      logsByBooking[bid].push(log);
    });

    Object.values(logsByBooking).forEach(logs =>
      logs.sort((a, b) => {
        const ta = a.createdAt?.seconds ?? a.timestamp?.seconds ?? 0;
        const tb = b.createdAt?.seconds ?? b.timestamp?.seconds ?? 0;
        return ta - tb;
      })
    );

    const dm = {};
    const ensure = (id, name) => {
      if (!dm[id]) dm[id] = { name: name || nameById[id] || id, assigned: 0, completed: 0, rejected: 0, revenue: 0 };
    };

    Object.entries(logsByBooking).forEach(([bid, logs]) => {
      // currentAssignee = the driver who most recently received this booking
      // currentRejected = whether that driver explicitly rejected it
      let currentAssignee = null;
      let currentRejected = false;

      logs.forEach(log => {
        const id   = log.assigned_driver_id || log.assigned_driver_email;
        const name = log.assigned_driver_name || nameById[id] || id;
        if (!id) return;

        ensure(id, name);

        if (id !== currentAssignee) {
          // A different driver is now on this booking.
          // If the previous driver did NOT reject (was silently taken away),
          // undo their assigned++ because they never truly owned the trip.
          if (currentAssignee !== null && !currentRejected) {
            dm[currentAssignee].assigned--;
          }
          // Count this new assignment
          dm[id].assigned++;
          currentAssignee = id;
          currentRejected = false;
        }

        if (log.decision === "rejected") {
          dm[id].rejected++;
          currentRejected = true;
          // assigned stays — they received the trip and chose to reject it.
          // The next driver will get their own +assigned when they appear.
        }
        // Any other decision (accepted / confirmed / null) — assigned already
        // incremented above; nothing extra needed.
      });
    });

    // For bookings that have NO dispatch_log rows (legacy data), fall back to
    // reading assigned_driver_id directly from the booking document.
    filtered.forEach(b => {
      const bid = b.id;
      if (logsByBooking[bid]) return; // already handled above

      const id   = b.assigned_driver_id || b.assigned_driver_email;
      const name = b.assigned_driver_name || id;
      if (!id) return;

      ensure(id, name);
      dm[id].assigned++;
    });

    // Credit completed trips & revenue to whoever is currently assigned on the booking
    filtered.forEach(b => {
      if (b.status !== "completed" && b.status !== "delivered") return;
      const id = b.assigned_driver_id || b.assigned_driver_email;
      if (!id) return;
      ensure(id, b.assigned_driver_name || id);
      dm[id].completed++;
      dm[id].revenue += b.estimatedCost || 0;
    });

    return Object.values(dm)
      .sort((a, b) => b.completed - a.completed)
      .slice(0, 5);
  }, [filtered, dispatchLogs]);

  const momDelta = (key) => {
    if (monthlyData.length < 2) return null;
    const last = monthlyData[monthlyData.length - 1][key];
    const prev = monthlyData[monthlyData.length - 2][key];
    if (prev === 0) return null;
    return (((last - prev) / prev) * 100).toFixed(1);
  };
  const bookingDelta = momDelta("bookings");
  const revenueDelta = momDelta("revenue");
  const lastMonthRev = monthlyData.length ? monthlyData[monthlyData.length - 1].revenue : 0;

  const exportCSV = () => {
    const headers = ["ID","Customer","Pickup","Destination","Truck Type","Status","Estimated Cost","Distance (km)","Driver","Plate","Date"];
    const rows = filtered.map(b => [
      b.id||"", b.customer?.fullName||b.customerName||"",
      b.pickupLocation||b.pickup||"", b.destination||"",
      fmtType(b.truckType?.type||b.truckType||""), b.status||"",
      b.estimatedCost||0, b.estimatedDistance||0,
      b.assigned_driver_name||"", b.assigned_truck_plate_number||"",
      b.createdAt?.seconds ? new Date(b.createdAt.seconds*1000).toLocaleDateString() : "",
    ]);
    const csv = [headers,...rows].map(r=>r.map(v=>`"${v}"`).join(",")).join("\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([csv],{type:"text/csv"}));
    a.download = `smarttruck-report-${range}.csv`;
    a.click();
  };

  return (
    <div style={{ fontFamily:"'DM Sans',sans-serif", background:DARK, minHeight:"100vh", padding:"28px 24px" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');
        .rpt * { font-family:'DM Sans',sans-serif; box-sizing:border-box; }
        .rpt h1 { font-family:'Sora',sans-serif; }
        .rbtn { background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.08); color:#64748b;
          border-radius:8px; padding:6px 14px; font-size:13px; font-weight:500; cursor:pointer;
          transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .rbtn:hover { color:#cbd5e1; border-color:rgba(255,255,255,0.14); }
        .rbtn.on { background:rgba(22,163,74,0.15); border-color:rgba(22,163,74,0.4); color:#4ade80; }
        .expbtn { display:flex; align-items:center; gap:7px; background:rgba(22,163,74,0.15);
          border:1px solid rgba(22,163,74,0.35); color:#4ade80; border-radius:10px; padding:9px 18px;
          font-size:13px; font-weight:600; cursor:pointer; transition:all 0.18s; font-family:'DM Sans',sans-serif; }
        .expbtn:hover { background:rgba(22,163,74,0.25); }
        .kpi { border-radius:14px; padding:18px; display:flex; flex-direction:column; gap:8px;
          background:${CARD}; border:1px solid ${BORDER}; }
        .g2 { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
        @media(max-width:900px){ .g2{ grid-template-columns:1fr; } }
        .mom-pill { margin:10px 0 0; font-size:12px; display:flex; align-items:center; gap:4px; }
      `}</style>

      <div className="rpt" style={{ display:"flex", flexDirection:"column", gap:20 }}>

        <div style={{ display:"flex", alignItems:"flex-start", justifyContent:"space-between", flexWrap:"wrap", gap:16 }}>
          <div>
            <h1 style={{ fontSize:28, fontWeight:800, color:"#f1f5f9", margin:0 }}>Reports & Analytics</h1>
            <p style={{ color:"#64748b", fontSize:14, marginTop:4, margin:0 }}>Operational insights derived from bookings data</p>
          </div>
          <button className="expbtn" onClick={exportCSV}><Download size={15}/> Export CSV</button>
        </div>

        <div style={{ display:"flex", alignItems:"center", gap:8, flexWrap:"wrap" }}>
          <Calendar size={14} style={{ color:"#475569" }}/>
          {rangeOptions.map(r => (
            <button key={r.value} className={`rbtn${range===r.value?" on":""}`} onClick={()=>setRange(r.value)}>
              {r.label}
            </button>
          ))}
        </div>

        <div style={{ display:"grid", gridTemplateColumns:"repeat(auto-fit,minmax(148px,1fr))", gap:12 }}>
          {[
            { label:"Total Bookings",  value:total,             color:"#f1f5f9", accent:"#64748b", Icon:ClipboardList },
            { label:"Completed",       value:completed,         color:"#4ade80", accent:G,          Icon:CheckCircle2 },
            { label:"Cancelled",       value:cancelled,         color:"#f87171", accent:"#ef4444",  Icon:XCircle      },
            { label:"Active Now",      value:active,            color:"#fbbf24", accent:"#f59e0b",  Icon:TrendingUp   },
            { label:"Completion Rate", value:`${completeRate}%`,color:"#34d399", accent:G,          Icon:Activity     },
            { label:"Total Revenue",   value:fmt(revenue),      color:"#4ade80", accent:G,          Icon:PhilippinePeso},
          ].map(s => (
            <div key={s.label} className="kpi">
              <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between" }}>
                <span style={{ fontSize:10, color:"#64748b", fontWeight:700, textTransform:"uppercase", letterSpacing:"0.07em" }}>{s.label}</span>
                <s.Icon size={14} style={{ color:s.accent }}/>
              </div>
              <p style={{ fontSize:20, fontWeight:800, color:s.color, margin:0, fontFamily:"'Sora',sans-serif",
                overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{s.value}</p>
            </div>
          ))}
        </div>

        <div className="g2">
          <Section label="Trends" title="Monthly Booking Volume" icon={ClipboardList}>
            <div style={{ height:260 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={monthlyData} barSize={28}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false}/>
                  <XAxis dataKey="month" fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <YAxis fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false} allowDecimals={false}/>
                  <Tooltip content={<DarkTooltip/>} cursor={{ fill:"rgba(255,255,255,0.04)" }}/>
                  <Bar dataKey="bookings" name="Bookings" radius={[6,6,0,0]} fill={G}/>
                </BarChart>
              </ResponsiveContainer>
            </div>
            {bookingDelta !== null && (
              <p className="mom-pill" style={{ color: parseFloat(bookingDelta) >= 0 ? "#4ade80" : "#f87171" }}>
                {parseFloat(bookingDelta) >= 0 ? "▲" : "▼"} {Math.abs(bookingDelta)}% vs last month
              </p>
            )}
          </Section>

          <Section label="Trends" title="Monthly Revenue" icon={PhilippinePeso}>
            <div style={{ height:260 }}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={monthlyData}>
                  <defs>
                    <linearGradient id="gRev" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#3B82F6" stopOpacity={0.25}/>
                      <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false}/>
                  <XAxis dataKey="month" fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <YAxis fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false} tickFormatter={v=>`₱${(v/1000).toFixed(0)}k`}/>
                  <Tooltip content={<DarkTooltip/>} cursor={{ stroke:"rgba(255,255,255,0.07)", strokeWidth:1 }}/>
                  <Area type="monotone" dataKey="revenue" name="Revenue" stroke="#3B82F6" strokeWidth={2.5} fill="url(#gRev)" dot={{ fill:"#3B82F6", r:3 }} activeDot={{ r:5 }}/>
                </AreaChart>
              </ResponsiveContainer>
            </div>
            {revenueDelta !== null && (
              <p className="mom-pill" style={{ color: parseFloat(revenueDelta) >= 0 ? "#4ade80" : "#f87171" }}>
                {parseFloat(revenueDelta) >= 0 ? "▲" : "▼"} {Math.abs(revenueDelta)}% vs last month
                <span style={{ color:"#475569", fontWeight:400 }}> · {fmt(lastMonthRev)} this month</span>
              </p>
            )}
          </Section>
        </div>

        <div className="g2">
          <Section label="Pipeline" title="Booking Status Funnel" icon={Activity}>
            <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
              {funnelStages.map(s => (
                <div key={s.label}>
                  <div style={{ display:"flex", justifyContent:"space-between", marginBottom:5 }}>
                    <span style={{ fontSize:13, color:"#cbd5e1", fontWeight:500 }}>{s.label}</span>
                    <span style={{ fontSize:13, fontWeight:700, color:s.color }}>
                      {s.count} <span style={{ color:"#475569", fontWeight:400, fontSize:11 }}>({pct(s.count,funnelMax)}%)</span>
                    </span>
                  </div>
                  <div style={{ height:8, background:"rgba(255,255,255,0.05)", borderRadius:4 }}>
                    <div style={{ height:"100%", width:`${pct(s.count,funnelMax)}%`, background:s.color, borderRadius:4, transition:"width 0.6s ease", opacity:0.85 }}/>
                  </div>
                </div>
              ))}
            </div>
          </Section>

          <Section label="Booking Patterns" title="Bookings by Day of Week" icon={Calendar}>
            <div style={{ height:240 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={dayData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)"/>
                  <XAxis dataKey="day" fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <YAxis fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <Tooltip content={<DarkTooltip/>} cursor={{ fill:"rgba(255,255,255,0.04)" }}/>
                  <Bar dataKey="bookings" name="Bookings" radius={[5,5,0,0]} fill={G}/>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>
        </div>

        <div className="g2">
          <Section label="Fleet Analytics" title="Bookings by Truck Type" icon={Truck}>
            <div style={{ height:260 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={truckData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)"/>
                  <XAxis dataKey="name" fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <YAxis fontSize={11} tick={{ fill:"#64748b" }} axisLine={false} tickLine={false}/>
                  <Tooltip content={<DarkTooltip/>} cursor={{ fill:"rgba(255,255,255,0.04)" }}/>
                  <Bar dataKey="bookings" name="Bookings" radius={[5,5,0,0]} fill={G}/>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section label="Route Analytics" title="Top Routes by Frequency" icon={MapPin}>
            {topRoutes.length === 0
              ? <p style={{ color:"#475569", textAlign:"center", padding:"32px 0", fontSize:13 }}>No data</p>
              : topRoutes.map((r,i) => (
                <RankRow key={r.route} rank={i+1} label={r.route} value={r.count} valueSub="trips" max={maxFreq} accent={i===0}/>
              ))
            }
          </Section>
        </div>

        <div className="g2">
          <Section label="Customer Insights" title="Top Customers by Bookings" icon={Users}>
            {topCustomers.length === 0
              ? <p style={{ color:"#475569", textAlign:"center", padding:"32px 0", fontSize:13 }}>No data</p>
              : topCustomers.map((c,i) => (
                <RankRow key={c.name+i} rank={i+1} label={c.name}
                  sub={c.cancelled > 0 ? `${c.cancelled} cancellation${c.cancelled!==1?"s":""}` : null}
                  value={c.bookings} valueSub="bookings" max={maxCustBookings} accent={i===0}/>
              ))
            }
          </Section>

          <Section label="Driver Performance" title="Top Drivers by Completed Trips" icon={UserCheck}>
            {topDrivers.length === 0
              ? <p style={{ color:"#475569", textAlign:"center", padding:"32px 0", fontSize:13 }}>No driver data</p>
              : <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
                  {topDrivers.map((d,i) => (
                    <div key={d.name+i} style={{ background:CARD2, border:`1px solid ${BORDER}`,
                      borderRadius:12, padding:"12px 14px", display:"flex", alignItems:"center", gap:12 }}>
                      <div style={{ width:34, height:34, borderRadius:9, flexShrink:0,
                        background: i===0 ? G_DIM : "rgba(255,255,255,0.05)",
                        border:`1px solid ${i===0 ? G_BRD : BORDER}`,
                        display:"flex", alignItems:"center", justifyContent:"center",
                        fontSize:13, fontWeight:700, color: i===0 ? "#4ade80" : "#64748b" }}>
                        {d.name.charAt(0).toUpperCase()}
                      </div>
                      <div style={{ flex:1, minWidth:0 }}>
                        <p style={{ fontSize:13, fontWeight:700, color:"#f1f5f9", margin:"0 0 2px",
                          overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{d.name}</p>
                        <p style={{ fontSize:11, color:"#475569", margin:0 }}>
                          {d.assigned} assigned · {d.completed} completed
                          {d.rejected > 0 && (
                            <span style={{ color:"#fb923c" }}> · {d.rejected} rejected</span>
                          )}
                        </p>
                      </div>
                      <div style={{ flexShrink:0, textAlign:"right" }}>
                        {/* Rate = completed / assigned — rejections already removed from assigned */}
                        <p style={{ fontSize:13, fontWeight:700, color:"#4ade80", margin:"0 0 2px" }}>
                          {pct(d.completed, d.assigned)}%
                        </p>
                        <p style={{ fontSize:11, color:"#475569", margin:0 }}>
                          {d.revenue > 0 ? fmtShort(d.revenue) : "—"}
                        </p>
                      </div>
                      {i===0 && <Star size={12} style={{ color:"#fbbf24", flexShrink:0 }}/>}
                    </div>
                  ))}
                </div>
            }
          </Section>
        </div>

      </div>
    </div>
  );
}