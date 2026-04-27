----------------------------------------------------------------------------------
-- Mdulo: memoriaRAM_I (Test 2: Aciertos y Fallos de Lectura)
-- ===============================================================================
-- GUIA DEFINITIVA PARA EL REPORT (Lógica de Bloques y Aciertos):
-- ===============================================================================
--
-- 1. [T=45 ns] PRIMER FALLO (MISS)
--    - Instruccin: lw $8, 256($0)
--    - FSM: Inicio -> fallo -> Send_Addr -> read_block.
--    - Qué capturar: bus_req='1', stall_mips='1'.
--    - Explicación: La caché está vacía. Se pide el bloque completo (dir 256, 
--      260, 264 y 268) a la RAM-D. Este es el acceso más lento.
--
-- 2. [T=255 ns] EL MOMENTO DEL ACIERTO (HIT)
--    - Instruccin: lw $9, 260($0)
--    - FSM: Inicio -> Inicio (Se resuelve en el mismo estado).
--    - Qué capturar: ready='1' (instantneo), bus_req='0' (¡SIN BUS!).
--    - Explicación: ¡CLAVE! Como el bloque anterior trajo la dir 260 a la caché,
--      ahora el MIPS recibe el dato en 1 solo ciclo. No hay stall ni uso de bus.
--
-- 3. [T=275 ns] SEGUNDO FALLO (MISS - Bloque distinto)
--    - Instruccin: lw $10, 512($0)
--    - FSM: Inicio -> fallo -> Send_Addr -> read_block.
--    - Qué capturar: mc_addr_bus mostrando 0x200 (direccin 512).
--    - Explicación: Pedimos un dato de otro bloque (dir 512). La caché vuelve 
--      a pedir el bus para traer el nuevo bloque desde la RAM-D.
-- ===============================================================================
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity memoriaRAM_I is port (
		  CLK : in std_logic;
		  ADDR : in std_logic_vector (31 downto 0);
        Din : in std_logic_vector (31 downto 0);
        WE : in std_logic;
		  RE : in std_logic;
		  Dout : out std_logic_vector (31 downto 0));
end memoriaRAM_I;

architecture Behavioral of memoriaRAM_I is
type RamType is array(0 to 127) of std_logic_vector(31 downto 0);
signal RAM : RamType := (
    X"08080100", -- 0: [45 ns] lw $8, 256($0)  -> MISS (Trae bloque 64)
    X"00000000", -- 4: nop
    X"00000000", -- 8: nop
    X"00000000", -- C: nop
    X"00000000", -- 10: nop
    X"08090104", -- 14: [255 ns] lw $9, 260($0)  -> HIT (Dato ya en cach)
    X"00000000", -- 18: nop
    X"00000000", -- 1C: nop
    X"00000000", -- 20: nop
    X"080A0200", -- 24: [275 ns] lw $10, 512($0) -> MISS (Bloque 128)
    X"1000FFFF", -- 28: beq $0, $0, -1
    others => X"00000000"
);
signal dir_7:  std_logic_vector(6 downto 0); 
begin
 dir_7 <= ADDR(8 downto 2); 
 process (CLK)
    begin
        if (CLK'event and CLK = '1') then
            if (WE = '1') then 
                RAM(conv_integer(dir_7)) <= Din;
            end if;
        end if;
    end process;
    Dout <= RAM(conv_integer(dir_7)) when (RE='1') else "00000000000000000000000000000000"; 
end Behavioral;
