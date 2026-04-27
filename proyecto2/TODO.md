# Planificación y Tareas Pendientes (TODO) - AOC2 P2

Esta lista organiza todo lo requerido por la guía oficial del proyecto para alcanzar la máxima nota, dividido por fases de desarrollo.

## 1. Diseño Hardware (Controlador MC)
- [ ] Implementar la **Máquina de Estados (FSM) Principal** para procesar aciertos y fallos de lectura/escritura (gestionando las señales del Bus Semi-síncrono).
- [ ] Implementar la **FSM Secundaria (Manejo de Errores)** que controla la señal `Mem_Error` (Data Abort):
  - [ ] Trigger A: Ningún dispositivo responde validando la dirección (Timeout / sin Acknowledge).
  - [ ] Trigger B: Acceso desalineado por el procesador MIPS.
  - [ ] Trigger C: Intento de escritura a registrar en componentes Read-Only.
- [ ] Configurar el registro `Addr_Error_Reg` para almacenar el byte/dirección exacto del error y mapearlo nativamente a la dirección `x"01000000"`.
- [ ] Conectar y asegurar la precisión de los 4 Event Counters de Rendimiento:
  - [ ] `cont_m`: Fallos de Caché en zona Mapeada L1.
  - [ ] `cont_w`: Escrituras efectivas en L1.
  - [ ] `cont_r`: Lecturas efectivas desde L1.
  - [ ] `cont_cb`: Reemplazos hacia la MD desencadenados por Copy-Back de bloques sucios. *(IMPORTANTE: Asegurar que incrementan 1 sola vez por evento, no 1 vez por ciclo del evento).*

## 2. Testing y Verificación
- [ ] **Tests Unitarios (Testbenches Modulares):**
  - [ ] Aislar y probar Hits de lectura/escritura.
  - [ ] Forzar miss con bloques limpios y sucios para todas las vías.
  - [ ] Leer/Escribir en la MD Scratchpad de forma continuada comprobando ausencia de colisión con la caché.
  - [ ] Inyectar accesos ilegales comprobando levantada y bajada correcta de banderas.
- [ ] **Test de Integración Global:**
  - [ ] Programar un binario en ensamblador MIPS complejo que cubra todos los flujos de la arquitectura en una sóla ejecución ininterrumpida.

## 3. Preparación del Informe / Memoria
- [ ] Dibujar el **Grafo de Estados Final (State Graph)** asegurando legibilidad de las ramas condicionales. Añadir tabla anexa de Mealy/Moore si fuese incomprensible.
- [ ] Dibujar diagrama gráfico de la división del Address (`[ Tag | Set | Word | Byte ]`).
- [ ] Extraer mediciones puras de ciclos desde las formas de onda (simulación) para rellenar las constantes del documento: `CrB_MD`, `CwW_MD`, `CrW_MDscratch`, etc.
- [ ] Redactar y justificar matemáticamente la **Fórmula de Ciclos Medios por Acceso a Memoria**.
- [ ] Calcular el *Speedup* definitivo frente a un sistema base sin caché.
- [ ] Redactar Registro temporal de dedicación y Autoevaluación de Equipo.

## 4. Mejoras Opcionales para Excelencia (Si hay tiempo)
- [ ] **Write Buffer (Lockup-free cache):** Buffer intermedio al escribir en MD para agilizar liberando el estado MIPS temporalmente.
- [ ] **Critical Word Forwarding:** Cortocircuito del dato en lecturas; Pasar primero la palabra exacta que necesita la instrucción para que vuelva a arrancar la CPU mientras se sigue rellenando el bloque por detrás.
- [ ] **Simulación DDoS/Hacking Ético:** Script/Programa asmb destructivo para asfixiar las recargas del bus llenando a posta toda la caché de bits sucios en cada interacción de bloque.
