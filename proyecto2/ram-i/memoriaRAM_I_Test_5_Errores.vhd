----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 5: Gestión de Errores)
-- ===============================================================================
-- GUIA PARA EL REPORT:
-- ===============================================================================
--
-- TEST A: Error de alineación
--   lw $2, 1($0)  → Dirección MIPS = 0x0001 (desalineada, bits[1:0] != "00")
--   FSM: Inicio → Inicio (no va al bus, error detectado combinacionalmente)
--   Señales: unaligned='1', Mem_ERROR='1', ready='1', load_addr_error='1'
--   Contadores: inc_m=0 (no es miss cacheable), cont_m no cambia
--
-- TEST B: Carga de registro interno (MISS real al bus)
--   lw $8, 264($0) → Dirección MIPS = 0x0108, Set=0, Via 0
--   ATENCIÓN: 264($0) accede a la DIRECCIÓN 0x0108 en la RAM-D
--   El DATO devuelto desde RAM-D[posición 66] = 0x01000000 → se carga en $8
--   FSM: Miss → Arbitraje → block_transfer_addr → block_transfer_data (x4) → Inicio
--   Contadores: cont_m += 1
--
-- TEST C: Escritura en registro interno de solo lectura
--   sw $9, 0($8)  → Dirección = $8+0 = 0x01000000 (registro interno, solo lectura)
--   FSM: Inicio → Inicio (detectado como internal_addr='1' y WE='1')
--   Señales: Mem_ERROR='1', load_addr_error='1', ready='1'
--   Contadores: no incrementa ningún contador
--
-- TEST D: Lectura del registro de error (limpia Mem_ERROR)
--   lw $9, 0($8)  → Dirección = 0x01000000 (registro interno, solo lectura)
--   FSM: Inicio → Inicio (internal_addr='1', RE='1')
--   Señales: Mem_ERROR pasa a '0', mux_output="10" (devuelve Addr_Error_Reg al MIPS)
--   $9 recibe el contenido de Addr_Error_Reg (la dirección que causó el error previo)
--
-- TEST E: Timeout de bus (ningún esclavo responde)
--   lw $9, 0x4000($0) → Dirección = 0x4000 (fuera de rango MD y Scratchpad)
--   FSM: Miss → Arbitraje → single_word_transfer_addr → (DevSel=0) → Inicio+Error
--   Señales: Mem_ERROR='1', Bus_DevSel='0'
--   Contadores: cont_m += 1 (es cacheable y no estaba → miss)
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
    -- ADDR MIPS / PC / instrucción
    0 => X"08020001", -- 0x00: lw $2, 1($0)    → TEST A: Error desalineado (addr=0x0001)
    1 => X"00000000", -- 0x04: nop
    -- lw $8, 264($0): accede a ADDR=0x108 en RAM-D.
    -- RAM-D[posicion 66] = X"01000000" → $8 = 0x01000000 tras este miss
    2 => X"08080108", -- 0x08: lw $8, 264($0)  → TEST B: MISS cacheable (addr MIPS=0x108, dato=0x01000000)
    3 => X"00000000", -- 0x0C: nop
    4 => X"00000000", -- 0x10: nop
    -- sw $9, 0($8): escribe en 0x01000000 → registro interno, solo lectura → ERROR
    5 => X"0D090000", -- 0x14: sw $9, 0($8)    → TEST C: Escritura en registro read-only (0x01000000)
    6 => X"00000000", -- 0x18: nop
    -- lw $9, 0($8): lee 0x01000000 → limpia Mem_ERROR, $9 recibe la addr del error
    7 => X"08090000", -- 0x1C: lw $9, 0($8)    → TEST D: Lectura de Addr_Error_Reg (limpia error)
    8 => X"00000000", -- 0x20: nop
    -- lw $9, 0x4000($0): addr=0x4000, fuera de rango → ningún esclavo responde → Timeout
    9 => X"08094000", -- 0x24: lw $9, 16384($0)→ TEST E: Timeout (DevSel=0, addr=0x4000)
   10 => X"1000FFFF", -- 0x28: beq $0, $0, -1  → bucle final
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
    Dout <= RAM(conv_integer(dir_7)) when (RE='1') else X"00000000"; 
end Behavioral;
