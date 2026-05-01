"use client";

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Loader2, Check, AlertCircle } from "lucide-react";
import AuthModal from "./AuthModal";
import { joinBetaTester, joinWaitlist, getBetaTesterCount, getMaxBetaTesters } from "@/app/actions/beta";

// Downloads Launch date: April 30, 2026 at 11:11 AM IST
const DOWNLOADS_LAUNCH_DATE = new Date("2026-04-30T11:11:00+05:30").getTime();

// Detect device architecture for APK download
function getDeviceArchitecture(): "arm64-v8a" | "armeabi-v7a" {
  if (typeof navigator === 'undefined') return "arm64-v8a";

  const userAgent = navigator.userAgent.toLowerCase();

  // Check for 64-bit ARM (most modern Android devices)
  if (userAgent.includes("arm64") || userAgent.includes("aarch64") || userAgent.includes("x86_64")) {
    return "arm64-v8a";
  }

  // Default to 32-bit ARM
  return "armeabi-v7a";
}

function handleDownloadAPK() {
  const arch = getDeviceArchitecture();
  const downloadPath = `/downloads/${arch}/oasis-${arch}.apk`;

  // Create a temporary link and trigger download
  const link = document.createElement('a');
  link.href = downloadPath;
  link.download = `oasis-${arch}.apk`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

function handleDownloadMSIX() {
  const downloadPath = `/downloads/windows/oasis-windows.msix`;

  // Create a temporary link and trigger download
  const link = document.createElement('a');
  link.href = downloadPath;
  link.download = `oasis-windows.msix`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

export default function FinalCTA() {
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [email, setEmail] = useState("");
  const [betaCount, setBetaCount] = useState<number | null>(null);
  const [isBetaFull, setIsBetaFull] = useState(false);
  const [isSignedIn, setIsSignedIn] = useState(false);
  const [maxBeta, setMaxBeta] = useState(15);
  const [isDownloadsUnlocked, setIsDownloadsUnlocked] = useState(false);

  useEffect(() => {
    // Get initial beta count
    async function fetchBetaCount() {
      const [count, max] = await Promise.all([
        getBetaTesterCount(),
        getMaxBetaTesters()
      ]);
      setBetaCount(count);
      setMaxBeta(max);
      setIsBetaFull(count >= max);
    }
    fetchBetaCount();

    // Check downloads unlock status
    const now = Date.now();
    setIsDownloadsUnlocked(now >= DOWNLOADS_LAUNCH_DATE);

    // Poll every second to unlock downloads at exact time
    const interval = setInterval(() => {
      const now = Date.now();
      if (now >= DOWNLOADS_LAUNCH_DATE) {
        setIsDownloadsUnlocked(true);
        clearInterval(interval);
      }
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const handleJoinBeta = async (userEmail: string) => {
    setIsLoading(true);
    setMessage(null);

    const result = await joinBetaTester(userEmail);

    setMessage({
      type: result.success ? "success" : "error",
      text: result.message
    });

    if (result.success) {
      setIsSignedIn(true);
      const count = await getBetaTesterCount();
      setBetaCount(count);
    }

    setIsLoading(false);
  };

  const handleWaitlistSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;

    setIsLoading(true);
    const result = await joinWaitlist(email);

    setMessage({
      type: result.success ? "success" : "error",
      text: result.message
    });

    setIsLoading(false);
  };

  const handleAuthSuccess = async (userEmail: string) => {
    await handleJoinBeta(userEmail);
  };

  return (
    <section id="download" className="py-48 px-6 bg-oasis-deep relative overflow-hidden flex flex-col items-center justify-center text-center">
      {/* Background radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-oasis-glow/[0.05] blur-[160px] rounded-full -z-10" />

      <motion.div
        initial={{ opacity: 0, y: 50 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        className="max-w-4xl space-y-8"
      >
        <h2 className="font-cormorant text-7xl md:text-[120px] lg:text-[160px] italic text-oasis-sand leading-none">
          Step into the Oasis.
        </h2>

        <p className="font-dm-serif text-xl md:text-3xl text-oasis-mist max-w-2xl mx-auto">
          A social network that respects you.
        </p>

        {/* Beta Counter */}
        {betaCount !== null && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            className="flex flex-col items-center gap-2"
          >
            <div className="flex items-center gap-3 px-4 py-2 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full">
              <span className="font-space-mono text-xs text-oasis-mist uppercase tracking-widest">
                Beta Testers
              </span>
              <span className="font-space-mono text-lg text-oasis-glow font-bold">
                {betaCount} / {maxBeta}
              </span>
            </div>
            <div className="w-48 h-2 bg-oasis-moss/40 rounded-full overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                whileInView={{ width: `${(betaCount / maxBeta) * 100}%` }}
                viewport={{ once: true }}
                transition={{ duration: 1, ease: "easeOut" }}
                className="h-full bg-oasis-glow rounded-full"
              />
            </div>
          </motion.div>
        )}

        {/* Messages */}
        {message && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className={`flex items-center justify-center gap-3 p-4 rounded-xl ${
              message.type === "success"
                ? "bg-oasis-glow/10 border border-oasis-glow/30 text-oasis-glow"
                : "bg-red-500/10 border border-red-500/30 text-red-400"
            }`}
          >
            {message.type === "success" ? <Check size={20} /> : <AlertCircle size={20} />}
            <span className="font-geist text-sm">{message.text}</span>
          </motion.div>
        )}

        {/* Main CTA - Different based on state */}
        {!isSignedIn ? (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.3 }}
            className="mt-8"
          >
            <button
              onClick={() => setIsAuthModalOpen(true)}
              disabled={isLoading}
              className="px-8 py-4 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_30px_rgba(127,255,212,0.4)] transition-all disabled:opacity-50 flex items-center gap-3 mx-auto"
            >
              {isLoading ? (
                <>
                  <Loader2 className="animate-spin" size={20} />
                  Processing...
                </>
              ) : (
                <>
                  Join Beta Waitlist
                </>
              )}
            </button>
            <p className="mt-4 font-geist text-sm text-oasis-mist/60">
              Sign in to secure your spot as a beta tester
            </p>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            className="mt-8 p-6 bg-oasis-glow/10 border border-oasis-glow/30 rounded-2xl"
          >
            <Check className="w-12 h-12 text-oasis-glow mx-auto mb-4" />
            <h3 className="font-cormorant text-2xl italic text-oasis-sand mb-2">
              You're In!
            </h3>
            <p className="font-geist text-oasis-mist">
              Welcome to the beta. We're excited to have you!
            </p>
          </motion.div>
        )}

        {/* Waitlist form when beta is full */}
        {isBetaFull && !isSignedIn && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.4 }}
            className="mt-8"
          >
            <p className="font-geist text-oasis-mist mb-4">
              Beta is full! Join the waitlist to be notified when we expand.
            </p>
            <form onSubmit={handleWaitlistSubmit} className="flex flex-col sm:flex-row gap-4 items-center justify-center max-w-md mx-auto">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Enter your email"
                required
                className="w-full px-6 py-4 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full font-geist text-oasis-white focus:outline-none focus:border-oasis-glow/50 transition-colors"
              />
              <button
                type="submit"
                disabled={isLoading}
                className="whitespace-nowrap px-8 py-4 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_30px_rgba(127,255,212,0.4)] transition-all disabled:opacity-50"
              >
                {isLoading ? <Loader2 className="animate-spin" size={20} /> : "Join Waitlist"}
              </button>
            </form>
          </motion.div>
        )}

        {/* Platform Download Buttons */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.5 }}
          className="mt-16 flex flex-col sm:flex-row gap-4 items-center justify-center"
        >
          {isDownloadsUnlocked ? (
            <button onClick={handleDownloadMSIX} className="flex items-center gap-3 px-6 py-3 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full font-geist text-oasis-mist hover:border-oasis-glow/30 transition-all cursor-pointer">
              <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                <rect x="3" y="3" width="8" height="8" rx="1" />
                <rect x="13" y="3" width="8" height="8" rx="1" />
                <rect x="3" y="13" width="8" height="8" rx="1" />
                <rect x="13" y="13" width="8" height="8" rx="1" />
              </svg>
              <span>Download for Windows</span>
            </button>
          ) : (
            <button disabled className="flex items-center gap-3 px-6 py-3 bg-oasis-moss/20 border border-oasis-sage/10 rounded-full font-geist text-oasis-mist/30 cursor-not-allowed opacity-50">
              <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                <rect x="3" y="3" width="8" height="8" rx="1" />
                <rect x="13" y="3" width="8" height="8" rx="1" />
                <rect x="3" y="13" width="8" height="8" rx="1" />
                <rect x="13" y="13" width="8" height="8" rx="1" />
              </svg>
              <span>Windows</span>
              <span className="px-2 py-0.5 bg-oasis-mist/10 text-oasis-mist/40 text-xs font-space-mono rounded">Coming Soon</span>
            </button>
          )}

          <button disabled className="flex items-center gap-3 px-6 py-3 bg-oasis-moss/20 border border-oasis-sage/10 rounded-full font-geist text-oasis-mist/30 cursor-not-allowed opacity-50">
            <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.02.39-2.15 1.05-3.11z"/>
            </svg>
            <span>macOS</span>
            <span className="px-2 py-0.5 bg-oasis-mist/10 text-oasis-mist/40 text-xs font-space-mono rounded">Coming Soon</span>
          </button>

          {isDownloadsUnlocked ? (
            <button onClick={handleDownloadAPK} className="flex items-center gap-3 px-6 py-3 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full font-geist text-oasis-mist hover:border-oasis-glow/30 transition-all cursor-pointer">
              <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                <path d="M12 2c1.1 0 2 .9 2 2s-.9 2-2 2-2-.9-2-2 .9-2 2-2zm9 7h-6v13h-2v-6h-2v6H9V9H3V7h18v2z"/>
              </svg>
              <span>Download APK</span>
            </button>
          ) : (
            <button disabled className="flex items-center gap-3 px-6 py-3 bg-oasis-moss/20 border border-oasis-sage/10 rounded-full font-geist text-oasis-mist/30 cursor-not-allowed opacity-50">
              <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
                <path d="M12 2c1.1 0 2 .9 2 2s-.9 2-2 2-2-.9-2-2 .9-2 2-2zm9 7h-6v13h-2v-6h-2v6H9V9H3V7h18v2z"/>
              </svg>
              <span>Download APK</span>
              <span className="px-2 py-0.5 bg-oasis-mist/10 text-oasis-mist/40 text-xs font-space-mono rounded">Coming Soon</span>
            </button>
          )}
          {!isDownloadsUnlocked && (
            <p className="font-space-mono text-xs text-oasis-mist/50 mt-2">
              Downloads will unlock at 11:11 AM IST on April 30
            </p>
          )}
        </motion.div>
      </motion.div>

      {/* Auth Modal */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
        onSuccess={handleAuthSuccess}
      />
    </section>
  );
}
