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

card AddressBlock [
**Formato del Address (32 bits):**
| TAG (26 bits) | CONJUNTO (2 bits) | PALABRA (2 bits) | BO (2 bits) |
]

rectangle "Lógica de Control Físico" {
  component "Selector de Conjunto\n(Bits de Conjunto)" as DecSet
  component "Comparador Vía 0" as Comp0
  component "Comparador Vía 1" as Comp1
  component "Mux 4 a 1\n(Bits de Palabra)" as MuxPal
}

package "Almacenamiento Físico (128 Bytes)" {
    rectangle "VÍA 0 (16 Palabras)" {
        card "Conj 00: Tag_0A ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V0C0
        card "Conj 01: Tag_1A ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V0C1
        card "Conj 10: Tag_2A ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V0C2
        card "Conj 11: Tag_3A ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V0C3
    }
    
    rectangle "VÍA 1 (16 Palabras)" {
        card "Conj 00: Tag_0B ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V1C0
        card "Conj 01: Tag_1B ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V1C1
        card "Conj 10: Tag_2B ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V1C2
        card "Conj 11: Tag_3B ⇨ Pal0 | Pal1 | Pal2 | Pal3" as V1C3
    }
}

AddressBlock -down-> DecSet

DecSet -down-> V0C2 : "Ejemplo\nDir a Conj 10"
DecSet -down-> V1C2

V0C2 .right.> Comp0 : "Envía Tag"
V1C2 .left.> Comp1 : "Envía Tag"

Comp0 -down-> MuxPal : "Si Hit=1\nPasa el Bloque"
Comp1 -down-> MuxPal : "Si Hit=1\nPasa el Bloque"

MuxPal -down-> [Registro MIPS (32b)] : "Pincha y entrega\n1 sola Palabra"

@enduml
```
