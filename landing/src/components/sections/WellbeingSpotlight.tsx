"use client";

import React from "react";
import { motion } from "framer-motion";
import { Lock, Timer, Mail } from "lucide-react";

import { TimeRings, QuantumLock, TimeCapsule } from "../3d/SpotlightObjects";

const spotlightBlocks = [
  {
    title: "Your time is your life.",
    description: "Reclaim your focus with customizable study sessions and 'Lock-in Mode'. Straying from your goals results in XP penalties, training your mind for deep, intentional work. Oasis doesn't just save your time; it values it.",
    icon: Timer,
    color: "var(--oasis-glow)",
    graphic: (
      <div className="relative w-64 h-64 flex items-center justify-center">
        <TimeRings />
      </div>
    ),
  },
  {
    title: "Post-Quantum Privacy. Built for the future.",
    description: "We don't just use encryption; we use the world's most advanced post-quantum resilient double-ratchet. PQ-Aura ensures that your conversations are safe even against tomorrow's supercomputers. Your digital sanctuary is truly impenetrable.",
    icon: Lock,
    color: "#5DC9A8",
    graphic: (
      <div className="relative w-64 h-64 flex items-center justify-center">
        <QuantumLock />
      </div>
    ),
  },
  {
    title: "Plant a message. Harvest a memory.",
    description: "Time Capsule feature. Write to your future self, or schedule messages for communities to unlock at the right moment. Social media that spans seasons, not seconds.",
    icon: Mail,
    color: "var(--oasis-sand)",
    graphic: (
      <div className="relative w-64 h-64 flex items-center justify-center">
        <TimeCapsule />
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
