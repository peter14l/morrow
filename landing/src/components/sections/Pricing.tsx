"use client";

import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Check, Globe, ShieldAlert } from "lucide-react";
import { PricingGem } from "../3d/DecorativeObjects";

// PPP mapping (Expanded for major regions)
const PPP_PRICES: Record<string, { price: string; symbol: string }> = {
  US: { price: "4.99", symbol: "$" },
  GB: { price: "4.49", symbol: "£" },
  EU: { price: "4.99", symbol: "€" },
  DE: { price: "4.99", symbol: "€" },
  FR: { price: "4.99", symbol: "€" },
  CA: { price: "6.99", symbol: "CA$" },
  AU: { price: "7.99", symbol: "A$" },
  IN: { price: "149", symbol: "₹" },
  BR: { price: "14.90", symbol: "R$" },
  MX: { price: "49", symbol: "$" },
  ID: { price: "39000", symbol: "Rp" },
  PH: { price: "149", symbol: "₱" },
  // Default fallback
  DEFAULT: { price: "4.99", symbol: "$" },
};

export default function Pricing() {
  const [geoData, setGeoData] = useState<{ country: string; isVpn: boolean } | null>(null);
  const [pricing, setPricing] = useState<{ price: string; symbol: string } | null>(null);

  useEffect(() => {
    async function fetchGeo() {
      try {
        const res = await fetch("/api/geo");
        const data = await res.json();
        setGeoData(data);

        // If VPN detected, force default pricing
        if (data.isVpn) {
          setPricing(PPP_PRICES.DEFAULT);
        } else {
          const countryPricing = PPP_PRICES[data.country] || PPP_PRICES.DEFAULT;
          setPricing(countryPricing);
        }
      } catch (error) {
        console.error("Failed to fetch geo data", error);
        setPricing(PPP_PRICES.DEFAULT);
      }
    }
    fetchGeo();
  }, []);

  // Use India as fallback for immediate display if you prefer, or a placeholder
  const activePricing = pricing || PPP_PRICES.DEFAULT;

  const plans = [
    {
      name: "Free",
      price: `${activePricing.symbol}0`,
      features: [
        "End-to-end encryption",
        "14-Day Cloud Media Storage",
        "Local Device Storage",
        "Public Circles",
        "Mindful feed access",
      ],
      cta: "Join Waitlist",
      highlight: false,
    },
    {
      name: "Pro",
      price: `${activePricing.symbol}${activePricing.price}`,
      features: [
        "Unlimited Cloud Media Storage",
        "Unlimited Vault & Capsules",
        "Private & Hidden Circles",
        "Enhanced Wellness Insights",
        "Custom UI Themes",
        "Priority Support",
      ],
      cta: "Upgrade to Pro",
      highlight: true,
    },
  ];

  return (
    <section id="pricing" className="py-24 px-6 bg-oasis-deep relative overflow-hidden">
      <PricingGem />
      <div className="max-w-5xl mx-auto relative z-10">
        <div className="mb-16 text-center">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="font-dm-serif text-4xl md:text-5xl text-oasis-sand mb-4"
          >
            Upgrade to Oasis Pro
          </motion.h2>
          <p className="font-geist text-oasis-mist">Choose the level of presence that works for you.</p>
          
          {geoData && (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="mt-6 inline-flex items-center gap-2 px-4 py-2 bg-oasis-glow/10 border border-oasis-glow/20 rounded-full"
            >
              {geoData.isVpn ? (
                <>
                  <ShieldAlert size={14} className="text-red-400" />
                  <span className="font-space-mono text-[10px] text-red-400 uppercase tracking-widest font-bold">
                    VPN Detected - Standard Pricing Applied
                  </span>
                </>
              ) : (
                <>
                  <Globe size={14} className="text-oasis-glow" />
                  <span className="font-space-mono text-[10px] text-oasis-glow uppercase tracking-widest">
                    Local pricing for {geoData.country} applied
                  </span>
                </>
              )}
            </motion.div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-stretch">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.2 }}
              className={`p-10 rounded-[3rem] glass flex flex-col justify-between transition-all duration-500 hover:scale-102 ${
                plan.highlight 
                  ? "border-oasis-glow/40 shadow-[0_0_80px_rgba(93,201,168,0.15)] scale-105 z-10" 
                  : "border-oasis-sage/20 opacity-90"
              }`}
            >
              <div>
                <div className="flex justify-between items-center mb-6">
                  <h3 className="font-dm-serif text-2xl text-oasis-sand">{plan.name}</h3>
                  {plan.highlight && (
                    <span className="px-4 py-1 bg-oasis-glow text-oasis-deep font-space-mono text-[10px] uppercase font-bold rounded-full">
                      Most Popular
                    </span>
                  )}
                </div>
                <div className="flex items-baseline gap-2 mb-8">
                  <span className="text-4xl font-dm-serif text-oasis-white">{plan.price}</span>
                  <span className="text-oasis-mist">/month</span>
                </div>
                <ul className="space-y-4 mb-12">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-center gap-3 text-oasis-mist/90">
                      <div className="w-5 h-5 rounded-full bg-oasis-glow/10 flex items-center justify-center flex-shrink-0">
                        <Check size={12} className="text-oasis-glow" />
                      </div>
                      <span className="font-geist text-sm">{feature}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <button
                className={`w-full py-4 rounded-full font-space-mono transition-all duration-300 ${
                  plan.highlight
                    ? "bg-oasis-glow text-oasis-deep hover:shadow-[0_0_30px_rgba(93,201,168,0.3)]"
                    : "border border-oasis-mist/30 text-oasis-white hover:bg-white/5"
                }`}
              >
                {plan.cta}
              </button>
            </motion.div>
          ))}
        </div>

        {/* Info about pricing */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.5 }}
          className="mt-16 p-8 rounded-2xl bg-oasis-glow/5 border border-oasis-glow/20 text-center relative overflow-hidden group"
        >
          <div className="absolute inset-0 bg-oasis-glow/5 blur-3xl group-hover:bg-oasis-glow/10 transition-colors -z-10" />
          <p className="font-space-mono text-lg md:text-xl text-oasis-glow font-bold tracking-tight">
            Pricing and subscriptions will be introduced in the app soon.
          </p>
          <p className="font-geist text-sm text-oasis-mist/60 mt-2">
            Early adopters will receive exclusive benefits and legacy status.
          </p>
        </motion.div>
      </div>
      
      {/* Background radial glow */}
      <div className="absolute -top-40 -right-40 w-96 h-96 bg-oasis-glow/10 blur-[120px] rounded-full -z-10" />
    </section>
  );
}
