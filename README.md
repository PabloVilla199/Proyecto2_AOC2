# AOC2 Project 2: Data Memory Hierarchy

## Overview
This repository contains the implementation of a data cache memory controller (MC Control Unit) for a MIPS System-on-Chip (SoC), developed for the Computer Architecture and Organization 2 (AOC2) course at EINA - Universidad de Zaragoza.

The project builds upon a provided memory subsystem that includes a Cache Memory (MC), Main Data Memory (MD), a high-speed Scratchpad Memory (MD Scratch), a semi-synchronous Bus Arbiter, and an I/O Master module. Our contribution is the **FSM-based MC Controller** (`Completar_UC_MC_2026.vhd`) that orchestrates all cache operations over this bus.

## Authors
- Pablo Villa
- Tahir Berga

## Key Features & Architecture
- **Data Cache Memory (MC):** 2-way set-associative cache (s=2), 128 bytes (32 words) capacity.
  - **Replacement Policy:** FIFO.
  - **Write Hit Policy:** Copy-Back.
  - **Write Miss Policy:** Write-Around (Write-No-Allocate).
- **MD Scratchpad:** A dedicated, ultra-fast memory mapped at `X"10000000"`-`X"100000FF"`. Accessed as non-cacheable single-word transfers.
- **Semi-Synchronous Bus Protocol:** Handshake-based bus with an arbiter enabling variable-length burst transfers. Manages bus requests (`Bus_req`) from both the MC and the IO Master.
- **Error Handling (Data Aborts):** Secondary FSM resolving Memory Exception faults triggered by:
  - No device responding to an address (`Bus_DevSel` timeout).
  - Misaligned memory accesses.
  - Write attempts to Read-Only internal registers (`Addr_Error_Reg`).
- **Event Counters:** 4 performance counters (`cont_m`, `cont_r`, `cont_w`, `cont_cb`) incrementing exactly once per event.

## Testing & Validation
We use 5 pre-loaded instruction memories (`memoriaRAM_I_Test_*.vhd`) to exercise specific scenarios:

| Test | Focus | Cases Covered |
|------|-------|---------------|
| Test 1 - Scratchpad | Basic hits | Non-cacheable reads/writes to MD Scratch |
| Test 2 - Lecturas | Read miss/hit | Cache misses, block fetches, subsequent hits |
| Test 3 - Escrituras | Write paths | Write-Around (miss), Copy-Back (hit on dirty block) |
| Test 4 - CopyBack | Dirty replacement | Full Copy-Back flow with block writeback to MD |
| Test 5 - Errores | Error handling | Misaligned access, address timeout, Data_abort |

### Automation & Analysis Tools
- **Signal Extraction:** `scripts/extract_signals.py` parses VCD files to generate human-readable event logs for MIPS and UC signals.
- **Visual Dashboard:** `scripts/generate_gallery.py` creates an interactive HTML report with waveforms.

## Directory Structure
- `proyecto1/`: MIPS Core and SoC top-level (from Project 1).
- `proyecto2/`: Memory hierarchy components (Cache, Bus, RAM, **MC Controller**).
- `scripts/`: Automation and analysis scripts.
- `docs/`: Technical documentation and test plans.
- `outputs/`: Pre-generated simulation logs and visual reports.

## Usage
1. **Simulation:** Run `wsl ./ejecutar_proyecto2.sh --vcd` (requires WSL + GHDL). Choose test 1-5.
2. **Analysis:** Run `python scripts/extract_signals.py` to extract event logs.
3. **Visualization:** Run `python scripts/generate_gallery.py` to view interactive waveforms in `outputs/reporte_grafico_caps.html`.

## Documentation Index
* 🏗️ **[Architecture & Use Cases](./docs/Arquitectura_Completa_CasosUso.md)** — System interconnect schematic, Write-Around/Copy-Back theory, and dataflow matrix.
* 🧪 **[Testing Suite Plan](./docs/PLAN_PRUEBAS.md)** — Detailed test plan with expected hit/miss per instruction.
* 📋 **[Project Roadmap](./docs/TODO.md)** — Checklist of completed and remaining tasks.
* 📐 **[Cache Internal Schematic](./docs/Esquema_Interno_Cache.md)** — MC internal organization reference.
* 📖 **[MIPS Architecture Summary](./docs/resumen_arquitectura_mips.md)** — Pipeline and memory interface reference.
