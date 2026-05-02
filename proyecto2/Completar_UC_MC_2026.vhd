---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:38:18 05/15/2014 
-- Design Name: 
-- Module Name:    UC_slave - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: la UC incluye un contador de 2 bits para llevar la cuenta de las transferencias de bloque y una m�quina de estados
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UC_MC_CB is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			-- �rdenes del MIPS
			RE : in  STD_LOGIC; 
			WE : in  STD_LOGIC;
			-- Respuesta al MIPS
			ready : out  STD_LOGIC; -- indica si podemos procesar la orden actual del MIPS en este ciclo. En caso contrario habr� que detener el MIPs
			-- Se�ales de la MC
			hit0 : in  STD_LOGIC; --se activa si hay acierto en la via 0
			hit1 : in  STD_LOGIC; --se activa si hay acierto en la via 1
			via_2_rpl :  in  STD_LOGIC; --indica que via se va a reemplazar
			addr_non_cacheable: in STD_LOGIC; --indica que la direcci�n no debe almacenarse en MC. En este caso porque pertenece a la scratch
			internal_addr: in STD_LOGIC; -- indica que la direcci�n solicitada es de un registro de MC
			MC_WE0 : out  STD_LOGIC;
            MC_WE1 : out  STD_LOGIC;
           	-- Se�ales para indicar la operaci�n que se quiere hacer en el bus
       		MC_bus_Read : out  STD_LOGIC; -- para pedir el bus en acceso de lectura
			MC_bus_Write : out  STD_LOGIC; --  para pedir el bus en acceso de escritura
			MC_tags_WE : out  STD_LOGIC; -- para escribir la etiqueta en la memoria de etiquetas
            palabra : out  STD_LOGIC_VECTOR (1 downto 0);--indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)
            mux_origen: out STD_LOGIC; -- Se utiliza para elegir si el origen de la direcci�n de la palabra y el dato es el Mips (cuando vale 0) o la UC y el bus (cuando vale 1)
			block_addr : out  STD_LOGIC; -- indica si la direcci�n a enviar es la de bloque (rm) o la de palabra (w)
			mux_output: out  std_logic_vector(1 downto 0); -- para elegir si le mandamos al procesador la salida de MC (valor 0),los datos que hay en el bus (valor 1), o un registro interno( valor 2)
			-- se�ales para los contadores de rendimiento de la MC
			inc_m : out STD_LOGIC; -- indica que ha habido un fallo en MC
			inc_w : out STD_LOGIC; -- indica que ha habido una escritura en MC
			inc_r : out STD_LOGIC; -- indica que ha habido una escritura en MC
			inc_cb :out STD_LOGIC; -- indica que ha habido un reemplazo sucio en MC
			-- Gesti�n de errores
			unaligned: in STD_LOGIC; --indica que la direcci�n solicitada por el MIPS no est� alineada
			Mem_ERROR: out std_logic; -- Se activa si en la ultima transferencia el esclavo no respondi� a su direcci�n
			load_addr_error: out std_logic; --para controlar el registro que guarda la direcci�n que caus� error
			-- Gesti�n de los bloques sucios
			send_dirty: out std_logic;-- Indica que hay que enviar la @ del bloque sucio
			Update_dirty	: out  STD_LOGIC; --indica que hay que actualizar los bits dirty tanto por que se ha realizado una escritura, como porque se ha enviado el bloque sucio a memoria
			dirty_bit_rpl : in  STD_LOGIC; --indica si el bloque a reemplazar es sucio
			Block_copied_back	: out  STD_LOGIC; -- indica que se ha enviado a memoria un bloque que estaba sucio. Se usa para elegir la m�scara que quita el bit de sucio
			-- Para gestionar las transferencias a trav�s del bus
			bus_TRDY : in  STD_LOGIC; --indica que la memoria puede realizar la operaci�n solicitada en este ciclo
			Bus_DevSel: in  STD_LOGIC; --indica que la memoria ha reconocido que la direcci�n est� dentro de su rango
			Bus_grant :  in  STD_LOGIC; --indica la concesi�n del uso del bus
			MC_send_addr_ctrl : out  STD_LOGIC; --ordena que se env�en la direcci�n y las se�ales de control al bus
            MC_send_data : out  STD_LOGIC; --ordena que se env�en los datos
            Frame : out  STD_LOGIC; --indica que la operaci�n no ha terminado
            last_word : out  STD_LOGIC; --indica que es el �ltimo dato de la transferencia
            Bus_req :  out  STD_LOGIC --indica la petici�n al �rbitro del uso del bus
			);
end UC_MC_CB;

architecture Behavioral of UC_MC_CB is
 
component counter is 
	generic (
	   size : integer := 10
	);
	Port ( clk : in  STD_LOGIC;
	       reset : in  STD_LOGIC;
	       count_enable : in  STD_LOGIC;
	       count : out  STD_LOGIC_VECTOR (size-1 downto 0)
					  );
end component;		           
-- Ejemplos de nombres de estado. No hay que usar estos. Nombrad a vuestros estados con nombres descriptivos. As� se facilita la depuraci�n
type state_type is (Inicio, single_word_transfer_addr, read_block, write_dirty_block, single_word_transfer_data, block_transfer_addr, block_transfer_data, Arbitraje, Send_ADDR_CB, fallo, CopyBack); 
type error_type is (memory_error, No_error); 
signal state, next_state : state_type; 
signal error_state, next_error_state : error_type; 
signal last_word_block: STD_LOGIC; --se activa cuando se est� pidiendo la �ltima palabra de un bloque
signal one_word: STD_LOGIC; --se activa cuando s�lo se quiere transferir una palabra
signal count_enable: STD_LOGIC; -- se activa si se ha recibido una palabra de un bloque para que se incremente el contador de palabras
signal hit: std_logic;
signal palabra_UC : STD_LOGIC_VECTOR (1 downto 0);
begin

hit <= hit0 or hit1;	
 
--el contador nos dice cuantas palabras hemos recibido. Se usa para saber cuando se termina la transferencia del bloque y para direccionar la palabra en la que se escribe el dato leido del bus en la MC
word_counter: counter 	generic map (size => 2)
						port map (clk, reset, count_enable, palabra_UC); --indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)

last_word_block <= '1' when palabra_UC="11" else '0';--se activa cuando estamos pidiendo la �ltima palabra

palabra <= palabra_UC;

   State_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            state <= Inicio;
         else
            state <= next_state;
         end if;        
      end if;
   end process;
 
   ---------------------------------------------------------------------------
-- 2023
-- M�quina de estados para el bit de error
---------------------------------------------------------------------------

error_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then           
            error_state <= No_error;
        else
            error_state <= next_error_state;
         end if;   
      end if;
   end process;
   
--Salida Mem Error
Mem_ERROR <= '1' when (error_state = memory_error) else '0';

   
   --MEALY State-Machine - Outputs based on state and inputs
   --Sensitivity list: check that all the combinational inputs used are included
   OUTPUT_DECODE: process (state, hit, last_word_block, bus_TRDY, RE, WE, Bus_DevSel, Bus_grant, via_2_rpl, hit0, hit1, dirty_bit_rpl, addr_non_cacheable, internal_addr, unaligned)
   begin
-- Default values
	MC_WE0 <= '0';
	MC_WE1 <= '0';
	MC_bus_Read <= '0';
	MC_bus_Write <= '0';
	MC_tags_WE <= '0';
    ready <= '0';
    mux_origen <= '0';
    MC_send_addr_ctrl <= '0';
    MC_send_data <= '0';
    next_state <= state;  
	count_enable <= '0';
	Frame <= '0';
	block_addr <= '0';
	inc_m <= '0';
	inc_w <= '0';
	inc_r <= '0';
	inc_cb <= '0';
	Bus_req <= '0';
	one_word <= '0';
	mux_output <= "00";
	last_word <= '0';
	next_error_state <= error_state; 
	load_addr_error <= '0';
	send_dirty <= '0';
	Update_dirty <= '0';
	Block_copied_back <= '0';
	
	    -- Inicio state          
    CASE state is 
		when Inicio => 			
        -- Estado Inicio          
		    if (RE = '0' and WE = '0') then -- si no piden nada no hacemos nada
				next_state <= Inicio;
				ready <= '1';
			elsif ((RE = '1') or (WE = '1')) and  (unaligned ='1') then -- si el procesador quiere leer una direcci�n no alineada
				-- Se procesa el error y se ignora la solicitud
				next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --�ltima direcci�n incorrecta (no alineada)
				load_addr_error <= '1';
		    elsif (RE= '1' and  internal_addr ='1') then -- si quieren leer un registro de la MC se lo mandamos
		    	next_state <= Inicio;
				ready <= '1';
				mux_output <= "10"; -- La salida es un registro interno de la MC
				next_error_state <= No_error; --Cuando se lee el registro interno el controlador quita la se�al de error
			elsif (WE = '1'  and  internal_addr ='1') then -- si quieren escribir en el registro interno de la MC se genera un error porque es s�lo de lectura
		    	next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --�ltima direcci�n incorrecta (intento de escritura en registro de lectura)
				load_addr_error <= '1';
			elsif (RE= '1' and  hit='1' and addr_non_cacheable = '0') then -- si piden y es acierto de lectura mandamos el dato
		        next_state <= Inicio;
				ready <= '1';
				inc_r <= '1'; -- se lee la MC
				mux_output <= "00"; --Es el valor por defecto. No hace falta ponerlo. La salida es un dato almacenado en la MC
			elsif ( WE= '1' and  hit='1' and addr_non_cacheable = '0') then -- si piden y es acierto de escritura 
				next_state <= Inicio;
				ready <= '1';
				inc_w <= '1';
				Update_dirty <= '1'; --Bloque sucio 
				if(hit0='1') then
					MC_WE0 <= '1';
				elsif(hit1='1') then
					MC_WE1 <= '1';
			    else
					--error 
				end if;
			elsif (((RE= '1') or (WE= '1')) and (hit='0' or addr_non_cacheable = '1')) then  --fallo O NO CACHEABLE
				next_state <= Arbitraje;
				if (addr_non_cacheable = '0' and dirty_bit_rpl = '0') then
					inc_m <= '1'; -- Solo contamos fallo si es cacheable y no estamos en medio de un reemplazo sucio
				end if;
			end if;

		when Arbitraje =>
			Bus_req <= '1';
			if (Bus_grant = '1') then
				if(addr_non_cacheable = '1' or WE = '1') then -- no cacheable o peticion de escritura
					next_state <= single_word_transfer_addr;
				else
					next_state <= block_transfer_addr;
				end if;
			else 
				next_state <= Arbitraje;
			end if;
		
		when block_transfer_addr =>
			Frame <= '1';
			MC_send_addr_ctrl <= '1';
			Bus_req <= '1';
			block_addr <= '1';

			if (dirty_bit_rpl = '1') then
				send_dirty <= '1';
				MC_bus_Write <= '1';
				if(Bus_DevSel = '1') then
					next_state <= CopyBack;
				else -- ERROR DE MEMORIA
					next_error_state <= memory_error;
					load_addr_error <= '1';
					ready <= '1'; -- Avisamos al MIPS para no colgarlo (faltaba aquí)
					next_state <= Inicio;
				end if;
			else
				MC_bus_Read <= '1';
				if(Bus_DevSel = '1') then
					next_state <= block_transfer_data;
				else -- ERROR DE MEMORIA
					next_error_state <= memory_error;
					load_addr_error <= '1';
					ready <= '1'; -- Avisamos al MIPS para no colgarlo
					next_state <= Inicio;
				end if;
			end if;

		when CopyBack=>
			Frame <= '1'; -- Mantenemos el bus 
			Bus_req <= '1'; -- Bus ocupado
			MC_send_data <= '1'; -- Mandamos los datos
			MC_bus_Write <= '1'; -- Mantenemos la señal de escritura en el bus
			mux_origen <= '1'; -- Origen los datos del bloque a guardar viene de MC 
			block_addr <= '1'; 
			send_dirty <= '1'; 
			
			if(Bus_TRDY = '1') then
				count_enable <= '1';
				if(last_word_block = '1') then
					last_word <= '1';
					next_state <= Inicio;
					inc_cb <= '1';
					Update_dirty <= '1';
					Block_copied_back <= '1';
				else 
					next_state <= CopyBack;
				end if;
			else 
				next_state <= CopyBack;
			end if;
		
		when block_transfer_data =>
			Bus_req <= '1';
			Frame <= '1';
			MC_bus_Read <= '1';	
			mux_origen <= '1';
			block_addr <= '1';
			mux_output <= "01";
			
			if(Bus_TRDY = '1') then
				count_enable <= '1';
				if(via_2_rpl = '0') then
					MC_WE0 <= '1';
				else 
					MC_WE1 <= '1';
				end if;
				if(last_word_block = '1') then
					last_word <= '1';
					MC_tags_WE <= '1';
					next_state <= Inicio;
				else 
					next_state <= block_transfer_data;
				end if;
			else 
				next_state <= block_transfer_data;
			end if;
		
		when single_word_transfer_addr =>
			Frame <= '1';
			MC_send_addr_ctrl <= '1';
			Bus_req <= '1';
			block_addr <= '0';
			one_word <= '1';

			if(RE = '1') then -- lectura
				MC_bus_Read <= '1';
		
			else 
				MC_bus_Write <= '1';
			end if;
		
			-- Si la dirección es no cacheable (Scratchpad), ya sabemos que responderá.
			-- No hace falta esperar DevSel (el Scratchpad lo activa el ciclo siguiente).
			-- Solo se comprueba DevSel para detectar errores en accesos a dir. desconocidas.
			if(Bus_DevSel = '1' or addr_non_cacheable = '1') then
				next_state <= single_word_transfer_data;
			else -- ERROR DE MEMORIA: ningún esclavo reconoció la dirección
				next_error_state <= memory_error;
				load_addr_error <= '1';
				ready <= '1';
				next_state <= Inicio;
			end if;
		when single_word_transfer_data =>
			Frame <= '1';
			Bus_req <= '1';
			block_addr <= '0';
			one_word <= '1';
			last_word <= '1';
			
			if(RE = '1') then -- lectura
				MC_bus_Read <= '1';
				mux_output <= "01";	
			else -- escritura
				MC_bus_Write <= '1';
				MC_send_data <= '1';
			end if;

			if(Bus_TRDY = '1') then
				ready <= '1'; -- Le decimos al procesador que su palabra est lista
				next_state <= Inicio;
			else 
				next_state <= single_word_transfer_data;
			end if;
					
    -- COMPLETE  with other states
		
		WHEN others => 	
	end CASE; 
	 	
end process; 

end Behavioral;

