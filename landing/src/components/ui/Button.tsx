"use client";

import React from "react";
import { motion, HTMLMotionProps } from "framer-motion";
import { cn } from "@/lib/utils";

interface ButtonProps extends HTMLMotionProps<"button"> {
  variant?: "primary" | "outline" | "ghost";
  size?: "sm" | "md" | "lg";
  children: React.ReactNode;
  className?: string;
}

export function Button({ 
  variant = "primary", 
  size = "md", 
  children, 
  className, 
  ...props 
}: ButtonProps) {
  const variants = {
    primary: "bg-oasis-glow text-oasis-deep hover:shadow-[0_0_30px_rgba(93,201,168,0.3)]",
    outline: "border border-oasis-glow text-oasis-glow hover:bg-oasis-glow hover:text-oasis-deep",
    ghost: "border border-oasis-mist/30 text-oasis-white hover:bg-white/5",
  };

  const sizes = {
    sm: "px-4 py-2 text-xs",
    md: "px-6 py-3 text-sm",
    lg: "px-8 py-4 text-base",
  };

  return (
    <motion.button
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.98 }}
      className={cn(
        "rounded-full font-space-mono font-bold transition-all duration-300",
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    >
      {children}
    </motion.button>
  );
}
