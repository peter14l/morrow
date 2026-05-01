"use client";

import { AnimatePresence, motion } from "framer-motion";
import Navbar from "@/components/layout/Navbar";
import Hero from "@/components/sections/Hero";
import ProblemStatement from "@/components/sections/ProblemStatement";
import FeaturesGrid from "@/components/sections/FeaturesGrid";
import WellbeingSpotlight from "@/components/sections/WellbeingSpotlight";
import FoundersNote from "@/components/sections/FoundersNote";
// import ScreenshotMarquee from "@/components/sections/ScreenshotMarquee";
import Pricing from "@/components/sections/Pricing";
import SocialProof from "@/components/sections/SocialProof";
import FinalCTA from "@/components/sections/FinalCTA";
import Footer from "@/components/layout/Footer";

export default function Home() {
  return (
    <AnimatePresence>
      <motion.main
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 1 }}
        className="relative bg-oasis-deep"
      >
        <Navbar />
        <Hero />
        <ProblemStatement />
        <FeaturesGrid />
        <WellbeingSpotlight />
        <FoundersNote />
        {/* <ScreenshotMarquee /> */}
        <Pricing />
        <SocialProof />
        <FinalCTA />
        <Footer />
      </motion.main>
    </AnimatePresence>
  );
}
