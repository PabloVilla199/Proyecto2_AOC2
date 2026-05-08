----------------------------------------------------------------------------------
-- Mdulo: memoriaRAM_I (Test 1: Accesos a Scratchpad)
-- ===============================================================================
-- GUIA DEFINITIVA PARA EL REPORT (Sigue estos puntos para tus capturas):
-- ===============================================================================
--
-- 1. [T=45 ns] EL MOMENTO DEL MISS (Fallo de Lectura)
--    - Se ejecuta: lw $8, 256($0)
--    - FSM: Inicio -> fallo -> Send_Addr.
--    - Qué capturar: bus_req='1' (petición de bus), stall_mips='1' (CPU congelada).
--    - Explicación: La dirección 0x100 no está en caché. La FSM detiene el pipeline
--      y activa la petición al árbitro del bus.
--
-- 2. [T=175 ns] CONCESION DEL BUS Y CARGA
--    - FSM: Send_Addr -> read_block (cuando bus_grant='1').
--    - Qué capturar: bus_grant='1', mc_addr_bus mostrando 0x100, 0x104...
--    - Explicación: El árbitro da paso. La caché empieza a leer el bloque de 4 
--      palabras de la RAM-D. Verás como bus_trdy pulsa 4 veces.
--
-- 3. [T=235 ns] FIN DEL STALL Y ACTUALIZACION
--    - FSM: read_block -> Inicio.
--    - Qué capturar: ready='1', stall_mips='0', bus_req='0'.
--    - Explicación: El bloque está cargado. La caché libera al MIPS y le entrega 
--      el dato 0x10000000. El registro $8 por fin se actualiza.
--
-- 4. [T=255 ns] ACCESO AL SCRATCHPAD (Lectura No Cacheable)
--    - Se ejecuta: lw $9, 0($8) -> Dirección 0x10000000.
--    - FSM: Inicio -> single_word_transfer_addr -> single_word_transfer_data.
--    - Qué capturar: single_word='1' (señal interna), bus_req='1', ready='1'.
--    - Explicación: La caché detecta el rango 0x1000.... y activa el modo
--      no cacheable. Pide el bus para una sola palabra y responde rápido.
--
-- 5. [T=385 ns] ESCRITURA EN SCRATCHPAD
--    - Se ejecuta: sw $9, 4($8) -> Dirección 0x10000004.
--    - FSM: Inicio -> single_word_transfer_addr -> single_word_transfer_data.
--    - Qué capturar: we='1', bus_req='1', bus_grant='1'.
--    - Explicación: Se escribe el dato en el Scratchpad externo a través del bus.
-- ===============================================================================
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
    X"08080100", -- 0: [45 ns] lw $8, 256($0) -> Carga de RAM-D
    X"09090000", -- 14: [255 ns] lw $9, 0($8)  -> LECTURA SCRATCHPAD
    X"0D090004", -- 24: [365 ns] sw $9, 4($8)  -> ESCRITURA SCRATCHPAD
    X"1000FFFF", -- 28: beq $0, $0, -1
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
