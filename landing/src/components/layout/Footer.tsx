import React from "react";
import Link from "next/link";

export default function Footer() {
  return (
    <footer className="bg-oasis-deep px-6 py-12 border-t border-oasis-glow/10">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2">
          <span className="font-cormorant text-2xl italic text-oasis-sand">Oasis</span>
        </Link>

        {/* Links */}
        <div className="flex flex-wrap justify-center gap-8 font-geist text-sm text-oasis-mist/60">
          <Link href="/privacy" className="hover:text-oasis-glow transition-colors">Privacy Policy</Link>
          <Link href="/terms" className="hover:text-oasis-glow transition-colors">Terms of Service</Link>
          <a href="mailto:oasis.officialsupport@gmail.com" className="hover:text-oasis-glow transition-colors">Support</a>
        </div>

        {/* Copyright */}
        <div className="text-center md:text-right space-y-1">
          <p className="font-space-mono text-[10px] text-oasis-mist/40 uppercase tracking-widest">
            Oasis — Social, Reimagined.
          </p>
          <p className="font-geist text-[10px] text-oasis-mist/30">
            © {new Date().getFullYear()} Oasis Social Inc. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
