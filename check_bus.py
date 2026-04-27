import sys
vcd_file = 'simulation/aoc2_p2_testbench.vcd'
with open(vcd_file, 'r') as f:
    t = 0
    reading = False
    for line in f:
        if 'enddefinitions' in line: reading = True; continue
        if not reading: continue
        if line.startswith('#'): t = int(line[1:])
        elif t > 600000000: break
        else:
            parts = line.split()
            if len(parts) == 2:
                v, s = parts[0], parts[1]
                if t > 250000000:
                    if s == '"$': print(f'{t/1000000:10.1f} ns: [BUS_REQ]   = {v}')
                    if s == 'z#': print(f'{t/1000000:10.1f} ns: [BUS_GRANT] = {v}')
