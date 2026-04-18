# Diagrama Estructural: Organización Interna de la Caché

Este fichero modela de manera exacta cómo la circuitería física de tu memoria lee la dirección suministrada por el MIPS, cómo baja directamente al "piso" correspondiente (Conjunto), cómo los comparadores verifican los Tags, y cómo el Multiplexor saca la palabra seleccionada del "cajón".

```plantuml
@startuml
skinparam componentStyle rectangle
skinparam monochrome true
skinparam padding 5
skinparam nodesep 50
skinparam ranksep 60

title Organización Interna MIPS (2 Vías, 4 Conjuntos, Bloques de 4 Palabras)

note top
**Formato del Address (32 bits):**
[      TAG (26 bits)      ] [ CONJUNTO (2 bits) ] [ PALABRA (2 bits) ] [ BO (2 bits) ]
end note

rectangle "Lógica de Control Físico" {
  component "Selector de Conjunto\n(Lee los 2 bits de Conjunto)" as DecSet
  component "Comparador Vía 0\n¿Tag Memoria == Tag CPU?" as Comp0
  component "Comparador Vía 1\n¿Tag Memoria == Tag CPU?" as Comp1
  component "Mux 4 a 1\n(Lee los 2 bits de Palabra)" as MuxPal
}

package "Almacenamiento Físico (128 Bytes totales)" {
    
    rectangle "VÍA 0 (Matriz de 16 Palabras)" {
        usecase "Conj. 00: [Tag_0A | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V0C0
        usecase "Conj. 01: [Tag_1A | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V0C1
        usecase "Conj. 10: [Tag_2A | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V0C2
        usecase "Conj. 11: [Tag_3A | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V0C3
    }
    
    rectangle "VÍA 1 (Matriz de 16 Palabras)" {
        usecase "Conj. 00: [Tag_0B | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V1C0
        usecase "Conj. 01: [Tag_1B | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V1C1
        usecase "Conj. 10: [Tag_2B | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V1C2
        usecase "Conj. 11: [Tag_3B | Val | Dirty] ⇨ (Pal_0 | Pal_1 | Pal_2 | Pal_3)" as V1C3
    }
}

' Flujo de un ejemplo Address:
DecSet -down-> V0C2 : "Ej. Supongamos\nConjunto = 10"
DecSet -down-> V1C2

V0C2 .left.> Comp0 : "Expulsa su Tag"
V1C2 .right.> Comp1 : "Expulsa su Tag"

Comp0 -down-> MuxPal : "Si Hit=1\nEntrega el Bloque"
Comp1 -down-> MuxPal : "Si Hit=1\nEntrega el Bloque"

MuxPal -down-> [Procesador MIPS (Registro 32b)] : "Pincha y entrega 1 Sola Palabra\n(Basado en el índice)"

@enduml
```
