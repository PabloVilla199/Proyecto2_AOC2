----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 2: Aciertos y Fallos de Lectura)
-- Descripción:
--   Verifica el comportamiento básico de la caché ante instrucciones 'lw'. 
--   El primer 'lw' producirá un Fallo de Lectura (Miss), obligando a la caché a
--   pedir un bloque completo de 4 palabras por el bus. El segundo 'lw' a la misma
--   dirección producirá un Acierto de Lectura (Hit), resolviéndose en un solo ciclo
--   sin usar el bus porque el bloque ya se ha guardado en caché.
--
-- Código Ensamblador MIPS:
--   lw $2, 0($0)      # Fallo L: La caché vacía pide el Bloque 0 y lo guarda.
--   nop               
--   nop               
--   lw $3, 0($0)      # Acierto L: El Bloque 0 ya está en caché. Acierto rápido.
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
    X"8C020000", -- 0: lw $2, 0($0)      
    X"00000000", -- 4: nop               
    X"00000000", -- 8: nop
    X"8C030000", -- C: lw $3, 0($0)      
    X"08000004", -- 10: j 4              
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
