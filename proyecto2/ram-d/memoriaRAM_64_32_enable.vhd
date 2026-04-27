library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity RAM_64_32 is port (
			CLK : in std_logic;
			ADDR : in std_logic_vector (31 downto 0);
			Din : in std_logic_vector (31 downto 0);
			WE : in std_logic;
			RE : in std_logic;
			enable: in std_logic;
			Dout : out std_logic_vector (31 downto 0));
end RAM_64_32;

architecture Behavioral of RAM_64_32 is
type RamType is array(0 to 127) of std_logic_vector(31 downto 0); -- Aumentamos a 128 palabras
signal RAM : RamType := (
                                    0  => X"DEADBEEF", -- Para el Test 2 (Miss 2)
                                    64 => X"10000000", -- Direccion 256
                                    65 => X"01000000", -- Direccion 260
									others => X"00000000");				
signal dir_7:  std_logic_vector(6 downto 0); 
begin
 dir_7 <= ADDR(8 downto 2); 
 process (CLK)
    begin
        if (CLK'event and CLK = '1') then
            if (WE = '1') and (enable = '1') then 
                RAM(conv_integer(dir_7)) <= Din;
            end if;
        end if;
    end process;
    Dout <= RAM(conv_integer(dir_7)) when (RE='1' and enable='1') else "00000000000000000000000000000000"; 
end Behavioral;
