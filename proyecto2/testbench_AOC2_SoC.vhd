-- TestBench con Monitor de Árbitro por Niveles
  LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;

  ENTITY testbench IS
  END testbench;

  ARCHITECTURE behavior OF testbench IS 
	COMPONENT AOC2_SoC is
		Port ( clk, reset, EXT_IRQ : in STD_LOGIC; INT_ACK : out STD_LOGIC; IO_input: in STD_LOGIC_VECTOR(31 downto 0); IO_output : out STD_LOGIC_VECTOR(31 downto 0));
	END COMPONENT;
    SIGNAL clk, reset, EXT_IRQ, INT_ACK : std_logic;
    SIGNAL IO_output, IO_input : std_logic_vector(31 downto 0);
    constant CLK_period : time := 10 ns;
  BEGIN
   uut: AOC2_SoC PORT MAP(clk => clk, reset => reset, EXT_IRQ => EXT_IRQ, INT_ACK=> INT_ACK, IO_input => IO_input, IO_output => IO_output);

   CLK_process :process begin
		CLK <= '0'; wait for CLK_period/2; CLK <= '1'; wait for CLK_period/2;
   end process;

 stim_proc: process begin		
      	EXT_IRQ <= '0'; IO_input <= x"CAFEBABE"; reset <= '1';
    	wait for CLK_period*2;
		reset <= '0';
		assert false report "--- INICIO TEST 7 ---" severity note;
        
        wait for 80 ns; 
        assert false report ">>> TESTBENCH: ACTIVANDO IRQ" severity note;
        EXT_IRQ <= '1'; 
        
        wait for 400 ns; 
        EXT_IRQ <= '0'; 
		wait;
   end process;

  monitor_cache: process(clk)
    alias req0 is << signal .testbench.uut.io_mem.arbitraje.req0 : std_logic >>;
    alias req1 is << signal .testbench.uut.io_mem.arbitraje.req1 : std_logic >>;
    alias grant0 is << signal .testbench.uut.io_mem.arbitraje.grant0 : std_logic >>;
    alias grant1 is << signal .testbench.uut.io_mem.arbitraje.grant1 : std_logic >>;
    
    variable old_grant1 : std_logic := '0';
    variable old_grant0 : std_logic := '0';
  begin
    if rising_edge(clk) then
        -- Reportamos cambios en Grant para no saturar la terminal
        if grant0 = '1' and old_grant0 = '0' then
            assert false report "[BUS] -> Concedido a CACHE" severity note;
        end if;
        if grant1 = '1' and old_grant1 = '0' then
            assert false report "[BUS] -> Concedido a IO MASTER" severity note;
        end if;
        
        -- Si IO Master pide bus pero no se le da
        if req1 = '1' and grant1 = '0' then
            -- assert false report "[INFO] IO Master esperando el bus..." severity note;
        end if;

        old_grant0 := grant0;
        old_grant1 := grant1;
    end if;
  end process;
  END;
