# Implementation Plan - Aegis-One Storage Engine Features

This plan outlines the technical changes required to implement the complete Aegis-One storage simulation, FTL mapping, CLI benchmark, 1M-write absorption demo, thermal simulator dashboard, and dynamic Enterprise IT Savings calculator.

## User Review Required

> [!IMPORTANT]
> - The new FTL mapping and 8-channel round-robin striping will be simulated inside the Rust core (`infinity_cache_core`).
> - We will add the `temperature` and `performance_multiplier` fields to the telemetry packet.
> - A new CLI benchmark utility `infinity_cache_bench` will be added to the Cargo workspace.
> - The Flutter UI will be expanded with a 4th tab: **THERMAL DYNAMICS** to show real-time temperature profiles.
> - The TCO tab will be upgraded with interactive sliders for fleet size, evaluation period, and write workload.

## Proposed Changes

---

### Component: Core Storage Engine (`infinity_cache_core`)

#### [MODIFY] [lib.rs](file:///e:/infinity_cache_sim/infinity_cache_core/src/lib.rs)
- **FTL Mapping & 8-Channel Striping**: Add `ftl_map` (HashMap) and `dirty_pages` (HashSet) to `AegisEngine`.
- **Address Translation**: Allocate physical block addresses (PBA) sequentially and map them to the 8 eMMC chips: `chip_idx = (pba % 8) as usize`.
- **Write Coalescing**: Implement a background writeback task that flushes dirty pages in batches to the eMMC array, demonstrating how DRAM protects eMMC from write amplification.
- **Thermal State**: Add dynamic temperature calculation to `AegisEngine`. Temperature rises with active writes and cools down toward ambient temperature.
- **Telemetry Update**: Add `temperature` and `performance_multiplier` fields to the `Telemetry` struct.

---

### Component: CLI Benchmark Utility (`infinity_cache_bench`)

#### [NEW] [Cargo.toml](file:///e:/infinity_cache_sim/infinity_cache_bench/Cargo.toml)
- Define a new binary crate `infinity_cache_bench` inside the workspace.

#### [NEW] [main.rs](file:///e:/infinity_cache_sim/infinity_cache_bench/src/main.rs)
- Implement a command-line utility that runs a synthetic stress test of 1,000,000 writes.
- Simulate Aegis-One (DRAM caching + FTL coalesced writeback) vs. a Samsung 990 Pro (direct QLC flash writes with WAF=3.5 and aluminum thermal throttling).
- Print a beautiful formatted comparison table showing execution time, IOPS, peak throughput, operating temperature, and physical wear.

---

### Component: Interception Daemon (`infinity_cache_daemon`)

#### [MODIFY] [main.rs](file:///e:/infinity_cache_sim/infinity_cache_daemon/src/main.rs)
- Expose the new telemetry fields (`temperature` and `performance_multiplier`) to WS clients.
- Add support for new WebSocket commands:
  - `START_1M_DEMO`: Trigger a high-speed write loop of 1,000,000 writes.
  - `START_THERMAL_STRESS` / `STOP_THERMAL_STRESS`: Simulate heavy load to drive up temperature.

---

### Component: User Interface (`infinity_cache_ui`)

#### [MODIFY] [daemon_bridge.dart](file:///e:/infinity_cache_sim/infinity_cache_ui/lib/services/daemon_bridge.dart)
- Parse new telemetry fields `temperature` and `performanceMultiplier` from the daemon WebSocket.
- Add support for triggering `START_1M_DEMO`, `START_THERMAL_STRESS`, and `STOP_THERMAL_STRESS`.
- Maintain history arrays for temperatures of both Aegis-One and the baseline NVMe drive.

#### [MODIFY] [dashboard.dart](file:///e:/infinity_cache_sim/infinity_cache_ui/lib/screens/dashboard.dart)
- **Cell Health Map Tab**: Add an interactive panel for the **1M-Write Absorption Demo** showing the live wear reduction ratio.
- **Thermal Dynamics Tab**: Create a new tab showing live charts comparing Aegis-One temperature vs. standard NVMe temperature and active throttle status.
- **TCO & Sustainability Tab**: Re-engineer the page to include interactive sliders (Fleet Size, Evaluation Period, Daily Writes) and dynamically calculate financial savings, SSD lifespan extension, and carbon footprint reduction.

## Verification Plan

### Automated Tests
- Build and run the core engine, daemon, and UI to ensure compilation.
- Run the new CLI benchmark:
  ```powershell
  cargo run -p infinity_cache_bench
  ```

### Manual Verification
- Launch the Flutter UI and verify each tab:
  - Trigger the 1M-Write absorption test and observe the write reduction ratio.
  - View the Thermal Dynamics tab, trigger thermal stress, and verify that the standard NVMe throttles while Aegis-One remains cool.
  - Adjust sliders in the TCO tab and verify that the financial savings and e-waste reduction metrics scale dynamically.
