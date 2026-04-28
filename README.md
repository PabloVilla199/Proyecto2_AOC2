# AOC2 Project 2: Data Memory Hierarchy

## Overview
This repository contains the implementation of a full data memory hierarchy for a MIPS System-on-Chip (SoC), developed for the Computer Architecture and Organization 2 (AOC2) course at EINA - Universidad de Zaragoza.

The project introduces a non-trivial memory system including a Cache Memory (MC), Main Data Memory (MD), a high-speed Scratchpad Memory (MD Scratch), and a semi-synchronous Bus Arbiter. It operates strictly under a Multi-Master paradigm, allowing concurrent access petitions from the MIPS CPU and an external I/O Master module.

## Authors
- Pablo Villa
- Tahir Berga

## Key Features & Architecture
- **Data Cache Memory (MC):** 2-way set-associative cache (s=2), 128 bytes (32 words) capacity.
  - **Replacement Policy:** FIFO.
  - **Write Hit Policy:** Copy-Back.
  - **Write Miss Policy:** Write-Around (Write-No-Allocate).
- **MD Scratchpad:** A dedicated, ultra-fast memory mapped at `X"10000000"`-`X"100000FF"`. It avoids the cache completely, answering directly to the MIPS processor, inspired by GPGPU shared memory concepts.
- **Semi-Synchronous Bus Protocol:** Handshake-based bus with an arbiter enabling variable-length burst transfers. Manages bus requests (`Bus_req`) from both the MC and the generic I/O module.
- **Error Handling (Data Aborts):** Full secondary FSM resolving Memory Exception faults triggered by invalid addresses, misalignment, or illegal write attempts to Read-Only internal registers.

## Testing & Validation
All memory access cases (Read/Write Hits, Misses, Clean/Dirty Evictions) are comprehensively checked via ModelSim unit testbenches and real MIPS Assembly program execution targeting different caching edge-cases to guarantee proper cycle behavior.

### Automation & Analysis Tools
We have developed a set of Python-based tools to facilitate the analysis of VHDL simulation results:
- **Signal Extraction:** `scripts/extract_signals.py` parses VCD files to generate human-readable event logs for MIPS and UC signals.
- **Visual Dashboard:** `scripts/generate_gallery.py` creates an interactive HTML report with waveforms for key simulation milestones (Cache Misses, Copy-Back, etc.).

## Directory Structure
- `proyecto1/`: MIPS Core implementation.
- `proyecto2/`: Memory hierarchy components (Cache, Bus, RAM).
- `scripts/`: Automation and analysis scripts.
- `docs/`: Technical documentation and test plans.
- `outputs/`: Pre-generated simulation logs and visual reports.

## Usage
1. **Simulation:** Run `./ejecutar_proyecto2.sh --vcd` (requires WSL/GHDL).
2. **Analysis:** Run `python scripts/extract_signals.py` to extract event logs.
3. **Visualization:** Run `python scripts/generate_gallery.py` to view interactive waveforms in `outputs/reporte_grafico_caps.html`.

## Documentation Index
In this repository, you can find extended technical documentation split carefully into specific markdown files to simplify assessment and development tracking:

* 🏗️ **[Architecture & Use Cases (`Arquitectura_Completa_CasosUso.md`)](./Arquitectura_Completa_CasosUso.md)** — Contains the full PlantUML top-down system interconnect schematic, the strict Write-Around/Copy-Back theory, and the definitive 9-case dataflow matrix.
* 🧪 **[Testing Suite Plan (`PLAN_PRUEBAS.md`)](./PLAN_PRUEBAS.md)** — Details the 12 precise ModelSim logical Testbenches required and the proposed assembler MIPS integration script.
* 📋 **[Project Roadmap (`TODO.md`)](./TODO.md)** — Checklist of the remaining hardware blocks (Error FSM, Counters) and report components to cross off prior to the May submission.
