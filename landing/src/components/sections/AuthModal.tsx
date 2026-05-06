"use client";

import React, { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Mail, Lock, Eye, EyeOff, AlertCircle, Check } from "lucide-react";
import { supabase } from "@/lib/supabase";

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (email: string) => void;
}

export default function AuthModal({ isOpen, onClose, onSuccess }: AuthModalProps) {
  const [mode, setMode] = useState<"signin" | "signup">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      if (mode === "signup") {
        // Check if already in beta_testers or waitlist to avoid redundant signups
        const { data: existingBeta } = await supabase
          .from('beta_testers')
          .select('email')
          .eq('email', email)
          .single();

        if (existingBeta) {
          setError("An account already exists with this email. Please sign in instead.");
          setMode("signin");
          setLoading(false);
          return;
        }

        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}/auth/success`,
          },
        });

        if (error) throw error;
        setSuccess("Account created successfully! Please check your spam folder for the verification email. You can now sign in.");
        setMode("signin");
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });

        if (error) throw error;
        onSuccess(email);
        onClose();
      }
    } catch (err: any) {
      setError(err.message || "An error occurred");
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-oasis-deep/90 backdrop-blur-sm z-50"
          />

          {/* Modal */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
          >
            <div className="w-full max-w-md bg-oasis-moss/40 border border-oasis-sage/30 rounded-3xl p-8 relative backdrop-blur-xl">
              {/* Close button */}
              <button
                onClick={onClose}
                className="absolute top-4 right-4 text-oasis-mist hover:text-oasis-glow transition-colors"
              >
                <X size={24} />
              </button>

              {/* Header */}
              <div className="text-center mb-8">
                <h2 className="font-cormorant text-3xl italic text-oasis-sand mb-2">
                  {mode === "signin" ? "Welcome Back" : "Join the Beta"}
                </h2>
                <p className="font-geist text-oasis-mist">
                  {mode === "signin" 
                    ? "Sign in to join the beta testers" 
                    : "Create an account to become a beta tester"}
                </p>
              </div>

              {/* Error/Success messages */}
              {error && (
                <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-xl flex items-center gap-3 text-red-400">
                  <AlertCircle size={20} />
                  <span className="text-sm">{error}</span>
                </div>
              )}
              {success && (
                <div className="mb-6 p-4 bg-oasis-glow/10 border border-oasis-glow/30 rounded-xl flex items-center gap-3 text-oasis-glow">
                  <Check size={20} />
                  <span className="text-sm">{success}</span>
                </div>
              )}

              {/* Form */}
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-oasis-mist/50" size={20} />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Email"
                    required
                    className="w-full pl-12 pr-4 py-3 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full font-geist text-oasis-white placeholder:text-oasis-mist/50 focus:outline-none focus:border-oasis-glow/50 transition-colors"
                  />
                </div>

                <div className="relative">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-oasis-mist/50" size={20} />
                  <input
                    type={showPassword ? "text" : "password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Password"
                    required
                    minLength={6}
                    className="w-full pl-12 pr-12 py-3 bg-oasis-moss/40 border border-oasis-sage/30 rounded-full font-geist text-oasis-white placeholder:text-oasis-mist/50 focus:outline-none focus:border-oasis-glow/50 transition-colors"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-oasis-mist/50 hover:text-oasis-glow transition-colors"
                  >
                    {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                  </button>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3 bg-oasis-glow text-oasis-deep rounded-full font-space-mono font-bold hover:shadow-[0_0_30px_rgba(127,255,212,0.4)] transition-all disabled:opacity-50"
                >
                  {loading 
                    ? "Please wait..." 
                    : mode === "signin" 
                      ? "Sign In" 
                      : "Create Account"}
                </button>
              </form>

              {/* Toggle mode */}
              <p className="mt-6 text-center font-geist text-oasis-mist">
                {mode === "signin" ? "Don't have an account? " : "Already have an account? "}
                <button
                  onClick={() => {
                    setMode(mode === "signin" ? "signup" : "signin");
                    setError(null);
                    setSuccess(null);
                  }}
                  className="text-oasis-glow hover:underline"
                >
                  {mode === "signin" ? "Sign Up" : "Sign In"}
                </button>
              </p>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
