"use client";

import React from "react";
import { motion } from "framer-motion";

const stats = [
  "93% of users feel 'digital burnout'",
  "Your attention is the product.",
  "E2EE is no longer enough.",
];

export default function ProblemStatement() {
  return (
    <section className="py-24 bg-oasis-deep border-y border-oasis-sage/20 relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-6 text-center">
        <motion.div
          initial={{ clipPath: "inset(0 100% 0 0)" }}
          whileInView={{ clipPath: "inset(0 0% 0 0)" }}
          transition={{ duration: 1.5, ease: "easeInOut" }}
          viewport={{ once: true }}
          className="mb-12"
        >
          <h2 className="font-dm-serif text-3xl md:text-5xl text-oasis-sand leading-tight">
            "Social media was supposed to connect us.<br className="hidden md:block" /> Instead, it harvested us. It's time to go home."
          </h2>
        </motion.div>

        <div className="flex flex-wrap justify-center gap-4">
          {stats.map((stat, i) => (
            <motion.div
              key={stat}
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.5 + i * 0.1 }}
              viewport={{ once: true }}
              className="px-6 py-2 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full"
            >
              <span className="font-space-mono text-xs md:text-sm text-oasis-mist uppercase tracking-tight">
                {stat}
              </span>
            </motion.div>
          ))}
        </div>
      </div>
      
      {/* Background radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-oasis-glow/[0.02] blur-3xl -z-10" />
    </section>
  );
}
