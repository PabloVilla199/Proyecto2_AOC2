----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 4: Desalojo de Bloque Sucio - CopyBack)
-- Descripción:
--   Es la prueba más completa y crucial. Evalúa la política de reemplazo FIFO 
--   junto con el volcado a RAM de bloques sucios (CopyBack).
--
-- Código Ensamblador MIPS:
--   lw $2, 0x0000($0) # Fallo: Trae el Bloque 0 a la Vía 0.
--   nop
--   sw $2, 0x0000($0) # Acierto E: Marca la Vía 0 como SUCIA (Dirty=1).
--   nop
--   lw $2, 0x0040($0) # Fallo: Trae el Bloque 4 a la Vía 1. ¡Ambas Vías ocupadas!
--   nop
--   lw $2, 0x0080($0) # Fallo: Pide el Bloque 8. Al no haber sitio, el FIFO elige 
--                     # desalojar la Vía 0 (la más vieja). Al estar sucia (Dirty), 
--                     # la Unidad de Control lanza la fase de CopyBack enviando
--                     # el Bloque 0 a la RAM antes de traerse el Bloque 8.
--   beq $0, $0, -1    # Bucle infinito para finalizar la prueba
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
    X"08020000", -- 0: lw $2, 0x0000($0) 
    X"00000000", -- 4: nop
    X"0C020000", -- 8: sw $2, 0x0000($0) 
    X"00000000", -- C: nop
    X"08020040", -- 10: lw $2, 0x0040($0)
    X"00000000", -- 14: nop
    X"08020080", -- 18: lw $2, 0x0080($0)
    X"1000FFFF", -- 1C: beq $0, $0, -1 
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
