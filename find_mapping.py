import sys

vcd_file = 'simulation/aoc2_p2_testbench.vcd'
target_vars = ['state', 're', 'we', 'addr_non_cacheable', 'unaligned', 'hit', 'one_word', 'addr']
var_map = {}
scope_stack = []

with open(vcd_file, 'r') as f:
    for line in f:
        line = line.strip()
        if line.startswith('$scope'):
            parts = line.split()
            if len(parts) >= 3:
                scope_stack.append(parts[2].lower())
        elif line.startswith('$upscope'):
            if scope_stack: scope_stack.pop()
        elif line.startswith('$var'):
            parts = line.split()
            if len(parts) >= 5:
                symbol = parts[3]
                name = parts[4].lower()
                full_scope = '.'.join(scope_stack)
                if 'unidad_control' in full_scope:
                    var_map[f'uc_{name}'] = symbol
                elif 'mc' == scope_stack[-1] or 'mc_datos' in full_scope:
                    var_map[f'mc_{name}'] = symbol
        elif line.startswith('$enddefinitions'):
            break

for k, v in var_map.items():
    print(f'{k}: {v}')
