----------------------------------------------------------------------------------
-- Módulo: memoriaRAM_I (Test 8: Integración Completa - Estrés y Bucle)
-- ===============================================================================
-- Este test ejecuta TODA la funcionalidad de la memoria de forma intensiva y en 
-- bucle, diseñado para poder medir el Speedup del sistema (Cache vs No-Cache) y
-- detectar problemas (side-effects) en ejecuciones largas.
-- Incluye la generación de todos los errores posibles solicitados.
-- ===============================================================================
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
        -- 1. INICIALIZACIÓN Y SCRATCHPAD
        X"08080100", -- 0: lw $8, 256($0)    | Trae 0x10000000 desde MD a $8
        X"09090000", -- 1: lw $9, 0($8)      | Lectura de MD Scratch
        X"0D090004", -- 2: sw $9, 4($8)      | Escritura en MD Scratch

        -- 2. LLENADO DE LA CACHÉ (MISSES LIMPIOS)
        X"080A0000", -- 3: lw $10, 0($0)     | Miss: Set 0, Vía 0 (Bloque 0)
        X"080B0020", -- 4: lw $11, 32($0)    | Miss: Set 0, Vía 1 (Bloque 2)
        X"080C0010", -- 5: lw $12, 16($0)    | Miss: Set 1, Vía 0 (Bloque 1)
        X"080D0030", -- 6: lw $13, 48($0)    | Miss: Set 1, Vía 1 (Bloque 3)

        -- 3. ENSUCIADO DE LA CACHÉ (HITS DE ESCRITURA -> DIRTY)
        X"0C0A0004", -- 7: sw $10, 4($0)     | Hit: Ensucia Bloque 0
        X"0C0B0024", -- 8: sw $11, 36($0)    | Hit: Ensucia Bloque 2
        X"0C0C0014", -- 9: sw $12, 20($0)    | Hit: Ensucia Bloque 1
        X"0C0D0034", -- 10: sw $13, 52($0)   | Hit: Ensucia Bloque 3

        -- 4. WRITE-AROUND A MD DIRECTO
        X"0C0A0040", -- 11: sw $10, 64($0)   | Miss Write: a Bloque 4 (Set 0) -> a MD
        X"0C0B0050", -- 12: sw $11, 80($0)   | Miss Write: a Bloque 5 (Set 1) -> a MD

        -- 5. REEMPLAZO DE BLOQUES SUCIOS (COPY-BACK)
        X"080E0080", -- 13: lw $14, 128($0)  | Expulsa Vía 0 (Bloque 0 Sucio) -> Copy-Back a MD
        X"080F00A0", -- 14: lw $15, 160($0)  | Expulsa Vía 1 (Bloque 2 Sucio) -> Copy-Back a MD
        X"080E0090", -- 15: lw $14, 144($0)  | Expulsa Vía 0 (Bloque 1 Sucio) -> Copy-Back a MD
        X"080F00B0", -- 16: lw $15, 176($0)  | Expulsa Vía 1 (Bloque 3 Sucio) -> Copy-Back a MD

        -- 6. EXCEPCIONES Y ERRORES DEL BUS (DATA ABORT)
        X"08100001", -- 17: lw $16, 1($0)    | Error 1: Acceso desalineado
        X"08110108", -- 18: lw $17, 264($0)  | Carga base de registros internos (0x01000000)
        X"0E310000", -- 19: sw $17, 0($17)   | Error 2: Escritura en registro Read-Only
        X"0A310000", -- 20: lw $17, 0($17)   | Acierto: Lectura de reg interno (Limpia error)
        X"08104000", -- 21: lw $16, 16384($0)| Error 3: Timeout del Bus (No DevSel)

        -- 7. BUCLE INFINITO
        X"1000FFE9", -- 22: beq $0, $0, -23  | Salto incondicional al inicio (instrucción 0)
        
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
