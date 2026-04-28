# Plan de Pruebas (Test Cases) - AOC2 P2

Este documento contiene los casos de prueba esenciales que deben ser validados en ModelSim (tanto en tests unitarios como en el ensamblador final) para asegurar el funcionamiento de la Memoria Caché y el Árbitro.

## Batería de Pruebas Unitarias (Testbench)

Para probar minuciosamente la lógica combinacional y secuencial del hardware, el archivo Testbench inyectará ondas asíncronas para simular los siguientes casos vitales:

| ID | Operación / Escenario | Maestro / Inicia | Componente Destino | Condición Hardware | ¿Usa Bus General? | Descripción del Flujo Físico Resultante |
| :---: | :--- | :---: | :---: | :--- | :---: | :--- |
| **TEST_01** | Lectura sin Caché previa (MIPS -> RAM) | MIPS | RAM principal | `lw` en Caché Fría / Hit = 0. | ✅ **SÍ** | El TB solicita lectura. Caché hace de mediador, pide Bus, trae ráfaga con latencia, y actualiza Vía limpia. `cont_m`++. |
| **TEST_02** | Acierto de Lectura sucesiva (Hit) | MIPS | Caché | `lw` consecutivo a mismo Address. | ❌ **No** | El TB repite el `lw` en el ciclo inmediato. La caché responde en 1 único ciclo con el dato guardado (Valid=1). `cont_r`++. |
| **TEST_03** | Llenar Vías limpias (Load seguido) | MIPS | RAM principal | Múltiples `lw` hasta rellenar un *Set* entero. | ✅ **SÍ** | Secuencia extensa de `lw` en addresses distintas con el mismo índice para ver si los reemplazos FIFO Limpios saltan correctamente. |
| **TEST_04** | Acierto de Escritura (Copy-Back) | MIPS | Caché | `sw` en una vía residente / Hit = 1. | ❌ **No** | El TB altera un dato precargado. La Caché altera el byte y marca el bloque como 'Sucio' (`dirty_bit=1`). `cont_w`++. |
| **TEST_05** | Fallo de Escritura (Write-Around) | MIPS | RAM principal | `sw` en address no cacheado. | ✅ **SÍ** | El TB graba una dirección inédita. El sistema no trae bloque, pero pide Bus y manda la palabra a la RAM directo. |
| **TEST_06** | Desalojo Copy-Back (Bloque Sucio) | Caché | RAM principal | Miss que requiere usar la Vía que ocupa el **TEST_04**. | ✅ **SÍ** | El TB fuerza desalojo. Caché frena el pipeline, pide Bus, vuelca Bloque Sucio a la RAM, y luego carga el bloque nuevo. `cont_cb`++. |
| **TEST_07** | Aislamiento Scratchpad | MIPS | MemScratch | Peticiones a `x10000000`. | ✅ **SÍ** | El TB interactúa directamente con Scratchpad. Bus transmite, pero Caché queda completamente inalterable (Mapeo por fuera). |
| **TEST_08** | E/S y Colisión Temporal (Árbitro) | E/S + Caché| Árbitro Hardware | Peticiones sincrónicas simultáneas. | ✅ **SÍ** | TB activa al módulo `IO_Master` y al MIPS al mismo tiempo. El Árbitro concede `Bus_grant` según precedencia. |
| **TEST_09** | Error: "No Acknowledge" | MIPS | Bus Fantasma | Envío de `Address` no reconocida. | ✅ **SÍ** | TB trata de leer vacío sin `Bus_DevSel`. Salta FSM, `Mem_Error=1`, CPU entra en latencia Data Abort. |
| **TEST_10** | Error: Misaligned Word | MIPS | Red de control | `lw` a byte Address impar/no-múltiplo.| ❌ **No** | IF intercepta mala alineación. Se levanta Bandera de Error inmediatamente, rellenando `Addr_Error_Reg`. |
| **TEST_11** | Error: Escritura en Read-Only | MIPS | Componente Int. | `sw` malintencionado a `x01000000`. | ❌ **No** | TB intenta pisar el registro *Read-Only* de Error. Hardware corta la petición, declara Excepción de forma automática. |
| **TEST_12** | Clearence del Error (Lectura) | MIPS | Componente Int. | `lw` al Registro especial de Fallo. | ❌ **No** | El OS maneja excepción (TB hace un simple Read a `x01000000`). FSM secundaria se resetea a `No_error`, limpiando el aborto. |

## Prueba de Integración Externa (`.s` Assembler Program)

Una vez validados los picos del circuito hardware en ModelSim, es vital crear el **Programa en Ensamblador** (`.asm` / `.s`) integrador y correr la ejecución de MIPS al 100%. Los pasos recomendados:

1. **Rellenado y Write-Around:** Código ensamblador que inicialice 2 matrices enormes secuencialmente en bucle cerrado. Observar el tráfico directo hacia RAM (Comportamiento Write-Around puro).
2. **Cómputo Local y Hit Rate:** Bucle que procese o sume vectores matemáticamente. Con variables residentes en L1, se evalúa y extrae el **Speedup Final** frente al MIPS nativo (La aceleración gracias a la Caché Copy-Back).
3. **Manejo DMA Asíncrono:** Durante el procesado, activar temporalizadores paralelos dentro del módulo E/S que escriban el *Heartbeat* hacia la RAM; esto valida el Árbitro frente al estrés.
4. **Finalización y Matemáticas:** Sumar y parsear en el Módulo los 4 contadores de eventos. Con sus resultados, contrastar la fórmula de *Average Access Cycles* pedida en el informe académico.
