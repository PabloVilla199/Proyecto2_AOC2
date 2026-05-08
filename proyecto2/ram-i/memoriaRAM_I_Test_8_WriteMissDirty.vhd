----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 8: Write Miss con Víctima Dirty)
-- Verifica que los write misses se cuenten correctamente incluso si la vía que
-- tocaría reemplazar (si no fuera write-around) está sucia.
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
    0 => X"08020000", -- 0x00: lw $2, 0x0000($0)  -> MISS (Set 0, Tag 0, Via 0)
    1 => X"00000000", -- 0x04: nop
    2 => X"00000000", -- 0x08: nop
    3 => X"0D020000", -- 0x0C: sw $2, 0x0000($0)  -> HIT WRITE (Via 0 becomes DIRTY)
    4 => X"00000000", -- 0x10: nop
    5 => X"08030040", -- 0x14: lw $3, 0x0040($0)  -> MISS (Set 0, Tag 1, Via 1)
    6 => X"00000000", -- 0x18: nop
    7 => X"00000000", -- 0x1C: nop
    8 => X"0D040080", -- 0x20: sw $4, 0x0080($0)  -> WRITE MISS (Set 0, Tag 2) 
                      -- FIFO apunta a Via 0 (DIRTY). Debe contar cont_m=3.
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
