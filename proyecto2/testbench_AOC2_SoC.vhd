-- TestBench de Integracion Final (Auditoria Completa)
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
    SIGNAL sim_finished : std_logic := '0';
    constant CLK_period : time := 10 ns;
  BEGIN
   uut: AOC2_SoC PORT MAP(clk => clk, reset => reset, EXT_IRQ => EXT_IRQ, INT_ACK=> INT_ACK, IO_input => IO_input, IO_output => IO_output);

   CLK_process :process begin
		CLK <= '0'; wait for CLK_period/2; CLK <= '1'; wait for CLK_period/2;
   end process;

 stim_proc: process begin		
      	EXT_IRQ <= '0'; IO_input <= x"00000000"; reset <= '1';
    	wait for CLK_period*2;
		reset <= '0';
		assert false report "--- INICIANDO TEST DE INTEGRACION FINAL ---" severity note;
		
        -- Esperamos un tiempo prudencial para que termine el programa cargado en RAM-I
        wait for 1500 ns; 
        
        sim_finished <= '1';
        wait for CLK_period;
        assert false report "--- SIMULACION COMPLETADA ---" severity note;
		wait;
   end process;

  monitor_final: process(clk, sim_finished)
    alias inc_m is << signal .testbench.uut.io_mem.mc.inc_m : std_logic >>;
    alias inc_cb is << signal .testbench.uut.io_mem.mc.inc_cb : std_logic >>;
    alias abort is << signal .testbench.uut.io_mem.mem_error : std_logic >>;
    alias addr_d is << signal .testbench.uut.mips_addr : std_logic_vector(31 downto 0) >>;
    
    -- Nuevos Aliases para contadores de rendimiento
    alias m_count is << signal .testbench.uut.io_mem.mc.m_count : std_logic_vector(7 downto 0) >>;
    alias w_count is << signal .testbench.uut.io_mem.mc.w_count : std_logic_vector(7 downto 0) >>;
    alias r_count is << signal .testbench.uut.io_mem.mc.r_count : std_logic_vector(7 downto 0) >>;
    alias cb_count is << signal .testbench.uut.io_mem.mc.cb_count : std_logic_vector(7 downto 0) >>;

    -- Aliases para el Árbitro (Verificación de Test 7)
    alias grant_mips is << signal .testbench.uut.io_mem.MC_Bus_Grant : std_logic >>;
    alias grant_io is << signal .testbench.uut.io_mem.IO_M_bus_Grant : std_logic >>;
    alias req_mips is << signal .testbench.uut.io_mem.MC_Bus_Req : std_logic >>;
    alias req_io is << signal .testbench.uut.io_mem.IO_M_Req : std_logic >>;
    alias nc_sig is << signal .testbench.uut.io_mem.mc.addr_non_cacheable : std_logic >>;
    alias addr_sig is << signal .testbench.uut.io_mem.mc.Addr : std_logic_vector(31 downto 0) >>;
    
    variable abort_prev : std_logic := '0';
    variable grant_mips_prev : std_logic := '0';
    variable grant_io_prev : std_logic := '0';
    variable req_mips_prev : std_logic := '0';
  begin
    if rising_edge(clk) then
        if inc_m = '1' then
            assert false report ">>> [EVENTO] MISS en addr=" & to_hstring(addr_d) severity note;
        end if;
        if inc_cb = '1' then
            assert false report ">>> [EVENTO] COPY-BACK (Escritura de bloque sucio en RAM-D) <<<" severity note;
        end if;
        -- Detección de errores (Data Abort)
        if abort = '1' and abort_prev = '0' then
            assert false report ">>> [ALERTA] MEMORY ERROR / DATA ABORT DETECTADO! <<<" severity note;
        end if;
        abort_prev := abort;

        if req_mips = '1' and req_mips_prev = '0' then
            report ">>> [DEBUG] MIPS pide bus para addr=" & to_hstring(addr_sig) & " (NC=" & std_logic'image(nc_sig) & ")";
        end if;
        req_mips_prev := req_mips;

        if grant_mips = '1' and grant_mips_prev = '0' then
            assert false report ">>> [ARBITRAJE] Bus concedido al MIPS" severity note;
        end if;
        if grant_io = '1' and grant_io_prev = '0' then
            assert false report ">>> [ARBITRAJE] Bus concedido al IO_MASTER" severity note;
        end if;
        
        grant_mips_prev := grant_mips;
        grant_io_prev := grant_io;
    end if;

    if rising_edge(sim_finished) then
        assert false report "====================================================" severity note;
        assert false report "      AUDITORIA FINAL DE RENDIMIENTO (CACHE)        " severity note;
        assert false report "====================================================" severity note;
        assert false report " - Misses Totales:       " & integer'image(to_integer(unsigned(m_count))) severity note;
        assert false report " - Aciertos Lectura (r): " & integer'image(to_integer(unsigned(r_count))) severity note;
        assert false report " - Aciertos Escritura(w): " & integer'image(to_integer(unsigned(w_count))) severity note;
        assert false report " - Bloques Copy-Back:    " & integer'image(to_integer(unsigned(cb_count))) severity note;
        assert false report "====================================================" severity note;
    end if;
  end process;
  END;
