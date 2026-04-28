----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 2: Aciertos y Fallos de Lectura - Localidad Espacial)
-- ===============================================================================
-- GUIA DEFINITIVA PARA EL REPORT (Cronología de Capturas):
-- ===============================================================================
--
-- 1. [T=45.0 ns] DETECCIÓN DEL FALLO INICIAL (MISS)
--    - Instrucción: lw $8, 256($0) -> Dirección 0x100
--    - FSM: Inicio -> Send_Addr.
--    - Qué capturar: ready='0', stall_mips='1', bus_req='1'.
--    - Explicación: La MC detecta que el dato no está. Detiene el pipeline para 
--      iniciar el arbitraje del bus.
--
-- 2. [T=145 ns a 205 ns] CARGA EN RÁFAGA (BURST)
--    - FSM: block_transfer_data.
--    - Qué capturar: Pulsos de bus_trdy='1', mc_we0='1' y el contador 'palabra'
--      incrementando de 0 a 3.
--    - Explicación: Se traen las 4 palabras del bloque desde la RAM-D hacia la vía 0.
--
-- 3. [T=215 ns] CIERRE DE TRANSFERENCIA Y ETIQUETAS
--    - FSM: block_transfer_data -> bajar_Frame.
--    - Qué capturar: mc_tags_we='1' (se valida el bloque) y last_word='1'.
--    - Explicación: El bloque ya es oficial en la caché. Se libera el bus.
--
-- 4. [T=275.0 ns] EL MOMENTO DEL HIT (LOCALIDAD ESPACIAL)
--    - Instrucción: lw $9, 260($0) -> Dirección 0x104 (Siguiente palabra)
--    - FSM: Inicio (Se queda en Inicio, no salta al árbitro).
--    - Qué capturar: hit='1', ready='1', stall_mips='0', bus_req='0'.
--    - Explicación: ¡CLAVE! Como cargamos 4 palabras antes, esta dirección ya está 
--      en la caché. El procesador NO se detiene. Latencia de 1 ciclo.
--
-- 5. [T=315.0 ns] CAMBIO DE LÍNEA Y SEGUNDO FALLO
--    - Instrucción: lw $10, 512($0) -> Dirección 0x200 (Nueva etiqueta)
--    - FSM: Inicio -> Send_Addr.
--    - Qué capturar: ready vuelve a '0', stall_mips='1'.
--    - Explicación: Se accede a un bloque distinto. La UC repite el proceso de carga.
-- ===============================================================================
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity memoriaRAM_I is port (
          CLK  : in std_logic;
          ADDR : in std_logic_vector (31 downto 0);
          Din  : in std_logic_vector (31 downto 0);
          WE   : in std_logic;
          RE   : in std_logic;
          Dout : out std_logic_vector (31 downto 0));
end memoriaRAM_I;

architecture Behavioral of memoriaRAM_I is
    type RamType is array(0 to 127) of std_logic_vector(31 downto 0);
    signal RAM : RamType := (
        X"08080100", -- 0: [45 ns] lw $8, 256($0)  -> MISS (Trae bloque 0x100)
        X"08090104", -- 14: [255 ns aprox] lw $9, 260($0) -> HIT (Localidad espacial)
        X"080A0200", -- 24: [315 ns aprox] lw $10, 512($0) -> MISS (Nuevo bloque 0x200)
        X"1000FFFF", -- 28: beq $0, $0, -1
        others => X"00000000"
    );
    signal dir_7: std_logic_vector(6 downto 0); 
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