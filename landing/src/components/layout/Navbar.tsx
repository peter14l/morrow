"use client";

import React, { useState, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import { motion, AnimatePresence, useScroll, useTransform } from "framer-motion";
import { Menu, X } from "lucide-react";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/Button";

const NavLinks = [
  { name: "Home", href: "#" },
  { name: "Features", href: "#features" },
  { name: "Wellbeing", href: "#wellbeing" },
  { name: "Pricing", href: "#pricing" },
];

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const { scrollY } = useScroll();
  
  const backgroundColor = useTransform(
    scrollY,
    [0, 100],
    ["rgba(13, 31, 26, 0)", "rgba(13, 31, 26, 0.8)"]
  );
  
  const backdropBlur = useTransform(
    scrollY,
    [0, 100],
    ["blur(0px)", "blur(16px)"]
  );

  return (
    <motion.nav
      style={{ backgroundColor, backdropFilter: backdropBlur }}
      className="fixed top-0 left-0 right-0 z-50 transition-colors duration-300 border-b border-transparent data-[scrolled=true]:border-oasis-glow/10"
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-3 group">
          <div className="relative w-10 h-10 overflow-hidden rounded-xl border border-oasis-sage/20 group-hover:border-oasis-glow/30 transition-all">
            <Image 
              src="/app_icon.png" 
              alt="Oasis Logo" 
              fill 
              className="object-cover group-hover:scale-110 transition-transform duration-500"
            />
          </div>
          <span className="font-cormorant text-2xl italic text-oasis-sand group-hover:text-oasis-glow transition-colors">
            Oasis
          </span>
        </Link>

        {/* Desktop Nav */}
        <div className="hidden md:flex items-center gap-8">
          {NavLinks.map((link) => (
            <Link
              key={link.name}
              href={link.href}
              className="font-geist text-sm text-oasis-mist hover:text-oasis-glow transition-colors"
            >
              {link.name}
            </Link>
          ))}
          <Button variant="outline" size="sm">
            Join the Waitlist
          </Button>
        </div>

        {/* Mobile Toggle */}
        <button
          className="md:hidden text-oasis-sand"
          onClick={() => setIsOpen(!isOpen)}
        >
          {isOpen ? <X size={28} /> : <Menu size={28} />}
        </button>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, x: "100%" }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: "100%" }}
            transition={{ type: "spring", damping: 25, stiffness: 200 }}
            className="fixed inset-0 z-40 bg-oasis-deep flex flex-col items-center justify-center gap-8 md:hidden"
          >
            {NavLinks.map((link, i) => (
              <motion.div
                key={link.name}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.1 }}
              >
                <Link
                  href={link.href}
                  className="font-cormorant text-4xl italic text-oasis-sand hover:text-oasis-glow"
                  onClick={() => setIsOpen(false)}
                >
                  {link.name}
                </Link>
              </motion.div>
            ))}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: NavLinks.length * 0.1 }}
              className="mt-4"
            >
              <Button variant="outline" size="lg">
                Join the Waitlist
              </Button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
}

