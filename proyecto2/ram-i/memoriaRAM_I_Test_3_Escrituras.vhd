----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 3: Aciertos y Fallos de Escritura)
-- Descripción:
--   Verifica las políticas "Write-Around" en caso de fallo, y el marcado de "Dirty"
--   en caso de acierto de escritura. 
--
-- Código Ensamblador MIPS:
--   sw $2, 0x0020($0) # Fallo E: Al no estar en caché, se escribe directo a la 
--                     # memoria principal y no se guarda en caché (Write-Around).
--   nop
--   lw $3, 0x0020($0) # Fallo L: Carga el bloque entero en la caché a la fuerza.
--   nop
--   sw $3, 0x0024($0) # Acierto E: Como el bloque ya está en caché, se escribe 
--                     # en él y se enciende su bit "Dirty" en la Vía.
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
    X"AC020020", -- 0: sw $2, 0x0020($0) 
    X"00000000", -- 4: nop
    X"8C030020", -- 8: lw $3, 0x0020($0) 
    X"00000000", -- C: nop
    X"AC030024", -- 10: sw $3, 0x0024($0)
    X"08000005", -- 14: j 5              
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
