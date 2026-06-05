import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '@/firebase/config.js';
import { Truck, Lock, Mail, ArrowRight, AlertCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const [email, setEmail]       = useState('');
  const [password, setPassword] = useState('');
  const [error, setError]       = useState(null);
  const [loading, setLoading]   = useState(false);
  const navigate = useNavigate();

  // ── Enter key now works because this is called by onSubmit ──
  const handleLogin = async (e) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      navigate('/admin');
    } catch (err) {
      setError('Invalid email or password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ fontFamily: "'DM Sans', 'Sora', sans-serif" }}
      className="min-h-screen flex bg-[#0B0F1A]">

      {/* ── Google Fonts ── */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&family=Sora:wght@700;800&display=swap');

        .input-field {
          width: 100%;
          background: rgba(255,255,255,0.04);
          border: 1px solid rgba(255,255,255,0.10);
          border-radius: 10px;
          color: #f1f5f9;
          padding: 11px 14px 11px 40px;
          font-size: 14px;
          font-family: 'DM Sans', sans-serif;
          outline: none;
          transition: border-color 0.2s, box-shadow 0.2s;
        }
        .input-field::placeholder { color: rgba(255,255,255,0.28); }
        .input-field:focus {
          border-color: #16A34A;
          box-shadow: 0 0 0 3px rgba(22,163,74,0.18);
        }

        .login-btn {
          width: 100%;
          background: #16A34A;
          color: #fff;
          border: none;
          border-radius: 10px;
          padding: 12px;
          font-size: 15px;
          font-weight: 600;
          font-family: 'DM Sans', sans-serif;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          transition: background 0.2s, transform 0.15s;
          letter-spacing: 0.01em;
        }
        .login-btn:hover:not(:disabled) { background: #15803d; transform: translateY(-1px); }
        .login-btn:active:not(:disabled) { transform: translateY(0); }
        .login-btn:disabled { opacity: 0.55; cursor: not-allowed; }

        /* animated truck track lines */
        @keyframes slide {
          0%   { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
        .track-lines {
          animation: slide 18s linear infinite;
        }

        /* fade-up on mount */
        @keyframes fadeUp {
          from { opacity:0; transform:translateY(18px); }
          to   { opacity:1; transform:translateY(0); }
        }
        .fade-up { animation: fadeUp 0.55s ease both; }
        .fade-up-d1 { animation-delay: 0.08s; }
        .fade-up-d2 { animation-delay: 0.16s; }
        .fade-up-d3 { animation-delay: 0.24s; }
        .fade-up-d4 { animation-delay: 0.32s; }
      `}</style>

      {/* ══════════════ LEFT BRAND PANEL ══════════════ */}
      <div className="hidden lg:flex w-[52%] relative overflow-hidden flex-col justify-between p-14"
        style={{ background: 'linear-gradient(145deg, #0d1a0f 0%, #0B0F1A 60%, #111827 100%)' }}>

        {/* Subtle grid texture */}
        <div className="absolute inset-0 opacity-[0.06]"
          style={{
            backgroundImage: 'linear-gradient(rgba(255,255,255,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.6) 1px, transparent 1px)',
            backgroundSize: '48px 48px',
          }} />

        {/* Animated road track */}
        <div className="absolute bottom-24 left-0 right-0 overflow-hidden h-[3px] opacity-20">
          <div className="track-lines flex h-full" style={{ width: '200%' }}>
            {Array.from({ length: 40 }).map((_, i) => (
              <div key={i} className="h-full mx-3"
                style={{ width: 32, background: '#16A34A', borderRadius: 2 }} />
            ))}
          </div>
        </div>

        {/* Green accent glow */}
        <div className="absolute top-1/3 left-1/4 w-72 h-72 rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, #16A34A 0%, transparent 70%)' }} />

        {/* Logo */}
        <div className="relative flex items-center gap-3 z-10">
          <div className="w-10 h-10 rounded-xl flex items-center justify-center"
            style={{ background: 'rgba(22,163,74,0.18)', border: '1px solid rgba(22,163,74,0.35)' }}>
            <Truck className="w-5 h-5 text-green-400" />
          </div>
          <span className="text-white font-bold text-lg tracking-tight"
            style={{ fontFamily: "'Sora', sans-serif" }}>
            SmartTruck
          </span>
          <span className="ml-1 text-[10px] font-semibold px-2 py-0.5 rounded-full uppercase tracking-widest"
            style={{ background: 'rgba(22,163,74,0.18)', color: '#4ade80', border: '1px solid rgba(22,163,74,0.3)' }}>
            Admin
          </span>
        </div>

        {/* Hero copy */}
        <div className="relative z-10">
          <p className="text-green-400 text-xs font-semibold uppercase tracking-widest mb-4">
            Fleet Management System
          </p>
          <h2 className="text-white leading-[1.15] mb-6"
            style={{ fontFamily: "'Sora', sans-serif", fontSize: 42, fontWeight: 800 }}>
            Control your<br />logistics<br />
            <span style={{
              background: 'linear-gradient(90deg, #4ade80, #16A34A)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
            }}>operations.</span>
          </h2>
          <p className="text-slate-400 text-sm leading-relaxed max-w-xs">
            Real-time booking management, live fleet tracking, and driver oversight — all in one place.
          </p>

          {/* Feature pills */}
          <div className="flex flex-wrap gap-2 mt-8">
            {['Live Tracking', 'Fleet Management', 'Driver Oversight', 'Booking Control'].map(f => (
              <span key={f} className="text-xs px-3 py-1.5 rounded-full"
                style={{
                  background: 'rgba(255,255,255,0.05)',
                  border: '1px solid rgba(255,255,255,0.10)',
                  color: 'rgba(255,255,255,0.55)',
                }}>
                {f}
              </span>
            ))}
          </div>
        </div>

        <p className="relative z-10 text-xs text-slate-600">
          © {new Date().getFullYear()} SmartTruck System. All rights reserved.
        </p>
      </div>

      {/* ══════════════ RIGHT LOGIN PANEL ══════════════ */}
      <div className="w-full lg:w-[48%] flex items-center justify-center p-6"
        style={{ background: '#0B0F1A' }}>

        <div className="w-full max-w-sm">

          {/* Mobile logo */}
          <div className="flex lg:hidden items-center gap-2 mb-10">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ background: 'rgba(22,163,74,0.18)', border: '1px solid rgba(22,163,74,0.3)' }}>
              <Truck className="w-4 h-4 text-green-400" />
            </div>
            <span className="text-white font-bold" style={{ fontFamily: "'Sora', sans-serif" }}>
              SmartTruck
            </span>
          </div>

          {/* Heading */}
          <div className="mb-8 fade-up">
            <h2 className="text-white mb-2"
              style={{ fontFamily: "'Sora', sans-serif", fontSize: 28, fontWeight: 800 }}>
              Welcome back
            </h2>
            <p className="text-slate-500 text-sm">Sign in to your admin dashboard</p>
          </div>

          {/* ── FORM — onSubmit handles Enter key ── */}
          <form onSubmit={handleLogin} className="space-y-4" noValidate>

            {/* EMAIL */}
            <div className="fade-up fade-up-d1">
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-widest mb-2">
                Email
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="input-field"
                  placeholder="admin@smarttruck.com"
                  autoComplete="email"
                  required
                />
              </div>
            </div>

            {/* PASSWORD */}
            <div className="fade-up fade-up-d2">
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-widest mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="input-field"
                  placeholder="••••••••"
                  autoComplete="current-password"
                  required
                />
              </div>
            </div>

            {/* ERROR */}
            {error && (
              <div className="fade-up flex items-start gap-2.5 text-sm text-red-400 rounded-xl px-4 py-3"
                style={{ background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)' }}>
                <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {/* SUBMIT — type="submit" + form onSubmit = Enter key works */}
            <div className="fade-up fade-up-d3 pt-1">
              <button type="submit" disabled={loading} className="login-btn">
                {loading ? (
                  <>
                    <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
                      <circle className="opacity-25" cx="12" cy="12" r="10"
                        stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor"
                        d="M4 12a8 8 0 018-8v8H4z" />
                    </svg>
                    Signing in…
                  </>
                ) : (
                  <>
                    Sign In
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </div>

          </form>

          {/* Footer note */}
          <p className="fade-up fade-up-d4 mt-8 text-center text-xs text-slate-600">
            Access restricted to authorized administrators only.
          </p>

        </div>
      </div>
    </div>
  );
}