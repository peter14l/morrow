"use client";

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { ChevronDown } from "lucide-react";
import LaunchCountdown from "./LaunchCountdown";
import OasisSphere from "../3d/OasisSphere";

export default function Hero() {
  const scrollToDownload = () => {
    const element = document.getElementById('download');
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section className="relative min-h-[90vh] flex items-center overflow-hidden mesh-gradient-bg pt-32 px-6">
      {/* Background Glows */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-oasis-glow/10 rounded-full blur-[120px] -translate-y-1/2 translate-x-1/4" /> 
      <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-oasis-glow/5 rounded-full blur-[100px] translate-y-1/2 -translate-x-1/4" /> 

      <div className="max-w-7xl mx-auto w-full relative z-10 grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        {/* Text Content */}
        <div className="flex flex-col items-start text-left space-y-10">
          <motion.div
            initial={{ opacity: 0, x: -40 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          >
            <h1 className="font-cormorant text-7xl md:text-9xl italic text-oasis-sand leading-[0.9] tracking-tight">
              Digital sanctuary.<br />
              Be present.<br />
              Private chat.
            </h1>
          </motion.div>

          <motion.p
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: "easeOut" }}
            className="font-geist text-xl md:text-2xl text-oasis-mist max-w-lg leading-relaxed opacity-90"
          >
            Oasis is a high-performance sanctuary built for your wellbeing, protected by post-quantum encryption.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.4, ease: "easeOut" }}
            className="flex flex-col sm:flex-row gap-6 items-start"
          >
            <button
              onClick={scrollToDownload}
              className="px-10 py-5 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_40px_rgba(93,201,168,0.3)] transition-all flex items-center gap-3 justify-center group"
            >
              Get Early Access
              <motion.span animate={{ x: [0, 5, 0] }} transition={{ repeat: Infinity, duration: 1.5 }}>→</motion.span>
            </button>
            
            <div className="flex flex-col items-start pt-2">
              <span className="font-space-mono text-[10px] uppercase tracking-widest text-oasis-glow mb-1">Coming soon to</span>
              <span className="font-geist text-sm text-oasis-white/60">Windows & macOS</span>
            </div>
          </motion.div>
        </div>

        {/* Visual Element */}
        <motion.div
          initial={{ opacity: 0, scale: 0.8, rotate: -5 }}
          animate={{ opacity: 1, scale: 1, rotate: 0 }}
          transition={{ duration: 1.2, ease: "easeOut" }}
          className="hidden lg:flex justify-center relative"
        >
          <div className="relative w-[500px] h-[500px]">
            {/* 3D Organic Sphere */}
            <div className="absolute inset-0 flex items-center justify-center">
               <OasisSphere />
            </div>
            
            {/* Launch Countdown Overlay */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full z-10">
              <LaunchCountdown />
            </div>
          </div>
        </motion.div>
      </div>

      {/* Scroll Indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.5, duration: 1 }}
        className="absolute bottom-10 right-12 flex flex-col items-end gap-2"
      >
        <span className="font-space-mono text-[10px] uppercase tracking-widest text-oasis-mist/50">Scroll to explore</span>
        <div className="animate-bounce mr-4">
          <ChevronDown className="text-oasis-glow" size={20} />
        </div>
      </motion.div>
    </section>
  );
}
