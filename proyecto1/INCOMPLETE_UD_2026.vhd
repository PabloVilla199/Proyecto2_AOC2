------------------------------------------------------------------------------------
-- Company: Univesidad de Zaragoza
-- Engineer: Tahir Berga, Pablo Villa.
-- Desxription: Unidad de Detención (Stalling Unit) para el proyecto de MIPS segmentado.
-- Esta unidad detecta situaciones en las que la ejecución de una instrucción debe ser detenida
-- para evitar errores de datos o control. Maneja casos como Load-Use, saltos tomados, y operaciones
-- de la ALU que requieren varios ciclos (MAC).
-- Unversidad de Zaragoza - Arquitectura de Computadores 2  2025-2026
-----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UD is
    Port ( 
        valid_I_ID    : in  STD_LOGIC; 
        valid_I_EX    : in  STD_LOGIC; 
        valid_I_MEM   : in  STD_LOGIC; 
        Reg_Rs_ID     : in  STD_LOGIC_VECTOR (4 downto 0); 
        Reg_Rt_ID     : in  STD_LOGIC_VECTOR (4 downto 0);
        MemRead_EX    : in  std_logic; 
        RegWrite_EX   : in  std_logic;
        RW_EX         : in  STD_LOGIC_VECTOR (4 downto 0);
        RegWrite_Mem  : in  std_logic;
        RW_Mem        : in  STD_LOGIC_VECTOR (4 downto 0);
        IR_op_code    : in  STD_LOGIC_VECTOR (5 downto 0); 
        salto_tomado  : in  std_logic; 
        ALU_ready     : in  std_logic; 
        JAL_EX        : in  std_logic; 
        JAL_MEM       : in  std_logic; 
        IO_MEM_ready  : in  std_logic; 
        stall_MIPS    : out STD_LOGIC; 
        Kill_IF       : out STD_LOGIC; 
        stall_ID      : out STD_LOGIC 
    ); 
end UD;

architecture Behavioral of UD is

    signal dep_rs_EX, dep_rs_Mem, dep_rt_EX, dep_rt_Mem : std_logic;
    signal ld_uso_rs, ld_uso_rt, JAL_uso_rs, JAL_uso_rt : std_logic;
	signal ld_uso, jal_uso, beq_uso : std_logic; 
    signal RET_rs, BEQ_rs, BEQ_rt, riesgo_datos_ID    : std_logic;
    signal stall_MIPS_internal, rs_read, rt_read       : std_logic;

    -- Constantes de Opcodes
    constant ARIT_opcode : std_logic_vector(5 downto 0) := "000001";
    constant LW_opcode   : std_logic_vector(5 downto 0) := "000010";
    constant SW_opcode   : std_logic_vector(5 downto 0) := "000011";
    constant BEQ_opcode  : std_logic_vector(5 downto 0) := "000100";
    constant JAL_opcode  : std_logic_vector(5 downto 0) := "000101";
    constant RET_opcode  : std_logic_vector(5 downto 0) := "000110";
    constant FI_opcode   : std_logic_vector(5 downto 0) := "010000";

begin

-- Casos que activan Kill_IF
-- ------------------------------------------------------------------
-- | Caso | Instrucción en ID | Condición           | Señal activada|
-- |------|-------------------|---------------------|---------------|
-- | 1    | Salto JAL BEQ RET | salto_tomado=1 y    |Kill_IF=1      |
--                            | valid_I_ID=1        |               |
-- ------------------------------------------------------------------

-- Casos que activan stall_ID
-- -----------------------------------------------------------------------------------------------------------------------------------
-- | Caso | Instrucción en ID | Instrucción en EX/MEM | Condición de Riesgo                  | Señal activada | Efecto                |
-- |------|-------------------|-----------------------|--------------------------------------|----------------|-----------------------|
-- | 1    | BEQ               | Escribe registro      | dep_rs_*=1 o dep_rt_*=1              | BEQ_rs/BEQ_rt  | Espera hasta WB       |
-- | 2    | Lee registro      | LW (en EX)            | dep_rs/rt_EX=1 y MemRead_EX=1        | ld_uso_rs/rt   | Carga-uso, 1 ciclo    |
-- | 3    | Lee registro      | JAL (en EX o MEM)     | dep_rs/rt_*=1 y JAL_*=1              | JAL_uso_rs/rt  | Espera hasta WB       |
-- | 4    | RET               | Escribe registro      | dep_rs_EX=1 o dep_rs_Mem=1           | RET_rs         | Espera hasta WB       |
-- -----------------------------------------------------------------------------------------------------------------------------------

-- Casos que activan stall_MIPS
-- -------------------------------------------------------------
-- | Caso | Condición global                | Señal activada |
-- |------|---------------------------------|---------------|
-- | 1    | not(IO_MEM_ready) and valid_I_MEM| stall_MIPS=1  |
-- | 2    | not(ALU_ready) and valid_I_EX    | stall_MIPS=1  |
-- -------------------------------------------------------------

-- Casos que NO activan paradas
-- ------------------------------------------------------------------------------
-- | Caso | Instrucción en ID | Instrucción en EX/MEM | Condición                |
-- |------|-------------------|-----------------------|--------------------------|
-- | 1    | Lee registro      | ARIT / SW             | dep_* = 1 (forwarding)   |
-- | 2    | NOP / RTE         | Cualquiera            | dep_* = 0                |
-- | 3    | Cualquiera        | Cualquiera            | dep_* = 0 (sin dependencias)|
-- | 4    | JAL               | Cualquiera            | JAL no lee registro      |
-- | 5    | Lee registro      | LW (en MEM)           | Dato disponible (forwarding normal)|
-- ------------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    -- 1. IDENTIFICACIÓN DE USO DE REGISTROS (rs_read / rt_read)
    ---------------------------------------------------------------------------
    rs_read <= '1' when (IR_op_code = ARIT_opcode or IR_op_code = LW_opcode or 
                         IR_op_code = SW_opcode   or IR_op_code = BEQ_opcode or 
                         IR_op_code = RET_opcode  or IR_op_code = FI_opcode) else '0';

    rt_read <= '1' when (IR_op_code = ARIT_opcode or IR_op_code = SW_opcode or 
                         IR_op_code = BEQ_opcode  or IR_op_code = FI_opcode) else '0';

    ---------------------------------------------------------------------------
    -- 2. DETECCIÓN DE DEPENDENCIAS (ID vs EX/MEM)
    ---------------------------------------------------------------------------
    -- Incluimos RegWrite aquí para que la dependencia sea real: 
    -- "ID quiere leer un registro que EX o MEM van a escribir"
    dep_rs_EX  <= '1' when (valid_I_EX = '1'  and valid_I_ID = '1' and 
                            rs_read = '1'     and Reg_Rs_ID = RW_EX and 
                            RegWrite_EX = '1') else '0';
                            
    dep_rs_Mem <= '1' when (valid_I_MEM = '1' and valid_I_ID = '1' and 
                            rs_read = '1'     and Reg_Rs_ID = RW_Mem and 
                            RegWrite_Mem = '1') else '0';
    
    dep_rt_EX  <= '1' when (valid_I_EX = '1'  and valid_I_ID = '1' and 
                            rt_read = '1'     and Reg_Rt_ID = RW_EX and 
                            RegWrite_EX = '1') else '0';
                                
    dep_rt_Mem <= '1' when (valid_I_MEM = '1' and valid_I_ID = '1' and 
                            rt_read = '1'     and Reg_Rt_ID = RW_Mem and 
                            RegWrite_Mem = '1') else '0';

    ---------------------------------------------------------------------------
    -- 3. RIESGOS DE DATOS (Data Hazards)
    ---------------------------------------------------------------------------
    -- Load-Use: Si hay un LW en EX y el consumidor en ID, stall de 1 ciclo
    ld_uso_rs <= '1' when (MemRead_EX = '1' and dep_rs_EX = '1') else '0';
    ld_uso_rt <= '1' when (MemRead_EX = '1' and dep_rt_EX = '1') else '0';

	ld_uso <= ld_uso_rs or ld_uso_rt; 
                                    
    -- el BEQ debe parar hasta que el dato llegue a WB.
    BEQ_rs <= '1' when (IR_op_code = BEQ_opcode and (dep_rs_EX = '1' or dep_rs_Mem = '1')) else '0';
    BEQ_rt <= '1' when (IR_op_code = BEQ_opcode and (dep_rt_EX = '1' or dep_rt_Mem = '1')) else '0';

	beq_uso <= BEQ_rs or BEQ_rt;
    
    -- CASO RET: Igual que el BEQ, usa Rs en ID y debe esperar al productor
    RET_rs <= '1' when (IR_op_code = RET_opcode and (dep_rs_EX = '1' or dep_rs_Mem = '1')) else '0';
    
    -- JAL: Parada si ID necesita el registro que JAL está escribiendo en EX 
    -- Cuando este en MEM hacemos forwarding normal en WB
    JAL_uso_rs <= '1' when ((dep_rs_EX = '1' and JAL_EX = '1')) else '0';
    JAL_uso_rt <= '1' when ((dep_rt_EX = '1' and JAL_EX = '1')) else '0';

	jal_uso <= JAL_uso_rs or JAL_uso_rt;							
   ---------------------------------------------------------------------------
    -- 4. CONTROL DE PARADAS E INVALIDACIÓN
    ---------------------------------------------------------------------------
    riesgo_datos_ID <= ld_uso or beq_uso or RET_rs or jal_uso;
    
    stall_ID <= riesgo_datos_ID;

    -- Kill_IF: Solo mata la instrucción en IF si NO estamos estaleando ID 
    -- (si estaleamos ID, el salto_tomado de la instrucción anterior aún no es válido)
    Kill_IF <= '1' when (salto_tomado = '1' and valid_I_ID = '1') else '0';

    -- stall_MIPS: Parada global por memoria lenta o ALU multiciclo (MAC)
    stall_MIPS_internal <= (not(IO_MEM_ready) and valid_I_MEM) or (not(ALU_ready) and valid_I_EX);
    stall_MIPS <= stall_MIPS_internal;

end Behavioral;