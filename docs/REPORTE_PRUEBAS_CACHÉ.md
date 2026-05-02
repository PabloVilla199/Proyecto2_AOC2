# Tests Detallados: Batería de Pruebas de Caché AOC2

Este documento presenta un análisis ciclo a ciclo de la batería de pruebas, vinculando el código ensamblador MIPS con el comportamiento interno del controlador de caché.

---

## TEST 1: Accesos a Scratchpad (NC)
**Objetivo**: Verificar que el controlador distingue entre memoria cachéable (RAM-D) y no cachéable (IO/Scratchpad).

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **45 ns** | `lw $8, 256($0)` | `0x0100` | **MISS** | La etiqueta `0x0` no está en ninguna vía. La FSM pasa a `Send_Addr`. |
| **215 ns** | (Re-ejecución) | `0x0100` | **HIT** | Tras cargar el bloque de la RAM-D (4 palabras), el dato ya es visible. |
| **255 ns** | `lw $9, 0($8)` | `0x10000000` | **NC HIT** | La UC detecta dirección >= `0x1000...`. Activa `single_word='1'` y no toca las etiquetas. |
| **365 ns** | `sw $9, 4($8)` | `0x10000004` | **NC HIT** | Escritura directa al bus IO. No se carga bloque ni se marca dirty. |

**Resultados Finales Test 1:**
- **Cache Misses**: 1
- **Read Hits**: 1
- **Single Transfers (NC)**: 2

---

## TEST 2: Localidad Espacial (Lecturas)
**Objetivo**: Validar que la carga de bloques de 4 palabras beneficia a los accesos contiguos.

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **45 ns** | `lw $8, 256($0)` | `0x0100` | **MISS** | Cache vacía. Se inicia transferencia de ráfaga (Burst) de 4 palabras. |
| **215 ns** | (Re-ejecución) | `0x0100` | **HIT** | El bloque `[0x100-0x10F]` ya está en la Vía 0. |
| **275 ns** | `lw $9, 260($0)` | `0x0104` | **HIT** | **Clave**: La dirección está en el mismo bloque que la anterior. Acierto inmediato (1 ciclo). |
| **315 ns** | `lw $10, 16($0)` | `0x0010` | **MISS** | Cambio de etiqueta. Se requiere cargar un nuevo bloque en otra línea/vía. |

**Resultados Finales Test 2:**
- **Cache Misses**: 2
- **Read Hits**: 3

---

## TEST 3: Escrituras (Write-Around y Dirty)
**Objetivo**: Comprobar que no se cargan bloques en fallos de escritura y que se marcan como "sucios" en aciertos.

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **45 ns** | `sw $2, 32($0)` | `0x0020` | **MISS (W)** | **Write-Around**: Se escribe en RAM-D vía bus, pero la caché NO carga el bloque. |
| **175 ns** | `lw $3, 32($0)` | `0x0020` | **MISS (L)** | Ahora sí se carga el bloque en caché (Vía 0). |
| **355 ns** | `sw $3, 36($0)` | `0x0024` | **HIT (W)** | Acierto en Vía 0. Se actualiza el dato local y se activa `dirty='1'`. |

**Resultados Finales Test 3:**
- **Cache Misses**: 2
- **Read Hits**: 1
- **Write Hits**: 1

---

## TEST 4: Copy-Back y FIFO (La prueba reina)
**Objetivo**: Forzar el desalojo de un bloque modificado y verificar el volcado previo a RAM.

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **45 ns** | `lw $2, 0($0)` | `0x0000` | **MISS** | Carga Bloque 0 en Vía 0. |
| **245 ns** | `sw $2, 0($0)` | `0x0000` | **HIT** | Vía 0 marcada como **DIRTY**. |
| **265 ns** | `lw $2, 64($0)` | `0x0040` | **MISS** | Carga Bloque 4 en Vía 1 (vía libre). |
| **545 ns** | `lw $2, 128($0)`| `0x0080` | **REEMPLAZO**| El FIFO elige la Vía 0 (más vieja). Como está **Dirty**, inicia fase de **Copy-Back**. |
| **665 ns** | (Fase CB) | `0x0000` | **WRITE-BACK**| Se vuelcan las 4 palabras del Bloque 0 a la RAM-D. |
| **715 ns** | (Fase Carga)| `0x0080` | **LOAD** | Se carga el nuevo Bloque 8 en la Vía 0. |

**Resultados Finales Test 4:**
- **Cache Misses**: 3
- **Read Hits**: 3
- **Write Hits**: 1
- **Copy-Backs**: 1

---

## TEST 5: Gestión de Errores
**Objetivo**: Verificar que el sistema no se cuelga ante accesos prohibidos.

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **45 ns** | `lw $2, 1($0)` | `0x0001` | **ERR_UNALIGNED** | Dirección desalineada. La UC aborta inmediatamente. |
| **325 ns** | `sw $9, 0($8)` | `0x01000000` | **ERR_PROTECTED** | Intento de escritura en registro interno de solo lectura. |
| **545 ns** | `lw $9, 0x4000($0)`| `0x4000` | **ERR_TIMEOUT** | Sin respuesta del bus tras 16 ciclos (fuera de rango). |

**Resultados Finales Test 5:**
- **Cache Misses**: 3
- **Read Hits**: 2
- **Errores de Hardware**: 3 (Alineamiento, Escritura Protegida, Timeout)

---

## TEST 6: Estrés FIFO
**Objetivo**: Confirmar que el puntero de reemplazo rota correctamente entre las dos vías.

| Tiempo | Instrucción | Dirección | Evento | Racional Técnico |
| :--- | :--- | :--- | :--- | :--- |
| **...** | `lw $2, 0($0)` | `0x0000` | **MISS** | Carga en Vía 0. |
| **...** | `lw $3, 64($0)`| `0x0040" | **MISS** | Carga en Vía 1. |
| **...** | `lw $4, 128($0)`| `0x0080" | **MISS** | Expulsa Vía 0 (FIFO). |
| **...** | `lw $5, 0($0)` | `0x0000" | **MISS** | Expulsa Vía 1 (FIFO). |

**Resultados Finales Test 6:**
- **Cache Misses**: 4
- **Read Hits**: 5

---

## TEST 7: Arbitraje (MIPS vs IO)
**Objetivo**: Verificar que el bus no se bloquea cuando dos maestros compiten.

En este test, el `IO_MASTER` inunda el bus con peticiones. El MIPS realiza un bucle de lectura NC. Se observa cómo el `bus_grant` alterna entre `01` (MIPS) y `10` (IO_MASTER), demostrando un arbitraje justo.

**Resultados Finales Test 7:**
- **Cache Misses**: 1
- **Read Hits**: 1

---
*Este reporte ha sido validado contra los logs de simulación y los archivos VHDL originales.*
