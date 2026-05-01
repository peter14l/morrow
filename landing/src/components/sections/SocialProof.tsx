"use client";

import React from "react";
import { motion } from "framer-motion";

/* 
const quotes = [
  "Finally, a place where I don't feel like I'm being harvested for my attention. It's calm.",
  "Oasis feels like the internet used to — personal, safe, and actually social.",
  "The session limits changed my relationship with my phone. I'm finally present again.",
];
*/

export default function SocialProof() {
  return (
    <section id="community" className="py-24 px-6 bg-oasis-deep relative overflow-hidden">
      <div className="max-w-7xl mx-auto text-center">
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="font-dm-serif text-4xl md:text-6xl text-oasis-sand mb-12"
        >
          Built for humans who want more.
        </motion.h2>

        {/* Avatar Cluster
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          className="flex flex-col items-center gap-6 mb-20"
        >
          <div className="flex -space-x-4">
            {[1, 2, 3, 4, 5].map((i) => (
              <div 
                key={i}
                className="w-12 h-12 rounded-full border-2 border-oasis-deep bg-oasis-moss flex items-center justify-center overflow-hidden"        
              >
                <div className={`w-full h-full bg-gradient-to-br ${i % 2 === 0 ? 'from-oasis-glow/40 to-oasis-sage' : 'from-oasis-sand/40 to-oasis-moss'}`} />
              </div>
            ))}
            <div className="w-12 h-12 rounded-full border-2 border-oasis-deep bg-oasis-moss flex items-center justify-center text-[10px] font-space-mono text-oasis-glow">
              +12k
            </div>
          </div>
          <span className="font-space-mono text-sm text-oasis-mist uppercase tracking-widest">
            Join 12,000+ humans on the waitlist
          </span>
        </motion.div>
        */}

        {/* Testimonials
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
          {quotes.map((quote, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              className="space-y-4 group"
            >
              <div className="p-8 rounded-[2rem] bg-oasis-moss/20 border border-oasis-sage/10 relative hover:border-oasis-glow/30 transition-all">
                <p className="font-cormorant text-2xl italic text-oasis-mist leading-relaxed">
                  "{quote}"
                </p>
                <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-30 transition-opacity">
                  <svg viewBox="0 0 24 24" className="w-12 h-12 text-oasis-glow" fill="currentColor">
                    <path d="M14.017 21L14.017 18C14.017 16.8954 14.9124 16 16.017 16H19.017C19.5693 16 20.017 15.5523 20.017 15V9C20.017 8.44772 19.5693 8 19.017 8H15.017C14.4647 8 14.017 8.44772 14.017 9V12C14.017 12.5523 13.5693 13 13.017 13H11.017C10.4647 13 10.017 12.5523 10.017 12V9C10.017 7.34315 11.3601 6 13.017 6H19.017C20.6739 6 22.017 7.34315 22.017 9V15C22.017 18.3137 19.3307 21 16.017 21H14.017ZM3.017 21L3.017 18C3.017 16.8954 3.91243 16 5.017 16H8.017C8.56928 16 9.017 15.5523 9.017 15V9C9.017 8.44772 8.56928 8 8.017 8H4.017C3.46472 8 3.017 8.44772 3.017 9V12C3.017 12.5523 2.56928 13 2.017 13H0.017C-0.53528 13 -1.017 12.5523 -1.017 12V9C-1.017 7.34315 0.32614 6 2.017 6H8.017C9.67386 6 11.017 7.34315 11.017 9V15C11.017 18.3137 8.33071 21 5.017 21H3.017Z" />
                  </svg>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
        */}
      </div>
    </section>
  );
}
