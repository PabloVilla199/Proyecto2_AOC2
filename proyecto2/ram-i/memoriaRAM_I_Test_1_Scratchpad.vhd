----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 1: Accesos a Scratchpad)
-- Descripción:
--   Verifica que los accesos al rango de memoria Scratchpad (0x10000000) 
--   son marcados como no-cacheables (addr_non_cacheable = '1') y que la Unidad 
--   de Control se salta el protocolo normal de caché, mandando la petición 
--   de lectura y escritura directamente al bus sin modificar sus datos internos.
--
-- Código Ensamblador MIPS:
--   lui $8, 0x1000    # $8 = 0x10000000 (Dirección base Scratchpad)
--   lw $9, 0($8)      # Lee de la Scratchpad (Fuerza lectura no cacheable)
--   sw $9, 4($8)      # Escribe en la Scratchpad (Fuerza escritura no cacheable)
--   j loop            # Bucle infinito para finalizar la prueba
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
    X"3C081000", -- 0: lui $8, 0x1000    
    X"8D090000", -- 4: lw $9, 0($8)      
    X"AD090004", -- 8: sw $9, 4($8)      
    X"08000003", -- C: j 3               
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
