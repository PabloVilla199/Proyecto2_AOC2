# Arquitectura del Sistema de Memoria MIPS (AOC2 - P2_26)

Este documento resume la estructura y el funcionamiento de los componentes revisados en el proyecto de diseño de una jerarquía de memoria con caché para un procesador MIPS.

## Visión General
El sistema implementa una jerarquía de memoria con una **Caché de Datos (MC)** de tipo *Copy-Back* (Write-Back) y un bus semi-síncrono que comunica el controlador de caché con la memoria principal (**MD**) y otros dispositivos de E/S.

### Diagrama de Conexiones (Subclase IO_MD)

```mermaid
graph TD
    MIPS[Procesador MIPS] --> MC_Control[Controlador MC]
    MC_Control --> MC_Ways[Vías de la MC - Via_CB]
    
    subgraph "Bus Semi-síncrono"
        Arbiter[Árbitro del Bus]
        IO_Master[Master de E/S]
    end
    
    MC_Control <--> Arbiter
    IO_Master <--> Arbiter
    
    Arbiter --> Bus_Data[Líneas de Datos/Direcciones]
    
    Bus_Data <--> MD[Memoria de Datos - MD_cont]
    Bus_Data <--> Scratch[Scratchpad - MD_scratch]
```

---

## Análisis por Fichero

### 1. [IO_MD_subsystem_P2_26.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/IO_MD_subsystem_P2_26.vhd)
Es el **Top-Level** del subsistema de memoria. Su función es instanciar y cablear:
- El controlador de la caché de datos.
- El árbitro del bus.
- La memoria principal y la memoria scratchpad.
- Los maestros de E/S.
- Gestiona las señales de `ready` y `abort` hacia el procesador MIPS.

### 2. [arbitro.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/arbitro.vhd)
Implementa la lógica de gestión del bus.
- **Entradas:** `MC_Bus_Req`, `IO_M_Req` (solicitudes de acceso).
- **Salidas:** `MC_Bus_Grant`, `IO_M_bus_Grant` (permisos de acceso).
- Asegura que solo un dispositivo actúe como "Master" del bus en cada ciclo, evitando colisiones en las líneas de direcciones y datos.

### 3. [MC_datos_CB_2026.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/MC_datos_CB_2026.vhd)
Es el cerebro de la caché de datos. Contiene la **Unidad de Control (UC)** que gestiona:
- **Aciertos (Hits):** Entrega el dato al procesador en el mismo ciclo (o el siguiente).
- **Fallos (Misses):** Solicita el bus, realiza la carga del bloque desde memoria y, si el bloque reemplazado estaba "sucio" (modificado), gestiona el volcado (*Copy-Back*) a memoria.
- **Señales de rendimiento:** Controla contadores como `inc_m` (fallos), `inc_w` (escrituras), etc.

### 4. [Via_2026_CB.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/Via_2026_CB.vhd)
Representa una "vía" de la caché. Es el componente de hardware que almacena físicamente los datos.
- **Estructura:**
    - `memoria_cache_D`: RAM que guarda los datos (bloques).
    - `memoria_cache_tags`: RAM que guarda las etiquetas (Tags) para identificar los bloques.
    - `bits_validez`: Registro que indica si el bloque contiene datos válidos.
    - `bits_dirty`: Indica si el bloque ha sido modificado y debe guardarse en memoria al ser reemplazado.
- **Lógica de Hit:** Compara el `Tag` de la dirección solicitada con el almacenado y verifica que el bit de validez sea '1'.

### 5. [MD_cont_2026.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/MD_cont_2026.vhd) y [MD_scratch_2026.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/MD_scratch_2026.vhd)
Son los controladores de las memorias físicas.
- La **MD** es la memoria principal, más lenta y que requiere gestión del bus.
- La **Scratchpad** es una memoria rápida mapeada en una zona específica de direcciones para datos críticos o de acceso frecuente.

### 6. [FIFO_reg.vhd](file:///c:/Users/Pablo/Desktop/AOC2_p4/Moodle%202026_p2/Moodle%202026_p2/FIFO_reg.vhd)
Un buffer tipo FIFO (First-In, First-Out) utilizado probablemente para desacoplar la velocidad del procesador/caché de la velocidad del bus, o para almacenar temporalmente ráfagas de datos durante las transferencias de bloques.

---

## Flujos de Trabajo Clave

### Lectura con Fallo (Read Miss)
1. El MIPS pide un dato. La `MC` detecta `hit = '0'`.
2. El controlador de `MC` activa `MC_Bus_Req`.
3. El `Arbiter` concede el bus con `MC_Bus_Grant`.
4. La `MC` envía la dirección al bus y espera a que la `MD` responda (`MD_Bus_TRDY`).
5. Se cargan las 4 palabras del bloque en la `Via_CB`.
6. Se actualiza el `Tag` y el bit de validez.

### Escritura (Copy-Back)
1. Si se escribe en un bloque en caché, se marca como **Dirty**.
2. No se escribe inmediatamente en memoria (ahorra tráfico de bus).
3. Si ese bloque debe ser reemplazado por otro nuevo, la caché detecta `dirty = '1'` y primero escribe el bloque viejo en la `MD` antes de cargar el nuevo.

---

> [!TIP]
> **Próximos pasos recomendados:**
> - Revisar la máquina de estados en `Completar_UC_MC_2026.vhd` para asegurar que las transiciones entre estados (IDLE, BUS_REQ, MEM_WAIT, etc.) son correctas.
