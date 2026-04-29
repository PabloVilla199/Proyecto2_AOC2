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
    0 => X"08020000", -- 0: lw \, 0(\)   -> Miss (Via 0)
    1 => X"08030040", -- 4: lw \, 64(\)  -> Miss (Via 1)
    2 => X"08040080", -- 8: lw \, 128(\) -> Miss (Expulsa Via 0 - FIFO)
    3 => X"08050000", -- C: lw \, 0(\)   -> Miss (Expulsa Via 1 - FIFO)
    4 => X"08060080", -- 10: lw \, 128(\) -> HIT (Via 0)
    5 => X"1000FFFF", -- 14: beq \, \, -1 (Bucle final)
    others => X"00000000"
);
signal dir_7:  std_logic_vector(6 downto 0); 
begin
 dir_7 <= ADDR(8 downto 2); 
 process (CLK) begin
    if (CLK'event and CLK = '1') then
        if (WE = '1') then RAM(conv_integer(dir_7)) <= Din; end if;
    end if;
 end process;
 Dout <= RAM(conv_integer(dir_7)) when (RE='1') else X"00000000"; 
end Behavioral;
