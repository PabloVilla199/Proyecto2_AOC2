# Esquema Interno de la Memoria Caché de Datos

A continuación se detalla el diagrama lógico exacto del flujo de datos dentro de la caché, junto a la explicación del rol de la Unidad de Control (UC) en el manejo de fallos (Miss).

## 1. Diagrama de Enrutamiento Físico

```plantuml
@startuml
skinparam componentStyle rectangle
skinparam monochrome true
skinparam linetype ortho
skinparam padding 8
skinparam nodesep 60
skinparam ranksep 70

title Camino de Datos (Datapath) MIPS: Caché L1 (2 Vías, 128 Bytes)

card AddressBlock [
**Formato del Address MIPS (32 bits):**
| TAG (26 bits) | CONJUNTO (2 bits) | PALABRA (2 bits) | BYTE (2 bits) |
]

rectangle "Lógica de Control Físico" {
  component "Selector de Conjunto\n(Bits 5 y 4)" as DecSet
  component "Comparador Vía 0\n(Check Tag & Valid)" as Comp0
  component "Comparador Vía 1\n(Check Tag & Valid)" as Comp1
  component "Multiplexor 4:1\n(Bits 3 y 2)" as MuxPal
}

package "Almacenamiento Físico (Arrays RAM)" {
    rectangle "VÍA 0 (16 Palabras)" {
        card "Conj 00: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V0C0
        card "Conj 01: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V0C1
        card "Conj 10: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V0C2
        card "Conj 11: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V0C3
    }
    
    rectangle "VÍA 1 (16 Palabras)" {
        card "Conj 00: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V1C0
        card "Conj 01: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V1C1
        card "Conj 10: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V1C2
        card "Conj 11: [Tag] [V] [D] ⇨ P0 | P1 | P2 | P3" as V1C3
    }
}

AddressBlock -down-> DecSet : " Extrae Conjunto"

DecSet -down-> V0C2 : " Activa Fila Seleccionada "
DecSet -down-> V1C2

V0C2 .right.> Comp0 : " Envía Tag_0"
V1C2 .left.> Comp1 : " Envía Tag_1"

Comp0 -down-> MuxPal : " Si Hit=1,\n Baja Bloque 0"
Comp1 -down-> MuxPal : " Si Hit=1,\n Baja Bloque 1"

MuxPal -down-> [Registro Destino MIPS (32b)] : " Pincha la Palabra Correcta"

@enduml
```

## 2. Gestión de Fallos (Rol de la Unidad de Control)

Esta es la secuencia exacta que debe programarse en la Máquina de Estados (FSM) de vuestra **Unidad de Control (UC)** cuando los comparadores anteriores detectan un **Fallo (Miss)**:

1. **Salta la alarma (Freeze del MIPS):** El comparador chilla que hay un Miss. La UC agarra la interfaz del MIPS, y le mete la señal `Mem_Ready = 0` para congelarlo por completo y evitar que avance a la siguiente instrucción del pipeline.
2. **Pedir Permiso:** La UC levanta la mano al Árbitro (`Bus_req = 1`) y solicita la titularidad del Bus Semi-síncrono.
3. **¿A quién echamos? (El Reemplazo):** La UC lee la política FIFO para elegir qué vía víctima (la 0 o la 1) vamos a machacar. 
   👉 *Si encima es un bloque Sucio (Copy-Back)*, la UC tiene que pasarse varios ciclos tirando y volcando las 4 palabras a la Memoria Principal lentamente por el bus antes de pedir las nuevas, para salvar los datos al disco.
4. **Tráeme los datos (El Burst):** La UC le da la dirección de Address original a la RAM por el bus. Como los cables del gran bus principal miden también 32 bits, es físicamente imposible traerse el bloque de 128 bytes de golpe. Aquí la RAM inyecta una Ráfaga (**Burst**). Manda la Palabra 0 (1 ciclo de reloj), Palabra 1 (ciclo), Palabra 2...
5. **Guardar y Volver a la Normalidad:** Según van llegando esas 4 palabras en fila india desde el bus de la RAM, la UC las va estampando (escribiendo) dentro de las Memorias RAM internas de la Vía, usando los dos bits `[5 y 4]` del Address original para saber en qué altura de la estantería atornillarlas. Tras rellenarlo entero: 
   - Pone el Tag nuevo.
   - Marca el bloque como limpio y válido.
   - Libera al MIPS (`Mem_Ready = 1`).
   - El procesador MIPS se lleva por fin la palabra que quería de su `lw`, y la vida sigue.
