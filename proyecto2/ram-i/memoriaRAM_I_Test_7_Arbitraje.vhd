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
    0 => X"08080100", -- 0: lw $8, 256($0) -> Carga 0x10000000 en $8
    1 => X"00000000", -- 4: nop
    2 => X"09090000", -- 8: [LOOP] lw $9, 0($8) -> AHORA SÍ usa $8 como base
    3 => X"1000FFFE", -- C: beq $0, $0, -2 -> Vuelve al LOOP
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
