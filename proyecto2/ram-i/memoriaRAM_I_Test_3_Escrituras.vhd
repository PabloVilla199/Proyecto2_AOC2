----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 3: Políticas de Escritura y Coherencia)
-- ===============================================================================
-- GUIA DEFINITIVA PARA EL REPORT (Políticas Write-Around y Dirty Bit):
-- ===============================================================================
--
-- 1. [T=45.0 ns] FALLO DE ESCRITURA (POLÍTICA WRITE-AROUND)
--    - Instrucción: sw $2, 0x0020($0)
--    - FSM: Inicio -> Send_Addr -> single_word_transfer_addr.
--    - Qué capturar: hit='0', mc_bus_write='1', one_word='1', block_addr='0'.
--    - Explicación: Al ser un fallo de escritura, la UC NO trae el bloque. Envía 
--      el dato directamente a la RAM por el bus. La caché permanece vacía.
--
-- 2. [T=175.0 ns] CARGA DEL BLOQUE (PREPARACIÓN)
--    - Instrucción: lw $3, 0x0020($0)
--    - FSM: block_transfer_data (Ráfaga completa).
--    - Qué capturar: mc_we0='1' durante los 4 pulsos de bus_trdy.
--    - Explicación: Forzamos la carga del bloque 0x20 a la caché para poder 
--      probar un acierto de escritura en el siguiente paso.
--
-- 3. [T=355.0 ns] ACIERTO DE ESCRITURA (MARCADO DE DIRTY)
--    - Instrucción: sw $3, 0x0024($0) -> Dirección en el mismo bloque anterior.
--    - FSM: Inicio (Se resuelve en un ciclo).
--    - Qué capturar: hit='1', ready='1', mc_we0='1', Update_dirty='1'.
--    - Explicación: ¡CLAVE! Como el bloque ya está en la Vía 0, se escribe el dato
--      localmente y se activa Update_dirty. El bloque ahora es "sucio".
--
-- 4. [T=365 ns en adelante] VERIFICACIÓN DE ESTADÍSTICAS
--    - Qué observar: inc_w='1' (en T=355), inc_m='1' (solo en T=175).
--    - Explicación: El fallo de escritura inicial (T=45) no debe sumar inc_m 
--      si así lo requiere tu diseño, o sumarlo pero sin cargar bloque.
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
        X"0C020020", -- 0: [45 ns] sw $2, 0x0020($0) -> FALLO E (Write-Around)
        X"00000000", -- 4: nop
        X"08030020", -- 8: [175 ns] lw $3, 0x0020($0) -> FALLO L (Carga bloque)
        X"00000000", -- C: nop
        X"0C030024", -- 10: [355 ns] sw $3, 0x0024($0) -> ACIERTO E (Marca Dirty)
        X"1000FFFF", -- 14: beq $0, $0, -1
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