-----------------------------------------------------------------------------------
-- Author: Tahir Berga, Pablo Villa.
-- Description: Unidad de Anticipación (Forwarding Unit) para el proyecto de MIPS segmentado.
-- Esta unidad detecta dependencias de datos entre instrucciones en ejecución y activa el forwarding
-- para evitar stalls cuando es posible. También maneja el caso especial de JAL a distancia 2.
-- Unversidad de Zaragoza - Arquitectura de Computadores 2  2025-2026
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UA is
	Port(
			valid_I_MEM : in  STD_LOGIC; --valid bits
			valid_I_WB : in  STD_LOGIC; 
			Reg_Rs_EX: IN  std_logic_vector(4 downto 0); 
			Reg_Rt_EX: IN  std_logic_vector(4 downto 0);
			RegWrite_MEM: IN std_logic;
			RW_MEM: IN  std_logic_vector(4 downto 0);
			RegWrite_WB: IN std_logic;
			RW_WB: IN  std_logic_vector(4 downto 0);
			MUX_ctrl_A: out std_logic_vector(1 downto 0);
			MUX_ctrl_B: out std_logic_vector(1 downto 0)
		);
	end UA;

Architecture Behavioral of UA is
signal Corto_A_Mem, Corto_B_Mem, Corto_A_WB, Corto_B_WB: std_logic;
signal use_rs_EX, use_rt_EX: std_logic; 
begin


-- =====================================================================================
-- FORWARDING (ANTICIPACIÓN) - Unidad de Anticipación
-- =====================================================================================
-- Esta unidad detecta dependencias de datos entre instrucciones productoras (en MEM/WB)
-- e instrucciones consumidoras (en EX) y activa el forwarding cuando es posible.
--
-- RUTAS DE FORWARDING:
--   1) MEM→EX: productora a distancia 1 (más reciente, tiene prioridad)
--   2) WB→EX:  productora a distancia 2
--
-- =====================================================================================
-- CASO ESPECIAL: JAL (Jump and Link)
-- =====================================================================================
-- JAL escribe PC+4 en un registro (en WB), pero NO usa la ALU.
-- 
-- JAL DISTANCIA 1 (NO funciona forwarding en UA):
--   JAL R7, @sub    F  D  E  M  W    ← PC4 está en PC4_MEM (NO en ALU_out_MEM)
--   ADD R8, R7, R1     F  D  E  M  W
--                           ↑  ↑
--                          EX MEM (ALU_out_MEM = basura, PC4 no disponible)
--
--   Problema: Mux_A recibe ALU_out_MEM como entrada "01", pero JAL no usa ALU.
--   Solución: UD detecta JAL_uso_rs/rt='1' → STALL 1 ciclo
--
-- JAL DISTANCIA 2 (SÍ funciona forwarding en UA):
--   JAL R7, @sub    F  D  E  M  W         ← PC4 llega a busW
--   NOP                F  D  E  M  W
--   ADD R8, R7, R1        F  D  E  M  W
--                              ↑       ↑
--                             EX      WB (busW = PC4_WB)
--
--   Funcionamiento: 
--     - En el MIPS proyecto, el mux de write-back está controlado por:
--       ctrl_Mux4a1_escritura_BR = jal_WB & MemtoReg_WB
--     - Cuando jal_WB='1', el mux selecciona PC4_WB → busW = PC4_WB
--     - UA detecta dependencia normalmente: Corto_A_WB='1' → MUX_ctrl_A="10"
--     - Mux_A toma busW (que YA tiene PC4 gracias al mux de write-back)
--
-- =====================================================================================

-- ===========================================================================================================================
-- | Caso | Escenario de Dependencia | Condición UA (VHDL)                                   | Señal Activa   | Mux ALU      |
-- |------|--------------------------|-------------------------------------------------------|----------------|--------------|
-- |  1   | MEM -> EX (Operando Rs)  | (Reg_Rs_EX = RW_MEM) and RegWrite_MEM and valid_I_MEM | Corto_A_Mem=1  | Mux_A = "01" |
-- |  2   | MEM -> EX (Operando Rt)  | (Reg_Rt_EX = RW_MEM) and RegWrite_MEM and valid_I_MEM | Corto_B_Mem=1  | Mux_B = "01" |
-- |  3   | WB  -> EX (Operando Rs)  | (Reg_Rs_EX = RW_WB)  and RegWrite_WB  and valid_I_WB  | Corto_A_WB=1   | Mux_A = "10" |
-- |  4   | WB  -> EX (Operando Rt)  | (Reg_Rt_EX = RW_WB)  and RegWrite_WB  and valid_I_WB  | Corto_B_WB=1   | Mux_B = "10" |
-- |  5   | Doble (Prioridad MEM)    | Corto_MEM = '1' and Corto_WB = '1'                    | Corto_A/B_Mem  | Mux_A/B="01" |
-- |  6   | JAL Distancia 2 (busW)   | (Reg_Rs/t_EX = RW_WB) and jal_WB = '1'                | Corto_A/B_WB=1 | Mux_A/B="10" |
-- |  7   | Sin Riesgo  / NOP        | Default                                               | Ninguna        | Mux_A/B="00" |
-- ===========================================================================================================================

-------------------------------------------------------------------------------------------------------------------------------
-- Detección de Forwarding MEM→EX (distancia 1, prioridad alta)
-------------------------------------------------------------------------------------------------------------------------------

	-- Forwarding MEM→EX para operando A (Rs):
	-- Detecta si la instrucción en MEM escribe en el registro que Rs necesita leer
	Corto_A_Mem <= '1' when ((Reg_Rs_EX = RW_MEM)          -- Rs de EX == Rd de MEM
	                    and (RegWrite_MEM = '1')           -- MEM escribe en registro
	                    and (valid_I_MEM = '1'))           -- MEM tiene instrucción válida
	               else '0';
	
	-- Forwarding MEM→EX para operando B (Rt):
	-- Detecta si la instrucción en MEM escribe en el registro que Rt necesita leer
	Corto_B_Mem <= '1' when ((Reg_Rt_EX = RW_MEM)          -- Rt de EX == Rd de MEM
	                    and (RegWrite_MEM = '1')           -- MEM escribe en registro
	                    and (valid_I_MEM = '1'))           -- MEM tiene instrucción válida
	               else '0';

-------------------------------------------------------------------------------------------------------------------------------
-- Detección de Forwarding WB→EX (distancia 2, prioridad baja)
-------------------------------------------------------------------------------------------------------------------------------

	-- Forwarding WB→EX para operando A (Rs):
	-- Detecta si la instrucción en WB escribe en el registro que Rs necesita leer (distancia 2)
	-- NOTA: Funciona para JAL a distancia 2 porque busW ya tiene PC4_WB
	Corto_A_WB  <= '1' when ((Reg_Rs_EX = RW_WB)           -- Rs de EX == Rd de WB
	                    and (RegWrite_WB = '1')            -- WB escribe en registro
	                    and (valid_I_WB = '1'))            -- WB tiene instrucción válida
	               else '0';
	
	-- Forwarding WB→EX para operando B (Rt):
	-- Detecta si la instrucción en WB escribe en el registro que Rt necesita leer (distancia 2)
	-- NOTA: Funciona para JAL a distancia 2 porque busW ya tiene PC4_WB 
	Corto_B_WB  <= '1' when ((Reg_Rt_EX = RW_WB)           -- Rt de EX == Rd de WB
	                    and (RegWrite_WB = '1')            -- WB escribe en registro
	                    and (valid_I_WB = '1'))            -- WB tiene instrucción válida
	               else '0';
-------------------------------------------------------------------------------------------------------------------------------
-- Control de Muxes de Forwarding (con prioridad MEM > WB > BR)
-------------------------------------------------------------------------------------------------------------------------------
	-- Entradas de los muxes:
	--   "00": dato del Banco de Registros (sin forwarding)
	--   "01": dato desde MEM (ALU_out_MEM) - forwarding MEM→EX
	--   "10": dato desde WB (busW) - forwarding WB→EX
	--
	-- Razón: Si hay doble dependencia (productora en MEM y productora en WB),
	--        tomamos la de MEM porque es más reciente (el valor correcto).
	--
	-- Ejemplo de doble dependencia:
	--   ADD R1, R2, R3    F  D  E  M  W     ← R1 = 10 (viejo, en WB)
	--   ADD R1, R4, R5       F  D  E  M  W  ← R1 = 20 (nuevo, en MEM)
	--   SUB R6, R1, R7          F  D  E  M  W  ← debe usar R1 = 20
	--                                 ↑  ↑  ↑
	--                                EX MEM WB
	--   Solución: MUX_ctrl_A = "01" (toma MEM, no WB)
	
	-- MUX para operando A (Rs):
	MUX_ctrl_A <= 	"01" when (Corto_A_Mem = '1') else  -- Prioridad 1: MEM (más reciente)
					"10" when (Corto_A_WB = '1')  else  -- Prioridad 2: WB
					"00";                                -- Default: Banco de Registros
	
	-- MUX para operando B (Rt):
	MUX_ctrl_B <= 	"01" when (Corto_B_Mem = '1') else  -- Prioridad 1: MEM (más reciente)
					"10" when (Corto_B_WB = '1')  else  -- Prioridad 2: WB
					"00";                                -- Default: Banco de Registros	
end Behavioral;