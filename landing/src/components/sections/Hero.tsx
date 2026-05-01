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

      <div className="max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-2 gap-12 items-center relative z-10">
        {/* Text Content */}
        <div className="flex flex-col items-center lg:items-start text-center lg:text-left space-y-8">
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

        {/* Mockup */}
        <motion.div
          initial={{ opacity: 0, scale: 0.9, rotate: 5 }}
          animate={{ opacity: 1, scale: 1, rotate: 0 }}
          transition={{ duration: 1, delay: 0.5, ease: "easeOut" }}
          className="relative flex justify-center lg:justify-end"
        >
          <div className="relative w-[280px] h-[580px] md:w-[320px] md:h-[650px] animate-float">
            {/* Phone Frame */}
            <div className="absolute inset-0 bg-oasis-deep rounded-[3rem] border-8 border-oasis-sage shadow-2xl overflow-hidden glass flex flex-col items-center justify-center">
              {/* App Content: Focus Session */}
              <div className="w-full h-full bg-[#050B0A] relative flex flex-col items-center justify-center p-6 text-center space-y-8 overflow-hidden">
                {/* Starry Night Effect */}
                <div className="absolute inset-0 overflow-hidden pointer-events-none">
                  {[...Array(20)].map((_, i) => (
                    <motion.div
                      key={i}
                      animate={{
                        opacity: [0.2, 1, 0.2],
                        scale: [1, 1.2, 1],
                      }}
                      transition={{
                        duration: 3 + Math.random() * 2,
                        repeat: Infinity,
                        delay: Math.random() * 5,
                      }}
                      className="absolute w-1 h-1 bg-oasis-glow rounded-full"
                      style={{
                        top: `${Math.random() * 100}%`,
                        left: `${Math.random() * 100}%`,
                      }}
                    />
                  ))}
                </div>

                <div className="z-10 space-y-2">
                  <span className="font-space-mono text-[10px] text-oasis-glow uppercase tracking-[0.2em]">Deep Work</span>
                  <h3 className="font-dm-serif text-xl text-oasis-sand italic">Coding Oasis</h3>
                </div>

                {/* Giant Timer */}
                <div className="relative w-40 h-40 flex items-center justify-center z-10">
                  <svg viewBox="0 0 100 100" className="w-full h-full transform -rotate-90">
                    <circle cx="50" cy="50" r="45" fill="none" stroke="#1A2E28" strokeWidth="2" />
                    <motion.circle
                      cx="50"
                      cy="50"
                      r="45"
                      fill="none"
                      stroke="var(--oasis-glow)"
                      strokeWidth="2"
                      strokeDasharray="283"
                      animate={{ strokeDashoffset: [283, 100] }}
                      transition={{ duration: 10, repeat: Infinity, ease: "linear" }}
                    />
                  </svg>
                  <div className="absolute flex flex-col items-center">
                    <span className="font-space-mono text-3xl text-oasis-white font-bold tracking-tight">24:59</span>
                  </div>
                </div>

                {/* Avatars */}
                <div className="flex -space-x-2 z-10">
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="w-8 h-8 rounded-full border-2 border-[#050B0A] bg-oasis-moss overflow-hidden">
                      <div className={`w-full h-full bg-gradient-to-br ${i === 1 ? 'from-oasis-glow/40 to-oasis-sage' : 'from-oasis-sand/40 to-oasis-moss'}`} />
                    </div>
                  ))}
                  <div className="w-8 h-8 rounded-full border-2 border-[#050B0A] bg-oasis-moss/40 flex items-center justify-center text-[8px] text-oasis-glow font-space-mono">
                    +4
                  </div>
                </div>

                <div className="z-10 pt-4 w-full">
                  <div className="h-12 rounded-2xl bg-oasis-glow/10 border border-oasis-glow/20 flex items-center justify-center">
                    <span className="font-space-mono text-[10px] text-oasis-glow uppercase tracking-widest">Locked In</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Glow behind phone */}
            <div className="absolute inset-0 -z-10 bg-oasis-glow/10 rounded-full blur-3xl scale-110" />
          </div>
        </motion.div>
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
