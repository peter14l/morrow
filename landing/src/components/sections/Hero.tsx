"use client";

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { ChevronDown } from "lucide-react";
import LaunchCountdown from "./LaunchCountdown";

export default function Hero() {
  const scrollToDownload = () => {
    const element = document.getElementById('download');
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden mesh-gradient-bg pt-20 px-6">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-oasis-glow/5 rounded-full blur-[120px]" /> 

      <div className="max-w-3xl mx-auto w-full relative z-10 text-center">
        {/* Text Content */}
        <div className="flex flex-col items-center space-y-8">
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          >
            <h1 className="font-cormorant text-6xl md:text-8xl italic text-oasis-sand leading-tight">
              Be social.<br />
              Be present.<br />
              Be protected.
            </h1>
          </motion.div>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: "easeOut" }}
            className="font-geist text-lg md:text-xl text-oasis-mist max-w-lg"
          >
            Oasis is a social platform built around your wellbeing, not your attention span.
          </motion.p>

          {/* Launch Countdown */}
          <LaunchCountdown />

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.4, ease: "easeOut" }}
            className="flex flex-col sm:flex-row gap-4"
          >
            <button
              onClick={scrollToDownload}
              className="px-8 py-4 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_30px_rgba(127,255,212,0.4)] transition-all flex items-center gap-3 justify-center"
            >
              Get Early Access
            </button>
          </motion.div>
        </div>
      </div>

      {/* Scroll Indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.5, duration: 1 }}
        className="absolute bottom-10 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2"
      >
        <span className="font-space-mono text-[10px] uppercase tracking-widest text-oasis-mist/50">Scroll to explore</span>
        <div className="animate-bounce">
          <ChevronDown className="text-oasis-glow" size={20} />
        </div>
      </motion.div>
    </section>
  );
}
