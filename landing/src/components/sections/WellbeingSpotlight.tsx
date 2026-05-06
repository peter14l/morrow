"use client";

import React from "react";
import { motion } from "framer-motion";
import { Lock, Timer, Mail } from "lucide-react";

const spotlightBlocks = [
  {
    title: "Your time is yours.",
    description: "Take control of your focus with customizable study sessions. Set your duration from 15 to 60 minutes and activate 'Lock-in Mode' for deep focus—straying from Oasis during a session will result in XP penalties, keeping you accountable.",
    icon: Timer,
    color: "var(--oasis-glow)",
    graphic: (
      <div className="relative w-48 h-48 flex items-center justify-center">
        <svg viewBox="0 0 100 100" className="w-full h-full transform -rotate-90">
          <circle
            cx="50"
            cy="50"
            r="45"
            fill="none"
            stroke="var(--oasis-sage)"
            strokeWidth="1.5"
            opacity="0.2"
          />
          <motion.circle
            cx="50"
            cy="50"
            r="45"
            fill="none"
            stroke="var(--oasis-glow)"
            strokeWidth="1.5"
            strokeDasharray="283"
            initial={{ strokeDashoffset: 283 }}
            whileInView={{ strokeDashoffset: 100 }}
            transition={{ duration: 2, ease: "easeInOut" }}
            viewport={{ once: true }}
          />
        </svg>
        <div className="absolute font-space-mono text-oasis-glow text-2xl font-bold">15:00</div>
      </div>
    ),
  },
  {
    title: "Privacy isn't a setting. It's the foundation.",
    description: "Your digital life belongs to you. We use Row-Level Security (RLS) to ensure only you can access your profile and content, while End-to-End Encryption (E2EE) protects your journals and capsules. With the Privacy Sync Toggle, you decide exactly when your data touches the cloud.",
    icon: Lock,
    color: "#5DC9A8",
    graphic: (
      <div className="relative w-48 h-48 flex items-center justify-center">
        <motion.div
          animate={{ 
            scale: [1, 1.05, 1],
            rotate: [0, 5, -5, 0]
          }}
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
          className="w-36 h-36 bg-oasis-glow/5 rounded-[2rem] flex items-center justify-center border border-oasis-glow/20 shadow-[0_0_60px_rgba(93,201,168,0.1)]"
        >
          <div className="w-20 h-20 bg-oasis-glow/10 rounded-full flex items-center justify-center border border-oasis-glow/20">
            <Lock className="text-oasis-glow" size={32} />
          </div>
        </motion.div>
      </div>
    ),
  },
  {
    title: "Plant a message. Harvest a memory.",
    description: "Time Capsule feature. Write to your future self, or schedule messages for communities to unlock at the right moment. Social media that spans seasons, not seconds.",
    icon: Mail,
    color: "var(--oasis-sand)",
    graphic: (
      <div className="relative w-48 h-48 flex items-center justify-center">
        <div className="w-32 h-44 bg-oasis-sand/5 rounded-2xl border border-oasis-sand/20 relative overflow-hidden backdrop-blur-sm">
          <div className="absolute top-0 left-0 w-full h-14 bg-oasis-sand/10 border-b border-oasis-sand/20 flex items-center px-4">
             <div className="w-2 h-2 rounded-full bg-oasis-sand/40 mr-2" />
             <div className="w-12 h-1 bg-oasis-sand/20 rounded-full" />
          </div>
          <motion.div 
            initial={{ y: 20, opacity: 0 }}
            whileInView={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.8 }}
            className="absolute bottom-8 left-1/2 -translate-x-1/2 w-16 h-1 bg-oasis-sand/30 rounded-full shadow-[0_0_20px_rgba(227,209,180,0.2)]"
          />
        </div>
        <div className="absolute -bottom-2 w-40 h-1 bg-oasis-sand/10 blur-sm rounded-full" />
      </div>
    ),
  },
];

export default function WellbeingSpotlight() {
  return (
    <section id="wellbeing" className="py-24 px-6 bg-oasis-deep overflow-hidden">
      <div className="max-w-7xl mx-auto space-y-32">
        {spotlightBlocks.map((block, i) => (
          <div 
            key={block.title}
            className={`flex flex-col ${i % 2 === 0 ? 'md:flex-row' : 'md:flex-row-reverse'} items-center gap-12 md:gap-24`}
          >
            {/* Graphic side */}
            <motion.div
              initial={{ opacity: 0, x: i % 2 === 0 ? -50 : 50 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.8, ease: "easeOut" }}
              viewport={{ once: true, margin: "-100px" }}
              className="flex-1 flex justify-center"
            >
              <div className="relative">
                {block.graphic}
                <div className="absolute -inset-4 bg-oasis-glow/5 blur-3xl rounded-full -z-10" />
              </div>
            </motion.div>

            {/* Text side */}
            <motion.div
              initial={{ opacity: 0, x: i % 2 === 0 ? 50 : -50 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.8, ease: "easeOut" }}
              viewport={{ once: true, margin: "-100px" }}
              className="flex-1 space-y-6 text-center md:text-left"
            >
              <div className="flex justify-center md:justify-start">
                <div className="p-3 rounded-xl bg-oasis-moss border border-oasis-sage/30 text-oasis-glow mb-2">
                  <block.icon size={28} />
                </div>
              </div>
              <h2 className="font-dm-serif text-3xl md:text-5xl text-oasis-sand">
                {block.title}
              </h2>
              <p className="font-geist text-lg text-oasis-mist leading-relaxed max-w-xl mx-auto md:mx-0">
                {block.description}
              </p>
            </motion.div>
          </div>
        ))}
      </div>
    </section>
  );
}
