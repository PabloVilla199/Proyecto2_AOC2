# Planificación y Tareas Pendientes (TODO) - AOC2 P2

Esta lista organiza todo lo requerido por la guía oficial del proyecto para alcanzar la máxima nota, dividido por fases de desarrollo.

## 1. Diseño Hardware (Controlador MC)
- [x] Implementar la **Máquina de Estados (FSM) Principal** para procesar aciertos y fallos de lectura/escritura (gestionando las señales del Bus Semi-síncrono).
  - [x] Estado `Inicio`: despacho de hits (lectura/escritura), accesos no cacheables, registros internos, errores de alineamiento.
  - [x] Estado `Send_Addr`: arbitraje del bus (`Bus_req`/`Bus_grant`).
  - [x] Estados `block_transfer_addr` / `block_transfer_data`: lectura de bloque completo (4 palabras).
  - [x] Estado `CopyBack`: escritura de bloque sucio a MD antes de reemplazo.
  - [x] Estados `single_word_transfer_addr` / `single_word_transfer_data`: Write-Around y accesos a Scratch.
  - [x] Estado `bajar_Frame`: desactivación limpia del bus.
- [x] Implementar la **FSM Secundaria (Manejo de Errores)** que controla la señal `Mem_Error` (Data Abort):
  - [x] Trigger A: Ningún dispositivo responde validando la dirección (`Bus_DevSel='0'`).
  - [x] Trigger B: Acceso desalineado por el procesador MIPS.
  - [x] Trigger C: Intento de escritura a registro Read-Only (`Addr_Error_Reg`).
- [x] Registro `Addr_Error_Reg` mapeado en `x"01000000"`. Lectura limpia `Mem_Error`.
- [x] Conectar los 4 Event Counters de Rendimiento:
  - [x] `cont_m`: Fallos de Caché (solo direcciones cacheables).
  - [x] `cont_w`: Escrituras efectivas en MC.
  - [x] `cont_r`: Lecturas efectivas desde MC.
  - [x] `cont_cb`: Copy-Backs de bloques sucios. Incrementan **1 sola vez por evento**.

## 2. Testing y Verificación
- [x] **Tests Unitarios (RAM-I preconfiguradas):**
  - [x] Test 1 - Scratchpad: aciertos básicos, accesos no cacheables.
  - [x] Test 2 - Lecturas: fallos y aciertos de lectura en distintos conjuntos/vías.
  - [x] Test 3 - Escrituras: Write-Around en miss, Copy-Back en hit con bloque sucio.
  - [x] Test 4 - CopyBack: reemplazo de bloque sucio completo.
  - [x] Test 5 - Errores: acceso desalineado, timeout de bus, Data_abort.
- [ ] **Test de Integración Global:**
  - [ ] Programa ensamblador MIPS que cubra todos los flujos en una sola ejecución.
- [ ] **Documentar** cada test con tabla de hit/miss/set/vía esperados (para la memoria).

## 3. Preparación del Informe / Memoria
- [ ] Dibujar el **Grafo de Estados Final** con señales activas por estado y tabla Mealy.
- [ ] Diagrama de desglose de dirección `[ Tag (26b) | Set (2b) | Word (2b) | Byte (2b) ]`.
- [ ] Extraer latencias de bus desde simulación: `CrB(MD)`, `CwW(MD)`, `CrW(MDscratch)`, etc.
- [ ] Fórmula de **Ciclos Medios por Acceso a Memoria** (con verificación por simulación).
- [ ] Calcular **Speedup** vs sistema sin caché.
- [ ] Registro temporal de dedicación y Autoevaluación de Equipo.

## 4. Mejoras Opcionales (Si hay tiempo)
- [ ] **Write Buffer (Lockup-free cache)**
- [ ] **Critical Word Forwarding**
- [ ] **Simulación DDoS / Hacking ético**

## Observaciones sobre el código proporcionado
- ⚠️ En `IO_MD_subsystem_P2_26.vhd` (línea ~266), el MUX del bus no incluye `IO_M_Data`. Esto impide que el IO_Master escriba correctamente en la Scratch. No afecta a la MC ni a nuestros tests. Consultado con los profesores.
- ⚠️ El puerto `IO_M_Fetch_inc` no está enlazado en el port map del IO_Master. Genera un warning en compilación pero sin impacto funcional.
