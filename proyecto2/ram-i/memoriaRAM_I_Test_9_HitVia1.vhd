----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 9: Acierto en Vía 1)
-- Verifica que los accesos (lectura y escritura) que resultan en hit en la vía 1
-- funcionan correctamente.
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
    -- ADDR MIPS / Instrucción
    0 => X"08020000", -- 0x00: lw $2, 0x0000($0)  -> MISS (Via 0)
    1 => X"00000000", -- 0x04: nop
    2 => X"00000000", -- 0x08: nop
    3 => X"08030040", -- 0x0C: lw $3, 0x0040($0)  -> MISS (Via 1)
    4 => X"00000000", -- 0x10: nop
    5 => X"00000000", -- 0x14: nop
    6 => X"08040040", -- 0x18: lw $4, 0x0040($0)  -> HIT LECTURA VIA 1
    7 => X"00000000", -- 0x1C: nop
    8 => X"0D050040", -- 0x20: sw $5, 0x0040($0)  -> HIT ESCRITURA VIA 1 (Dirty Via 1)
    9 => X"00000000", -- 0x24: nop
   10 => X"1000FFFF", -- 0x28: beq $0, $0, -1
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
