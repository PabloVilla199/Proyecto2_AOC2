----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 5: Gestión de Errores y Registros Internos)
-- Descripción:
--   Verifica que la máquina de estados de la Unidad de Control salta a 
--   'memory_error' ante infracciones, y que se recupera únicamente al 
--   leer el registro mágico 0x01000000.
--
-- Código Ensamblador MIPS:
--   # 1) Error de Desalineamiento
--   lw $2, 0x0001($0) # Fallo: Dir no alineada. Activa Mem_Error.
--   nop
--   # 2) Limpieza del error
--   lui $8, 0x0100    # $8 = 0x01000000 (Dir del registro de error)
--   lw $9, 0($8)      # Lee el registro. Mem_Error debe volver a '0'.
--   nop
--   # 3) Error de Bus Timeout
--   lui $8, 0x2000    # $8 = 0x20000000 (Dirección que no existe en la placa)
--   lw $9, 0($8)      # Fallo: Nadie activa Bus_DevSel. Activa Mem_Error de nuevo.
--   nop
--   j loop            # Bucle infinito para finalizar
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
    X"8C020001", -- 0: lw $2, 0x0001($0) (Desalineado -> ERROR)
    X"00000000", -- 4: nop
    X"3C080100", -- 8: lui $8, 0x0100    ($8 = 0x01000000)
    X"8D090000", -- C: lw $9, 0($8)      (Lee Registro Error -> LIMPIA ERROR)
    X"00000000", -- 10: nop
    X"3C082000", -- 14: lui $8, 0x2000   ($8 = 0x20000000, dir fantasma)
    X"8D090000", -- 18: lw $9, 0($8)     (Bus_DevSel = 0 -> ERROR DE BUS)
    X"00000000", -- 1C: nop
    X"08000008", -- 20: j 8              (Bucle)
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
