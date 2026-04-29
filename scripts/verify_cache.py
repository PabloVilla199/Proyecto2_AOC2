"""
Verificador automático de eventos de caché para AOC2 Proyecto 2.
Analiza el VCD de simulación y detecta/verifica eventos clave de la UC:
  - Read Hit, Write Hit
  - Read Miss (block transfer), Write Miss (Write-Around)
  - CopyBack (dirty block writeback)
  - Scratch access (non-cacheable single word)
  - Bus arbitration sequences
  - Error conditions (unaligned, no DevSel)

Uso: python scripts/verify_cache.py [--test N]
  Si no se especifica --test, detecta automáticamente los eventos.
"""
import sys

vcd_file = 'simulation/aoc2_p2_testbench.vcd'

# --- Parse VCD header: build symbol → full_name map ---
sym_to_name = {}
scope_stack = []
with open(vcd_file, 'r') as f:
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

def b2h(b):
    if 'u' in b.lower() or 'x' in b.lower() or 'z' in b.lower() or '-' in b:
        return b
    try:
        return hex(int(b.replace('b',''), 2))
    except:
        return b

def b2int(b):
    if 'u' in b.lower() or 'x' in b.lower() or 'z' in b.lower() or '-' in b:
        return None
    try:
        return int(b.replace('b',''), 2)
    except:
        return None

# --- Signals we track ---
uc_signals = [
    'ready', 'hit', 're', 'we', 'bus_req', 'bus_grant', 'frame', 'last_word',
    'mc_send_addr_ctrl', 'mc_send_data', 'mc_bus_read', 'mc_bus_write',
    'mc_we0', 'mc_we1', 'mc_tags_we', 'addr_non_cacheable', 'one_word',
    'send_dirty', 'update_dirty', 'block_copied_back', 'block_addr',
    'palabra', 'mux_origen', 'mux_output', 'bus_trdy', 'via_2_rpl',
    'dirty_bit_rpl', 'inc_m', 'inc_r', 'inc_w', 'inc_cb',
    'unaligned', 'mem_error', 'load_addr_error', 'internal_addr'
]
mips_signals = ['addr', 're', 'we', 'stall_mips']

# --- Parse VCD events ---
current_time = 0
# State tracking: current value of each signal
uc_state = {}   # signal_short_name -> value
mips_state = {} # signal_short_name -> value

# Event log: list of (time_ns, event_type, details)
events_log = []

# Snapshots at each timestamp for analysis
snapshots = []  # list of (time_ns, uc_state_copy, mips_state_copy)

with open(vcd_file, 'r') as f:
    reading = False
    for line in f:
        line = line.strip()
        if line.startswith('$enddefinitions'):
            reading = True
            continue
        if not reading:
            continue
        
        if line.startswith('#'):
            new_time = int(line[1:])
            if new_time != current_time and current_time > 0:
                time_ns = current_time / 1_000_000
                if 20 < time_ns < 5000:
                    snapshots.append((time_ns, dict(uc_state), dict(mips_state)))
            current_time = new_time
        else:
            if ' ' in line:
                val, sym = line.split(None, 1)
            else:
                val, sym = line[0], line[1:]
            
            if sym in sym_to_name:
                name = sym_to_name[sym].lower()
                clean = name.split('[')[0]
                
                # UC signals
                if 'unidad_control' in name:
                    for s in uc_signals:
                        if clean.endswith('.' + s):
                            uc_state[s] = b2h(val)
                            break
                
                # MIPS signals
                if 'mips_core' in name:
                    if clean.endswith('.addr') and 'mips_core.addr' in clean:
                        mips_state['addr'] = b2h(val)
                    elif clean.endswith('.re') and 'mips_core.re' in clean:
                        mips_state['re'] = b2h(val)
                    elif clean.endswith('.we') and 'mips_core.we' in clean:
                        mips_state['we'] = b2h(val)
                    elif 'stall_mips' in clean and 'unidad_detencion' in clean:
                        mips_state['stall_mips'] = b2h(val)

# Add last snapshot
time_ns = current_time / 1_000_000
if 20 < time_ns < 5000:
    snapshots.append((time_ns, dict(uc_state), dict(mips_state)))

# --- Event Detection Engine ---
detected_events = []
prev_uc = {}
prev_mips = {}

for time_ns, uc, mips in snapshots:
    # --- ERROR: UNALIGNED ---
    if (uc.get('unaligned') == '0x1' and (uc.get('re') == '0x1' or uc.get('we') == '0x1')
        and uc.get('load_addr_error') == '0x1' and prev_uc.get('load_addr_error', '0x0') != '0x1'):
        addr = mips.get('addr', '?')
        detected_events.append((time_ns, 'ERROR_UNALIGNED', f'Dirección no alineada: {addr}'))

    # --- ERROR: BUS TIMEOUT (DevSel=0) ---
    if (uc.get('load_addr_error') == '0x1' and prev_uc.get('load_addr_error', '0x0') != '0x1'
        and uc.get('unaligned', '0x0') != '0x1' and uc.get('internal_addr', '0x0') != '0x1'):
        addr = mips.get('addr', '?')
        detected_events.append((time_ns, 'ERROR_TIMEOUT', f'Timeout de bus (DevSel=0) en {addr}'))

    # --- ERROR: INTERNAL REGISTER CLEAR ---
    if (uc.get('internal_addr') == '0x1' and uc.get('re') == '0x1' and uc.get('ready') == '0x1'
        and prev_uc.get('mem_error', '0x0') == '0x1' and uc.get('mem_error', '0x0') == '0x0'):
        detected_events.append((time_ns, 'ERROR_INTERNAL_CLEAR', 'Error limpiado por lectura de registro interno'))

    # --- INTERNAL REGISTER HIT ---
    if (uc.get('internal_addr') == '0x1' and uc.get('re') == '0x1' and uc.get('ready') == '0x1'
        and prev_uc.get('hit', '0x0') == '0x0'):
        # Check if it was already caught as a CLEAR, if not, log as HIT
        if not any(e[0] == time_ns and e[1] == 'ERROR_INTERNAL_CLEAR' for e in detected_events):
            detected_events.append((time_ns, 'INTERNAL_REG_HIT', 'Lectura de registro interno (MC)'))

    # --- READ HIT ---
    if (uc.get('re') == '0x1' and uc.get('hit') == '0x1' and uc.get('ready') == '0x1'
        and uc.get('bus_req', '0x0') == '0x0'
        and prev_uc.get('hit', '0x0') != '0x1'):
        addr = mips.get('addr', '?')
        nc = ' [SCRATCH]' if uc.get('addr_non_cacheable') == '0x1' else ''
        detected_events.append((time_ns, 'READ_HIT', f'addr={addr}{nc}'))
    
    # --- WRITE HIT ---
    if (uc.get('we') == '0x1' and uc.get('hit') == '0x1' and uc.get('ready') == '0x1'
        and uc.get('update_dirty') == '0x1'
        and prev_uc.get('update_dirty', '0x0') != '0x1'):
        addr = mips.get('addr', '?')
        via = 'vía0' if uc.get('mc_we0') == '0x1' else ('vía1' if uc.get('mc_we1') == '0x1' else '?')
        detected_events.append((time_ns, 'WRITE_HIT', f'addr={addr} → {via} (dirty)'))
    
    # --- MISS (bus_req rises) ---
    if (uc.get('bus_req') == '0x1' and prev_uc.get('bus_req', '0x0') == '0x0'
        and uc.get('ready', '0x1') != '0x1'):
        addr = mips.get('addr', '?')
        op = 'read' if mips.get('re') == '0x1' else ('write' if mips.get('we') == '0x1' else '?')
        detected_events.append((time_ns, 'MISS_ARBITRAJE', f'addr={addr} op={op}'))
    
    # --- BUS GRANT ---
    if (uc.get('bus_grant') == '0x1' and prev_uc.get('bus_grant', '0x0') != '0x1'
        and uc.get('bus_req') == '0x1'):
        detected_events.append((time_ns, 'BUS_GRANT', ''))
    
    # --- BLOCK TRANSFER START (addr phase) ---
    if (uc.get('mc_send_addr_ctrl') == '0x1' and prev_uc.get('mc_send_addr_ctrl', '0x0') != '0x1'
        and uc.get('block_addr') == '0x1'):
        if uc.get('mc_bus_read') == '0x1':
            detected_events.append((time_ns, 'BLOCK_READ_START', 'Lectura de bloque de MD'))
        elif uc.get('mc_bus_write') == '0x1' and uc.get('send_dirty') == '0x1':
            detected_events.append((time_ns, 'COPYBACK_START', 'Escritura bloque sucio a MD'))
    
    # --- SINGLE WORD TRANSFER START ---
    if (uc.get('mc_send_addr_ctrl') == '0x1' and prev_uc.get('mc_send_addr_ctrl', '0x0') != '0x1'
        and uc.get('one_word') == '0x1'):
        if uc.get('mc_bus_read') == '0x1':
            detected_events.append((time_ns, 'SINGLE_READ_START', 'Lectura single-word (Scratch/non-cacheable)'))
        elif uc.get('mc_bus_write') == '0x1':
            detected_events.append((time_ns, 'SINGLE_WRITE_START', 'Escritura single-word (Write-Around/Scratch)'))
    
    # --- BLOCK TRANSFER COMPLETE (tags written) ---
    if (uc.get('mc_tags_we') == '0x1' and prev_uc.get('mc_tags_we', '0x0') != '0x1'):
        via = 'vía1' if uc.get('via_2_rpl') == '0x1' else 'vía0'
        detected_events.append((time_ns, 'BLOCK_LOADED', f'Tags escritos → {via}'))
    
    # --- COPYBACK COMPLETE ---
    if (uc.get('block_copied_back') == '0x1' and prev_uc.get('block_copied_back', '0x0') != '0x1'):
        detected_events.append((time_ns, 'COPYBACK_DONE', 'Bloque sucio escrito en MD'))
    
    # --- SINGLE WORD COMPLETE (ready rises during single_word_transfer) ---
    if (uc.get('ready') == '0x1' and prev_uc.get('ready', '0x0') != '0x1'
        and uc.get('one_word') == '0x1' and uc.get('last_word') == '0x1'):
        detected_events.append((time_ns, 'SINGLE_WORD_DONE', 'Transferencia single-word completada'))
    
    # --- READY RISES (MIPS unstalled) ---
    if (uc.get('ready') == '0x1' and prev_uc.get('ready', '0x0') != '0x1'
        and uc.get('one_word', '0x0') != '0x1'):
        if uc.get('hit') == '0x1':
            detected_events.append((time_ns, 'READY_AFTER_MISS', 'MIPS desbloqueado tras miss'))
        elif uc.get('load_addr_error') == '0x1' or prev_uc.get('load_addr_error') == '0x1':
             detected_events.append((time_ns, 'READY_AFTER_ERROR', 'MIPS desbloqueado tras error'))
    
    # --- COUNTER INCREMENTS ---
    if uc.get('inc_m') == '0x1' and prev_uc.get('inc_m', '0x0') != '0x1':
        detected_events.append((time_ns, 'COUNTER', 'cont_m++ (miss)'))
    if uc.get('inc_r') == '0x1' and prev_uc.get('inc_r', '0x0') != '0x1':
        detected_events.append((time_ns, 'COUNTER', 'cont_r++ (read)'))
    if uc.get('inc_w') == '0x1' and prev_uc.get('inc_w', '0x0') != '0x1':
        detected_events.append((time_ns, 'COUNTER', 'cont_w++ (write)'))
    if uc.get('inc_cb') == '0x1' and prev_uc.get('inc_cb', '0x0') != '0x1':
        detected_events.append((time_ns, 'COUNTER', 'cont_cb++ (copyback)'))
    
    # --- STALL starts ---
    if (mips.get('stall_mips') == '0x1' and prev_mips.get('stall_mips', '0x0') != '0x1'):
        detected_events.append((time_ns, 'STALL_START', f'MIPS detenido'))
    
    # --- STALL ends ---
    if (mips.get('stall_mips') == '0x0' and prev_mips.get('stall_mips', '0x1') == '0x1'
        and prev_mips.get('stall_mips') is not None):
        detected_events.append((time_ns, 'STALL_END', f'MIPS reanudado'))
    
    prev_uc = dict(uc)
    prev_mips = dict(mips)

# --- Protocol Assertion Engine ---
violations = []
block_word_count = 0
in_block_transfer = False
in_copyback = False
stall_start_time = None

for time_ns, uc, mips in snapshots:
    # 1. Track Block Transfer Word Counts
    if uc.get('block_addr') == '0x1' and uc.get('mc_bus_read') == '0x1':
        if not in_block_transfer:
            in_block_transfer = True
            block_word_count = 0
        if uc.get('bus_trdy') == '0x1' and prev_uc.get('bus_trdy') != '0x1':
            block_word_count += 1
    
    if uc.get('mc_tags_we') == '0x1' and prev_uc.get('mc_tags_we') != '0x1':
        if block_word_count != 4:
            violations.append(f"[{time_ns} ns] VIOLACIÓN: Carga de bloque con {block_word_count} palabras (esperadas 4)")
        in_block_transfer = False

    # 2. Track CopyBack Word Counts
    if uc.get('send_dirty') == '0x1' and uc.get('mc_bus_write') == '0x1':
        if not in_copyback:
            in_copyback = True
            block_word_count = 0
        if uc.get('bus_trdy') == '0x1' and prev_uc.get('bus_trdy') != '0x1':
            block_word_count += 1
            
    if uc.get('block_copied_back') == '0x1' and prev_uc.get('block_copied_back') != '0x1':
        if block_word_count != 4:
            violations.append(f"[{time_ns} ns] VIOLACIÓN: CopyBack con {block_word_count} palabras (esperadas 4)")
        in_copyback = False

    # 3. Stall Continuity Check
    if mips.get('stall_mips') == '0x1':
        if stall_start_time is None: stall_start_time = time_ns
    else:
        if stall_start_time is not None:
            if uc.get('ready') != '0x1' and uc.get('mem_error') != '0x1':
                violations.append(f"[{time_ns} ns] VIOLACIÓN: Stall liberado sin READY ni ERROR")
            stall_start_time = None

    # 4. Bus Protocol: No data without DevSel
    if uc.get('bus_trdy') == '0x1' and uc.get('bus_devsel') == '0x0':
        violations.append(f"[{time_ns} ns] VIOLACIÓN: Data transfer (TRDY) sin DevSel")

    prev_uc = dict(uc)
    prev_mips = dict(mips)

# --- Output Results ---
print("=" * 70)
print("  VERIFICADOR ESTRICTO DE CACHÉ — AOC2 Proyecto 2")
print("=" * 70)

if violations:
    print("\n❌ VIOLACIONES DE PROTOCOLO DETECTADAS:")
    print("-" * 70)
    for v in violations:
        print(f"  {v}")
else:
    print("\n✅ Protocolo de bus y arquitectura: CORRECTO")

# Summary counts
event_types = {}
for _, etype, _ in detected_events:
    event_types[etype] = event_types.get(etype, 0) + 1

print("\n📊 RESUMEN DE EVENTOS DETECTADOS:")
print("-" * 40)
event_labels = {
    'READ_HIT': ' Read Hit',
    'WRITE_HIT': ' Write Hit (dirty)',
    'MISS_ARBITRAJE': ' Miss → Arbitraje',
    'BUS_GRANT': ' Bus Grant',
    'BLOCK_READ_START': ' Block Read (inicio)',
    'BLOCK_LOADED': ' Block Loaded (tags)',
    'SINGLE_READ_START': ' Single Read (inicio)',
    'SINGLE_WRITE_START': ' Single Write (inicio)',
    'SINGLE_WORD_DONE': ' Single Word (fin)',
    'COPYBACK_START': ' CopyBack (inicio)',
    'COPYBACK_DONE': ' CopyBack (fin)',
    'READY_AFTER_MISS': ' Ready tras miss',
    'READY_AFTER_ERROR': ' Ready tras error',
    'ERROR_UNALIGNED': ' ERROR: No alineado',
    'ERROR_TIMEOUT': ' ERROR: Timeout bus',
    'ERROR_INTERNAL_CLEAR': ' Error limpiado (registro)',
    'INTERNAL_REG_HIT': ' Lectura reg. interno',
    'STALL_START': ' Stall MIPS',
    'STALL_END': ' MIPS reanudado',
    'COUNTER': ' Contador',
}
for etype, label in event_labels.items():
    count = event_types.get(etype, 0)
    if count > 0:
        print(f"  {label:35s} × {count}")

print(f"\n  Total eventos detectados: {len(detected_events)}")

# Timeline
print("\n📋 TIMELINE DE EVENTOS:")
print("-" * 70)
for time_ns, etype, details in detected_events:
    label = event_labels.get(etype, etype)
    print(f"  [{time_ns:7.1f} ns] {label:35s} — {details}")

# --- Verification Checks ---
print("\n" + "=" * 70)
print("  VERIFICACIONES DE INTEGRIDAD")
print("=" * 70)

checks_passed = 0
checks_failed = 0
checks_total = 0

def check(condition, description):
    global checks_passed, checks_failed, checks_total
    checks_total += 1
    if condition:
        checks_passed += 1
        print(f"  ✅ PASS: {description}")
    else:
        checks_failed += 1
        print(f"  ❌ FAIL: {description}")

# Check 0: Strict Protocol
check(len(violations) == 0, "Protocolo de bus (palabras/bloque, señales control)")

# Check 1: At least one miss detected
miss_count = event_types.get('MISS_ARBITRAJE', 0)
check(miss_count > 0, f"Se detectaron misses de caché ({miss_count} encontrados)")

# Check 2: Bus grant after every miss
grant_count = event_types.get('BUS_GRANT', 0)
check(grant_count >= miss_count, f"Bus_grant recibido tras cada miss ({grant_count} grants para {miss_count} misses)")

# Check 3: MIPS unstalls after every stall
stall_starts = event_types.get('STALL_START', 0)
stall_ends = event_types.get('STALL_END', 0)
check(stall_ends >= stall_starts, f"MIPS se desbloquea tras cada stall ({stall_ends} ends para {stall_starts} starts)")

# Check 4: Frame goes down (returns to Inicio)
ready_events = [e for e in detected_events if e[1] in ('READY_AFTER_MISS', 'READY_AFTER_ERROR', 'SINGLE_WORD_DONE')]
check(len(ready_events) > 0, f"Ready vuelve a '1' tras transacciones de bus ({len(ready_events)} veces)")

# Check 5: Block transfers complete with tags (skip if timeout)
block_starts = event_types.get('BLOCK_READ_START', 0)
block_loads = event_types.get('BLOCK_LOADED', 0)
timeouts = event_types.get('ERROR_TIMEOUT', 0)
if block_starts > 0:
    if timeouts > 0:
        check(block_loads + timeouts >= block_starts, f"Block reads completados o abortados por timeout ({block_loads} tags, {timeouts} timeouts para {block_starts} lecturas)")
    else:
        check(block_loads == block_starts, f"Cada block read completa tags ({block_loads} tags para {block_starts} lecturas)")

# Check 6: CopyBack completes if started
cb_starts = event_types.get('COPYBACK_START', 0)
cb_dones = event_types.get('COPYBACK_DONE', 0)
if cb_starts > 0:
    check(cb_dones == cb_starts, f"Cada CopyBack se completa ({cb_dones} completos de {cb_starts} iniciados)")

# Check 7: Single word transfers complete
sw_starts = event_types.get('SINGLE_READ_START', 0) + event_types.get('SINGLE_WRITE_START', 0)
sw_dones = event_types.get('SINGLE_WORD_DONE', 0)
if sw_starts > 0:
    check(sw_dones >= sw_starts, f"Single-word transfers se completan ({sw_dones} de {sw_starts})")

# Check 8: Counters fire correctly
counter_events = [e for e in detected_events if e[1] == 'COUNTER']
miss_counters = sum(1 for e in counter_events if 'cont_m' in e[2])
if miss_count > 0:
    check(miss_counters > 0, f"cont_m se incrementa al detectar miss ({miss_counters} incrementos)")

read_hits = event_types.get('READ_HIT', 0)
read_counters = sum(1 for e in counter_events if 'cont_r' in e[2])
if read_hits > 0:
    check(read_counters > 0, f"cont_r se incrementa en read hits ({read_counters} incrementos)")

write_hits = event_types.get('WRITE_HIT', 0)
write_counters = sum(1 for e in counter_events if 'cont_w' in e[2])
if write_hits > 0:
    check(write_counters > 0, f"cont_w se incrementa en write hits ({write_counters} incrementos)")

cb_counters = sum(1 for e in counter_events if 'cont_cb' in e[2])
if cb_dones > 0:
    check(cb_counters > 0, f"cont_cb se incrementa en CopyBack ({cb_counters} incrementos)")

# Check 9: No permanent stall (MIPS not stuck)
last_stall = None
for e in detected_events:
    if e[1] == 'STALL_START': last_stall = e[0]
    if e[1] == 'STALL_END': last_stall = None
if last_stall is not None:
    # Check if it's stuck at the end (beq loop is ok)
    last_event_time = detected_events[-1][0] if detected_events else 0
    check(last_event_time - last_stall < 50, f"MIPS no se queda colgado indefinidamente (último stall a {last_stall:.1f} ns)")
else:
    check(True, "MIPS no se queda colgado indefinidamente")

# Final summary
print("\n" + "-" * 40)
if checks_failed == 0:
    print(f"  🎯 RESULTADO: {checks_passed}/{checks_total} verificaciones PASADAS")
else:
    print(f"  ⚠️  RESULTADO: {checks_passed}/{checks_total} pasadas, {checks_failed} FALLIDAS")
print()
