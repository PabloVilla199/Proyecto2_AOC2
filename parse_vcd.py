import sys

vcd_file = 'simulation/aoc2_p2_testbench.vcd'
# Busquemos los símbolos para las señales que nos importan
# 7: addr (MIPS)
# b#: addr_non_cacheable (Unidad de Control)
# q#: unaligned (Unidad de Control)
# \#: re (Unidad de Control)
# ]#: we (Unidad de Control)
# &$: hit (Unidad de Control)

target_syms = {'7': 'addr_mips', 'b#': 'non_cacheable', 'q#': 'unaligned', '\\#': 're', ']#': 'we', '&$': 'hit'}
events = []
current_time = 0

def b2h(b):
    if 'u' in b.lower() or 'x' in b.lower(): return b
    try:
        return hex(int(b.replace('b',''), 2))
    except:
        return b

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
            if current_time > 10000000: break # Solo los primeros 10 us
        else:
            if ' ' in line:
                val, sym = line.split()
            else:
                val, sym = line[0], line[1:]
            
            if sym in target_syms:
                name = target_syms[sym]
                v = b2h(val) if 'addr' in name else val
                events.append((current_time, name, v))

print("--- Análisis de Secuencia de Test 1 ---")
for t, name, val in sorted(events):
    if t > 5000: # Ignorar el reset inicial
        print(f'{t/1000:10.1f} ps: {name:20} = {val}')
