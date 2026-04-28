import json

vcd_file = 'simulation/aoc2_p2_testbench.vcd'

def parse_vcd_window(vcd_path, target_signals, start_ns, end_ns):
    sym_to_name = {}
    scope_stack = []
    data = {sig: [] for sig in target_signals}
    
    with open(vcd_path, 'r') as f:
        reading = False
        current_time = 0
        for line in f:
            line = line.strip()
            if not reading:
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
                        for target in target_signals:
                            if full_name.lower().endswith('.' + target.lower()):
                                sym_to_name[symbol] = target
                elif line.startswith('$enddefinitions'):
                    reading = True
                continue
            
            if line.startswith('#'):
                current_time = int(line[1:]) / 1000000.0 # ns
                if current_time > end_ns + 20: break
            elif reading:
                if ' ' in line:
                    val, sym = line.split()
                else:
                    val, sym = line[0], line[1:]
                
                if sym in sym_to_name:
                    sig_name = sym_to_name[sym]
                    v = val
                    if v.startswith('b'): v = v[1:]
                    if 'x' in v.lower() or 'u' in v.lower() or 'z' in v.lower():
                        v = 0
                    else:
                        try:
                            v = int(v, 2)
                        except:
                            v = 1 if v == '1' else 0
                    
                    if current_time >= start_ns - 10:
                        if not data[sig_name] or data[sig_name][-1][1] != v:
                            data[sig_name].append((current_time, v))
                        
    return data

# Definición de los capítulos para el reporte
chapters = [
    {
        "id": "cap1",
        "title": "1. CARGA INICIAL (VÍA 0)",
        "start": 40, "end": 220,
        "signals": ['stall_mips', 'bus_req', 'bus_grant', 'mc_bus_read', 'mc_we0', 'bus_trdy', 'palabra']
    },
    {
        "id": "cap2",
        "title": "2. MARCADO DE SUCIO (DIRTY BIT)",
        "start": 340, "end": 380,
        "signals": ['we', 'hit', 'ready', 'update_dirty', 'mc_we0']
    },
    {
        "id": "cap3",
        "title": "3. FASE DE COPY-BACK (DESALOJO)",
        "start": 540, "end": 680,
        "signals": ['bus_req', 'bus_grant', 'send_dirty', 'mc_bus_write', 'mc_send_data', 'bus_trdy', 'block_copied_back']
    }
]

# Procesar datos
for cap in chapters:
    cap['data'] = parse_vcd_window(vcd_file, cap['signals'], cap['start'], cap['end'])

html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Reporte de Simulación AOC2 - Capítulos</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&family=JetBrains+Mono&display=swap" rel="stylesheet">
    <style>
        :root { --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --accent: #38bdf8; --grid: #334155; }
        body { background: var(--bg); color: var(--text); font-family: 'Inter', sans-serif; padding: 2rem; }
        .chapter { background: var(--card); border-radius: 12px; padding: 2rem; margin-bottom: 3rem; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3); }
        h2 { color: var(--accent); margin-top: 0; border-bottom: 1px solid var(--grid); padding-bottom: 0.5rem; }
        .wave-box { overflow-x: auto; position: relative; margin-top: 1rem; }
        .sig-row { display: flex; height: 50px; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.05); }
        .sig-label { width: 140px; font-family: 'JetBrains Mono'; font-size: 0.8rem; color: #94a3b8; }
        .sig-wave { flex-grow: 1; height: 30px; position: relative; }
        svg { width: 100%; height: 100%; }
        path { stroke: var(--accent); stroke-width: 2; fill: none; }
        .time-axis { display: flex; justify-content: space-between; padding-left: 140px; color: #64748b; font-size: 0.7rem; margin-top: 10px; }
    </style>
</head>
<body>
    <div style="max-width: 1000px; margin: 0 auto;">
        <h1>📚 Galería de Capturas para el Reporte</h1>
        <p>He extraído los momentos exactos definidos en tu guía. Puedes usar estas gráficas para tu documento.</p>
        
        <div id="chapters-container"></div>
    </div>

    <script>
        const chapters = __CHAPTERS__;
        const container = document.getElementById('chapters-container');

        chapters.forEach(cap => {
            const div = document.createElement('div');
            div.className = 'chapter';
            div.innerHTML = `<h2>${cap.title}</h2><div class="wave-box"></div><div class="time-axis"><span>${cap.start}ns</span><span>${cap.end}ns</span></div>`;
            
            const waveBox = div.querySelector('.wave-box');
            const duration = cap.end - cap.start;

            Object.keys(cap.data).forEach(sig => {
                const row = document.createElement('div');
                row.className = 'sig-row';
                row.innerHTML = `<div class="sig-label">${sig}</div><div class="sig-wave"><svg preserveAspectRatio="none" viewBox="0 0 ${duration} 30"></svg></div>`;
                
                const svg = row.querySelector('svg');
                let d = "";
                const pts = cap.data[sig];
                if(pts.length > 0) {
                    let lastY = pts[0][1] === 1 ? 5 : 25;
                    d = `M 0 ${lastY}`;
                    pts.forEach(p => {
                        const x = p[0] - cap.start;
                        const y = p[1] === 1 ? 5 : 25;
                        d += ` L ${x} ${lastY} L ${x} ${y}`;
                        lastY = y;
                    });
                    d += ` L ${duration} ${lastY}`;
                }
                
                const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
                path.setAttribute('d', d);
                if(sig.includes('stall') || sig.includes('dirty')) path.style.stroke = '#fbbf24';
                if(sig.includes('hit') || sig.includes('ready')) path.style.stroke = '#34d399';
                
                svg.appendChild(path);
                waveBox.appendChild(row);
            });
            container.appendChild(div);
        });
    </script>
</body>
</html>
"""

with open('outputs/reporte_grafico_caps.html', 'w', encoding='utf-8') as f:
    f.write(html_template.replace('__CHAPTERS__', json.dumps(chapters)))

print("Reporte por capítulos generado en outputs/reporte_grafico_caps.html")
