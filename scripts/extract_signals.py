import sys

vcd_file = 'simulation/aoc2_p2_testbench.vcd'

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
    if 'u' in b.lower() or 'x' in b.lower() or 'z' in b.lower() or '-' in b: return b
    try:
        return hex(int(b.replace('b',''), 2))
    except:
        return b

current_time = 0

# Targets solicitados:
# MIPS: stall_mips, we, re, addr (solo mips_core.addr)
# UC: bus_req, bus_grant, frame, last_word, mc_send_addr_ctrl, mc_send_data, 
#     mc_bus_read, mc_bus_write, mc_we0, mc_we1, mc_tags_we, ready, hit, addr_non_cacheable,
#     palabra, mux_origen, mux_output, block_addr
targets = [
    'stall_mips', 'we', 're', 'addr', 
    'bus_req', 'bus_grant', 'frame', 'last_word', 'mc_send_addr_ctrl', 'mc_send_data',
    'mc_bus_read', 'mc_bus_write', 'mc_we0', 'mc_we1', 'mc_tags_we', 'ready', 'hit', 
    'addr_non_cacheable', 'palabra', 'mux_origen', 'mux_output', 'block_addr', 'one_word', 'bus_trdy',
    'send_dirty', 'update_dirty', 'block_copied_back', 'via_2_rpl', 'dirty_bit_rpl'
]

events = []
with open(vcd_file, 'r') as f:
    reading = False
    for line in f:
        line = line.strip()
        if line.startswith('$enddefinitions'):
            reading = True
            continue
        if not reading: continue
        
        if line.startswith('#'):
            current_time = int(line[1:])
        else:
            if ' ' in line:
                val, sym = line.split()
            else:
                val, sym = line[0], line[1:]
            
            if sym in sym_to_name:
                name = sym_to_name[sym].lower()
                clean_name = name.split('[')[0]
                
                # Para evitar duplicados de mips, exigimos que 'addr' sea mips_core.addr 
                if clean_name.endswith('.addr') and not 'mips_core.addr' in clean_name:
                    continue
                # we, re del mips o de la UC (pero no de los bancos internos)
                if clean_name.endswith('.we') and not ('mips_core.we' in clean_name or 'unidad_control.we' in clean_name):
                    continue
                if clean_name.endswith('.re') and not ('mips_core.re' in clean_name or 'unidad_control.re' in clean_name):
                    continue
                
                # Filtrar a UC y MIPS, ignorando otros
                if ('unidad_control' in name or 'mips_core' in name):
                    if any(clean_name.endswith('.' + t) for t in targets):
                        v = b2h(val)
                        events.append((current_time, clean_name, v))

grouped_events = {}
for t, name, val in events:
    if t not in grouped_events:
        grouped_events[t] = []
    # Avoid duplicate signal assignments at the same time
    if (name, val) not in grouped_events[t]:
        grouped_events[t].append((name, val))

print("=== Análisis Detallado de Señales (UC y MIPS) ===")
for t in sorted(grouped_events.keys()):
    time_ns = t / 1000000.0  
    if time_ns < 40 or time_ns > 1000: continue 
    
    if not grouped_events[t]: continue
    
    print(f'[{time_ns:6.1f} ns]')
    
    # Ordenamos un poco para que sea más fácil de leer (MIPS primero, luego UC)
    mips_evs = [ev for ev in grouped_events[t] if 'mips_core' in ev[0]]
    uc_evs = [ev for ev in grouped_events[t] if 'unidad_control' in ev[0]]
    
    if mips_evs:
        print("  -- MIPS --")
        for name, val in mips_evs:
            short_name = name.replace('testbench.uut.mips_core.', '')
            print(f'    {short_name:30} = {val}')
            
    if uc_evs:
        print("  -- UNIDAD CONTROL --")
        for name, val in uc_evs:
            short_name = name.replace('testbench.uut.io_mem.mc.unidad_control.', '')
            print(f'    {short_name:30} = {val}')
