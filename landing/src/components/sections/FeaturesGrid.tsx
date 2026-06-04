"use client";

import React from "react";
import { motion } from "framer-motion";
import { Waves, ShieldCheck, Layers, Clock, Lock, Activity } from "lucide-react";
import { cn } from "@/lib/utils";
import { BentoCard } from "@/components/ui/BentoCard";

const features = [
  {
    title: "Wellness Center",
    description: "Built-in study sessions, energy metering, and mindful detox modes to help you stay present.",
    icon: Activity,
    className: "md:col-span-2",
  },
  {
    title: "PQ-Aura Security",
    description: "Post-quantum double-ratchet encryption ensuring your conversations stay private forever.",
    icon: ShieldCheck,
    className: "md:col-span-1",
  },
  {
    title: "Digital Sanctuary",
    description: "Private communities designed for deep connection, free from algorithmic noise.",
    icon: Waves,
    className: "md:col-span-1",
  },
  {
    title: "Time Capsules",
    description: "Plant memories today and harvest them in the future when the moment is right.",
    icon: Clock,
    className: "md:col-span-2",
  },
  {
    title: "Privacy by Design",
    description: "Local-first data sovereignty and E2EE for all your journals and communications.",
    icon: Lock,
    className: "md:col-span-2",
  },
  {
    title: "Intentional Stories",
    description: "Share your life with mindful limits that prevent the infinite scroll trap.",
    icon: Layers,
    className: "md:col-span-1",
  },
];

export default function FeaturesGrid() {
  return (
    <section id="features" className="py-24 px-6 bg-oasis-deep">
      <div className="max-w-7xl mx-auto">
        <div className="mb-16 text-center">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="font-dm-serif text-4xl md:text-5xl text-oasis-sand mb-4"
          >
            Everything you love. Nothing you don't.
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="font-geist text-oasis-mist max-w-2xl mx-auto"
          >
            A social experience redesigned from the ground up to respect your time, 
            privacy, and mental wellbeing.
          </motion.p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 auto-rows-[minmax(220px,auto)]">
          {features.map((feature, i) => {
            const Icon = feature.icon;
            return (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                className={feature.className}
              >
                <BentoCard className="h-full hover:border-oasis-glow/40 hover:shadow-[0_0_40px_rgba(93,201,168,0.1)]">
                  <div className="flex justify-end">
                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-oasis-moss to-oasis-deep border border-oasis-sage/30 flex items-center justify-center text-oasis-glow shadow-inner group-hover:scale-110 transition-transform duration-500">
                      <Icon size={22} />
                    </div>
                  </div>
                  
                  <div className="mt-8">
                    <h3 className="font-dm-serif text-2xl text-oasis-sand mb-3 group-hover:text-oasis-glow transition-colors duration-300">
                      {feature.title}
                    </h3>
                    <p className="font-geist text-base text-oasis-mist leading-relaxed opacity-80 group-hover:opacity-100 transition-opacity">
                      {feature.description}
                    </p>
                  </div>
                </BentoCard>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
