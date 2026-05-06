"use client";

import React from "react";
import { motion } from "framer-motion";
import { CheckCircle2, ArrowRight } from "lucide-react";
import Link from "next/link";

export default function AuthSuccessPage() {
  return (
    <main className="min-h-screen bg-oasis-deep flex items-center justify-center p-6 relative overflow-hidden">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-oasis-glow/5 rounded-full blur-[120px]" />

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="max-w-md w-full glass p-10 rounded-[3rem] text-center relative z-10 border border-oasis-glow/20"
      >
        <div className="flex justify-center mb-8">
          <div className="w-24 h-24 bg-oasis-glow/10 rounded-full flex items-center justify-center border border-oasis-glow/30">
            <CheckCircle2 className="text-oasis-glow w-12 h-12" />
          </div>
        </div>

        <h1 className="font-cormorant text-4xl italic text-oasis-sand mb-4 leading-tight">
          Verification Successful!
        </h1>

        <p className="font-geist text-oasis-mist mb-10 leading-relaxed text-lg">
          Your email has been successfully verified. You&apos;re now ready to step into the Oasis.
        </p>

        <div className="space-y-4">
          <div className="p-6 bg-oasis-moss/40 border border-oasis-sage/20 rounded-2xl">
            <p className="font-space-mono text-xs uppercase tracking-widest text-oasis-glow mb-2">What&apos;s Next?</p>
            <p className="font-geist text-sm text-oasis-mist leading-relaxed">
              Head back to our website, download the app for your device, and sign in with your credentials.
            </p>
          </div>

          <Link
            href="/"
            className="flex items-center justify-center gap-2 w-full py-4 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_30px_rgba(127,255,212,0.4)] transition-all"
          >
            Go to Website
            <ArrowRight size={18} />
          </Link>
        </div>
      </motion.div>

      {/* Decorative elements */}
      <div className="absolute bottom-0 left-0 w-full h-1/2 bg-gradient-to-t from-oasis-glow/[0.02] to-transparent pointer-events-none" />
    </main>
  );
}
