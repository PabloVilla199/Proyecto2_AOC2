----------------------------------------------------------------------------------
-- Mdulo: memoriaRAM_I (Test 5: Gestin de Errores)
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
    X"08020001", -- 0: lw $2, 1($0) (Error Desalineado)
    X"00000000", -- 4: nop
    X"08080104", -- 8: lw $8, 260($0) ($8 = 0x01000000)
    X"00000000", -- C: nop
    X"08090000", -- 10: lw $9, 0($8) (Limpia Error)
    X"00000000", -- 14: nop
    X"08094000", -- 18: lw $9, 0x4000($0) (Timeout)
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
    Dout <= RAM(conv_integer(dir_7)) when (RE='1') else "00000000000000000000000000000000"; 
end Behavioral;
