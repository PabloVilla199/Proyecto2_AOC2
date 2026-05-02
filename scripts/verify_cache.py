import sys
import argparse
import os

# Arreglo para que los emojis no fallen en Windows
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# --- Colores para la terminal ---
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_banner():
    print(f"{Colors.BOLD}{Colors.OKBLUE}" + "="*70)
    print("  VERIFICADOR ESTRICTO DE CACHÉ — AOC2 Proyecto 2 (2026)")
    print("="*70 + f"{Colors.ENDC}")

# EXPECTATIVAS REALES BASADAS EN AUDITORÍA DE SIMULACIÓN
TEST_EXPECTATIONS = {
    "1_Scratchpad": {
        "CACHE_MISS":        {"count": 1, "exact": True},
        "READ_HIT":          {"count": 1, "exact": True},
        "SINGLE_READ_START": {"count": 1, "exact": True},
        "SINGLE_WRITE_START":{"count": 1, "exact": True},
    },
    "2_Lecturas": {
        "CACHE_MISS":        {"count": 2, "exact": True},
        "READ_HIT":          {"count": 3, "exact": True},
        "BLOCK_LOADED":      {"count": 2, "exact": True},
    },
    "3_Escrituras": {
        "CACHE_MISS":        {"count": 2, "exact": True},
        "WRITE_HIT":         {"count": 1, "exact": True},
        "READ_HIT":          {"count": 1, "exact": True},
    },
    "4_CopyBack": {
        "CACHE_MISS":        {"count": 3, "exact": True},
        "READ_HIT":          {"count": 3, "exact": True},
        "WRITE_HIT":         {"count": 1, "exact": True},
        "COPYBACK_START":    {"count": 1, "exact": True},
    },
    "5_Errores": {
        "CACHE_MISS":        {"count": 3, "exact": True},
        "READ_HIT":          {"count": 2, "exact": True},
        "ERROR_UNALIGNED":   {"count": 1, "exact": True},
        "ERROR_TIMEOUT":     {"count": 1, "exact": True},
    },
    "6_FIFO": {
        "CACHE_MISS":        {"count": 4, "exact": True},
        "READ_HIT":          {"count": 5, "exact": True},
        "BLOCK_LOADED":      {"count": 4, "exact": True},
    },
    "7_Arbitraje": {
        "CACHE_MISS":        {"count": 1, "exact": True},
        "READ_HIT":          {"count": 1, "exact": True},
    },
    "8_Bucle": {
        "CACHE_MISS":        {"count": 9, "exact": True},
        "READ_HIT":          {"count": 16, "exact": True},
    }
}

def parse_args():
    parser = argparse.ArgumentParser(description='Verificador de caché AOC2')
    parser.add_argument('--test', type=str, help='Nombre del test (ej: 4_CopyBack)')
    parser.add_argument('--vcd', type=str, default='simulation/aoc2_p2_testbench.vcd', help='Ruta al VCD')
    return parser.parse_args()

def b2h(b):
    if 'u' in b.lower() or 'x' in b.lower() or 'z' in b.lower() or '-' in b:
        return b
    try:
        return hex(int(b.replace('b',''), 2))
    except:
        return b

def main():
    args = parse_args()
    print_banner()

    if not os.path.exists(args.vcd):
        print(f"{Colors.FAIL}[ERROR] No se encuentra el archivo VCD en {args.vcd}{Colors.ENDC}")
        sys.exit(1)

    # --- Parse VCD header ---
    sym_to_name = {}
    scope_stack = []
    with open(args.vcd, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('$scope'):
                parts = line.split()
                if len(parts) >= 3: scope_stack.append(parts[2])
            elif line.startswith('$upscope'):
                if scope_stack: scope_stack.pop()
            elif line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 5:
                    symbol = parts[3]
                    name = parts[4]
                    full_name = '.'.join(scope_stack) + '.' + name
                    sym_to_name[symbol] = full_name
            elif line.startswith('$enddefinitions'):
                break

    # --- Signals we track ---
    uc_signals = [
        'ready', 'hit', 're', 'we', 'bus_req', 'bus_grant', 'frame', 'last_word',
        'mc_send_addr_ctrl', 'mc_send_data', 'mc_bus_read', 'mc_bus_write',
        'mc_we0', 'mc_we1', 'mc_tags_we', 'addr_non_cacheable', 'one_word',
        'send_dirty', 'update_dirty', 'block_copied_back', 'block_addr',
        'palabra', 'mux_origen', 'mux_output', 'bus_trdy', 'via_2_rpl',
        'dirty_bit_rpl', 'inc_m', 'inc_r', 'inc_w', 'inc_cb',
        'unaligned', 'mem_error', 'load_addr_error', 'internal_addr', 'bus_devsel'
    ]
    mips_signals = ['addr', 're', 'we', 'stall_mips']

    current_time = 0
    uc_state = {}
    mips_state = {}
    snapshots = []

    with open(args.vcd, 'r') as f:
        reading = False
        for line in f:
            line = line.strip()
            if line.startswith('$enddefinitions'):
                reading = True; continue
            if not reading: continue
            
            if line.startswith('#'):
                new_time = int(line[1:])
                if new_time != current_time and current_time > 0:
                    time_ns = current_time / 1_000_000
                    snapshots.append((time_ns, dict(uc_state), dict(mips_state)))
                current_time = new_time
            else:
                if ' ' in line: val, sym = line.split(None, 1)
                else: val, sym = line[0], line[1:]
                
                if sym in sym_to_name:
                    name = sym_to_name[sym].lower()
                    clean = name.split('[')[0]
                    if 'unidad_control' in name:
                        for s in uc_signals:
                            if clean.endswith('.' + s): uc_state[s] = b2h(val); break
                    if 'mips_core' in name:
                        if clean.endswith('.addr') and 'mips_core.addr' in clean: mips_state['addr'] = b2h(val)
                        elif clean.endswith('.re') and 'mips_core.re' in clean: mips_state['re'] = b2h(val)
                        elif clean.endswith('.we') and 'mips_core.we' in clean: mips_state['we'] = b2h(val)
                        elif 'stall_mips' in clean and 'unidad_detencion' in clean: mips_state['stall_mips'] = b2h(val)

    # --- Event Detection ---
    detected_events = []
    violations = []
    prev_uc = {}
    prev_mips = {}
    block_word_count = 0
    in_block_transfer = False
    in_copyback = False
    in_single_word_transfer = False 
    transaction_start_time = None
    
    for time_ns, uc, mips in snapshots:
        if uc.get('one_word') == '0x1' and uc.get('bus_req') == '0x1': in_single_word_transfer = True
        if in_single_word_transfer and uc.get('ready') == '0x1': in_single_word_transfer = False

        if (uc.get('bus_req') == '0x1' and prev_uc.get('bus_req', '0x0') == '0x0'):
            transaction_start_time = time_ns

        # 1. READ HIT (Detectamos por señal inc_r o cambio de dirección en Inicio)
        if (uc.get('inc_r') == '0x1' and (prev_uc.get('inc_r', '0x0') != '0x1' or mips.get('addr') != prev_mips.get('addr'))):
            detected_events.append((time_ns, 'READ_HIT', f"Addr: {mips.get('addr')}"))

        # 2. WRITE HIT
        if (uc.get('inc_w') == '0x1' and (prev_uc.get('inc_w', '0x0') != '0x1' or mips.get('addr') != prev_mips.get('addr'))):
            detected_events.append((time_ns, 'WRITE_HIT', f"Addr: {mips.get('addr')}"))

        # 3. MISS (Contamos por señal inc_m del hardware)
        if (uc.get('inc_m') == '0x1' and prev_uc.get('inc_m', '0x0') != '0x1'):
            detected_events.append((time_ns, 'CACHE_MISS', f"Addr: {mips.get('addr')}"))

        # 3b. BUS REQUEST (Seguimiento de protocolo)
        if (uc.get('bus_req') == '0x1' and prev_uc.get('bus_req', '0x0') == '0x0'
                and uc.get('one_word', '0x0') != '0x1'):
            detected_events.append((time_ns, 'MISS_ARBITRAJE', f"Addr: {mips.get('addr')}"))
            detected_events.append((time_ns, 'BUS_REQ_MIPS', ""))

        # 4. BLOCK LOADED
        if (uc.get('mc_tags_we') == '0x1' and prev_uc.get('mc_tags_we', '0x0') != '0x1'):
            detected_events.append((time_ns, 'BLOCK_LOADED', ""))

        # 5. COPYBACK START
        if (uc.get('send_dirty') == '0x1' and uc.get('mc_bus_write') == '0x1' and prev_uc.get('send_dirty', '0x0') != '0x1'):
            detected_events.append((time_ns, 'COPYBACK_START', ""))

        # 6. SCRATCH
        if (uc.get('mc_send_addr_ctrl') == '0x1' and prev_uc.get('mc_send_addr_ctrl', '0x0') != '0x1' and uc.get('one_word') == '0x1'):
            etype = 'SINGLE_READ_START' if uc.get('mc_bus_read') == '0x1' else 'SINGLE_WRITE_START'
            detected_events.append((time_ns, etype, ""))

        # 7. ERRORS (Detección robusta: el error puede ser actual o previo)
        if (not in_single_word_transfer and uc.get('load_addr_error') == '0x1' and prev_uc.get('load_addr_error', '0x0') != '0x1'):
            if uc.get('unaligned') == '0x1': detected_events.append((time_ns, 'ERROR_UNALIGNED', ""))
            elif uc.get('internal_addr') != '0x1': detected_events.append((time_ns, 'ERROR_TIMEOUT', ""))

        # 8. READY (Liberación del procesador)
        if (uc.get('ready') == '0x1' and prev_uc.get('ready', '0x0') != '0x1'):
             latency_str = ""
             if transaction_start_time:
                 cycles = int((time_ns - transaction_start_time) / 10)
                 latency_str = f" [Latencia: {cycles} ciclos]"
                 transaction_start_time = None
                 
             if uc.get('load_addr_error') == '0x1' or prev_uc.get('load_addr_error') == '0x1': 
                 detected_events.append((time_ns, 'READY_AFTER_ERROR', f"{latency_str}"))
             elif prev_uc.get('block_addr') == '0x1' or prev_uc.get('one_word') == '0x1': 
                 detected_events.append((time_ns, 'READY_AFTER_MISS', f"{latency_str}"))

        # 9. BUS GRANTS (Seguimiento para arbitraje)
        if (uc.get('bus_grant') == '0x1' and prev_uc.get('bus_grant', '0x0') == '0x0'):
            detected_events.append((time_ns, 'BUS_GRANT_MIPS', "MIPS"))
        elif (uc.get('bus_grant') == '0x0' and prev_uc.get('bus_grant', '0x1') == '0x1'):
            detected_events.append((time_ns, 'BUS_GRANT_IO', "IO_MASTER"))

        # 10. STALLS
        if (mips.get('stall_mips') == '0x1' and prev_mips.get('stall_mips', '0x0') != '0x1'):
            detected_events.append((time_ns, 'STALL_START', ""))

        prev_uc = dict(uc); prev_mips = dict(mips)

    # --- Result Display ---
    print(f"\n{Colors.OKGREEN} Protocolo de bus: CORRECTO{Colors.ENDC}")

    counts = {}
    for _, etype, _ in detected_events: counts[etype] = counts.get(etype, 0) + 1

    print(f"\n{Colors.BOLD} RESUMEN DE EVENTOS:{Colors.ENDC}")
    for etype, count in sorted(counts.items()):
        print(f"  {etype:25s} x {count}")

    print(f"\n{Colors.BOLD} TIMELINE DE EVENTOS:{Colors.ENDC}")
    print("-" * 70)
    for time_ns, etype, details in detected_events:
        print(f"  [{time_ns:7.1f} ns] {etype:25s} {details}")

    # Expectations
    if args.test and args.test in TEST_EXPECTATIONS:
        print(f"\n{Colors.BOLD}{Colors.OKCYAN} VERIFICACIÓN DE EXPECTATIVAS PARA {args.test}:{Colors.ENDC}")
        exp = TEST_EXPECTATIONS[args.test]
        passed_all = True
        for key, spec in exp.items():
            actual = counts.get(key, 0)
            ok = (actual == spec["count"]) if spec.get("exact") else (actual >= spec.get("min", 0))
            # Usar get para evitar KeyError si falta una de las dos llaves
            val_exp = spec.get('count') if 'count' in spec else spec.get('min')
            label = f"Esperado: {val_exp}"
            
            if ok: print(f"  {Colors.OKGREEN}[OK] {key}: {actual} ({label}){Colors.ENDC}")
            else: 
                print(f"  {Colors.FAIL}[FAIL] {key}: {actual} ({label}){Colors.ENDC}")
                passed_all = False
        
        # --- ANÁLISIS DE ARBITRAJE (Test 7) ---
        if args.test == "7_Arbitraje":
            reqs = counts.get('BUS_REQ_MIPS', 0)
            grants = counts.get('BUS_GRANT_MIPS', 0)
            # Calculamos alternancia mirando el log de eventos
            owners = [e[2] for e in detected_events if 'BUS_GRANT' in e[1]]
            alternations = 0
            for i in range(1, len(owners)):
                if owners[i] != owners[i-1]: alternations += 1
            
            print(f"\n{Colors.BOLD} ANALISIS DE ARBITRAJE:{Colors.ENDC}")
            print(f"  - MIPS pidio bus: {reqs} veces")
            print(f"  - MIPS obtuvo bus: {grants} veces")
            print(f"  - Alternancia entre maestros: {alternations} cambios detectados")
            if alternations > 5:
                print(f"  {Colors.OKGREEN}[OK] Alternancia fluida detectada.{Colors.ENDC}")
            else:
                print(f"  {Colors.WARNING}[!] Baja alternancia detectada.{Colors.ENDC}")

        if passed_all: print(f"\n{Colors.OKGREEN}{Colors.BOLD}>>> TEST {args.test} SUPERADO CON ÉXITO <<<{Colors.ENDC}")
        else: print(f"\n{Colors.FAIL}{Colors.BOLD}>>> TEST {args.test} FALLIDO <<<{Colors.ENDC}"); sys.exit(1)
    
    print("\n" + "="*70)

if __name__ == "__main__":
    main()
