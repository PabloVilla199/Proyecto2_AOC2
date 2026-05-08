# TEST DE INTEGRACIÓN COMPLETO - Jerarquía de Memoria (AOC2 - Proyecto 2)
# Autor: Pablo
# Descripción: Este programa ejecuta un bucle continuo que estresa todas las políticas 
# de la caché, revelando posibles side-effects u cuelgues de la FSM a largo plazo.
#
# Casos cubiertos en el bucle:
# 1. Accesos a MD Scratch (Lectura y Escritura).
# 2. Llenado completo de los conjuntos 0 y 1 (Miss limpios).
# 3. Aciertos de escritura (Hits) que marcan todas las vías de la caché como SUCIAS.
# 4. Fallos de escritura (Write-Arounds) a memoria principal sin afectar la caché.
# 5. Fallos de lectura que provocan expulsiones sucias (Copy-Backs a MD).
# 6. Excepciones: Desalineamiento, Timeout de Bus, Read-Only Write y Limpieza de Errores.
# 7. Al repetir el bucle, se comprueban también las expulsiones de bloques limpios.

.text
.globl main

main:
    # ---------------------------------------------------------
    # FASE 1: INICIALIZACIÓN Y LECTURA DEL SCRATCHPAD
    # ---------------------------------------------------------
    lw $8, 256($0)              # Lee de MD la base Scratchpad (0x10000000)

    lw $9, 0($8)                # Lectura de MD Scratch
    sw $9, 4($8)                # Escritura en MD Scratch

    # ---------------------------------------------------------
    # FASE 2: LLENADO DE LA CACHÉ Y MARCA DE SUCIO (DIRTY)
    # ---------------------------------------------------------
    lw $10, 0($0)               # Miss: Carga Bloque 0 en Set 0, Vía 0
    lw $11, 32($0)              # Miss: Carga Bloque 2 en Set 0, Vía 1
    lw $12, 16($0)              # Miss: Carga Bloque 1 en Set 1, Vía 0
    lw $13, 48($0)              # Miss: Carga Bloque 3 en Set 1, Vía 1

    sw $10, 4($0)               # Hit: Ensucia Bloque 0
    sw $11, 36($0)              # Hit: Ensucia Bloque 2
    sw $12, 20($0)              # Hit: Ensucia Bloque 1
    sw $13, 52($0)              # Hit: Ensucia Bloque 3

    # ---------------------------------------------------------
    # FASE 3: WRITE-AROUND A MEMORIA PRINCIPAL
    # ---------------------------------------------------------
    sw $10, 64($0)              # Miss Write: Write-around a Bloque 4 (Set 0)
    sw $11, 80($0)              # Miss Write: Write-around a Bloque 5 (Set 1)

    # ---------------------------------------------------------
    # FASE 4: ESTRÉS DE REEMPLAZO Y COPY-BACK
    # ---------------------------------------------------------
    lw $14, 128($0)             # Miss: Expulsa Bloque 0 (Sucio) -> Copy-Back a MD
    lw $15, 160($0)             # Miss: Expulsa Bloque 2 (Sucio) -> Copy-Back a MD
    lw $14, 144($0)             # Miss: Expulsa Bloque 1 (Sucio) -> Copy-Back a MD
    lw $15, 176($0)             # Miss: Expulsa Bloque 3 (Sucio) -> Copy-Back a MD

    # ---------------------------------------------------------
    # FASE 5: EXCEPCIONES Y ERRORES DEL BUS (DATA ABORT)
    # ---------------------------------------------------------
    lw $16, 1($0)               # Error 1: Acceso desalineado
    
    lw $17, 264($0)             # Carga base de registros internos (0x01000000)
    sw $17, 0($17)              # Error 2: Escritura en registro Read-Only
    lw $17, 0($17)              # Acierto: Lectura de registro interno (Limpia el error)
    
    lw $16, 16384($0)           # Error 3: Timeout del Bus (No hay DevSel en 0x4000)

    # ---------------------------------------------------------
    # FASE 6: BUCLE INFINITO DE ESTRÉS
    # ---------------------------------------------------------
    # Saltamos al inicio (-23 instrucciones).
    beq $0, $0, -23             
