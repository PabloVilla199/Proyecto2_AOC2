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
    if 'u' in b.lower() or 'x' in b.lower(): return b
    try:
        return hex(int(b.replace('b',''), 2))
    except:
        return b

current_time = 0
# Señales para ver el STALL
targets = ['stall_mips', 're', 'we', 'hit', 'bus_req']

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
            if current_time > 1000000000: break
        else:
            if ' ' in line:
                val, sym = line.split()
            else:
                val, sym = line[0], line[1:]
            
            if sym in sym_to_name:
                name = sym_to_name[sym].lower()
                if any(t in name for t in targets) and ('ud' in name or 'mc' in name):
                    v = b2h(val)
                    # Mostrar toda la evolución del stall
                    print(f'{current_time/1000000:10.1f} ns: {name:50} = {v}')
