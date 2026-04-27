----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:10:07 04/01/2026 
-- Design Name: 
-- Module Name:    ALU - Behavioral with support for vectorial MAC with internal accumulation
-- Additional Comments: by AOC2 Team Unizar 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;



entity ALU_Vector_MAC is
    Port ( DA : in  STD_LOGIC_VECTOR (31 downto 0); --input 1
           DB : in  STD_LOGIC_VECTOR (31 downto 0); --input 2
           valid_I_EX : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
		   ready : out STD_LOGIC; --initially is always '1', but if ALU supports multicycle ops, it will be cero when the output is not ready
           ALUctrl : in  STD_LOGIC_VECTOR (2 downto 0); -- Ops: "000" add, "001" sub, "010" AND, "011" OR, "100" MAC with internal acc, "101" MAC without previous acc.
           Dout : out  STD_LOGIC_VECTOR (31 downto 0)); -- Output
end ALU_Vector_MAC;

architecture Behavioral of ALU_Vector_MAC is

    type state_type is (IDLE, PROD, SUM);--Modificado
    signal state, next_state: state_type := IDLE;

    -- Registros intermedios para multiciclo
    signal prod0_reg, prod1_reg, prod2_reg, prod3_reg: signed(15 downto 0) := (others => '0');
    signal sum1_reg, sum2_reg: signed(16 downto 0) := (others => '0');
    signal ACC_reg: signed(31 downto 0) := (others => '0');

    signal ready_int: std_logic;
    signal mac_op, mac_ini_op, is_mac: std_logic;
    signal mac_result_comb: signed(31 downto 0); --Modificado

begin

    -- Detectar si la instrucción actual en EX es una operación MAC
    mac_op     <= '1' when (ALUctrl = "100") else '0';
    mac_ini_op <= '1' when (ALUctrl = "101") else '0';
    is_mac     <= (mac_op or mac_ini_op) and valid_I_EX;

    -- Máquina de estados 
    process(clk)--Modificado
    begin

        if rising_edge(clk) then
            if reset = '1' then--Modificado
                state <= IDLE;
                ACC_reg <= (others => '0');
            elsif valid_I_EX = '0' then
                state <= IDLE;
            else
                state <= next_state;
            end if;

            case state is
                when IDLE =>
                    if is_mac = '1' then
                        -- Ciclo 1: Multiplicar y guardar en registros
                        prod0_reg <= signed(DA(7 downto 0))   * signed(DB(7 downto 0));
                        prod1_reg <= signed(DA(15 downto 8))  * signed(DB(15 downto 8));
                        prod2_reg <= signed(DA(23 downto 16)) * signed(DB(23 downto 16));
                        prod3_reg <= signed(DA(31 downto 24)) * signed(DB(31 downto 24));
                    end if;

                when PROD =>
                    -- Ciclo 2: Sumar productos parciales en registros
                    sum1_reg <= (prod0_reg(15) & prod0_reg) + (prod1_reg(15) & prod1_reg);
                    sum2_reg <= (prod2_reg(15) & prod2_reg) + (prod3_reg(15) & prod3_reg);

                when SUM =>
                    -- Ciclo 3: Registrar resultado combinacional en ACC_reg para futuras acumulaciones
                    ACC_reg <= mac_result_comb;

                when others => null;
            end case;
        end if;
    end process;

    -- Lógica de transición de estados (Combinacional)
    process(state, is_mac)
    begin
        next_state <= state;
        case state is
            when IDLE =>
                if is_mac = '1' then next_state <= PROD; end if;
            when PROD =>
                next_state <= SUM;
            when SUM =>
                next_state <= IDLE;--Modificado
            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -- Señal READY para la Unidad de Detención (UD)
    -- Se mantiene a '0' durante los estados de cálculo (PROD, SUM)
    -- Vuelve a '1' en ACC porque el dato en ACC_reg ya es válido en este ciclo.
    ready_int <= '0' when (is_mac = '1' and (state = IDLE or state = PROD)) else '1';--Modificado
    ready <= ready_int;

    mac_result_comb <= resize((sum1_reg(16) & sum1_reg) + (sum2_reg(16) & sum2_reg), 32)
                       when mac_ini_op = '1' else
                       ACC_reg + resize((sum1_reg(16) & sum1_reg) + (sum2_reg(16) & sum2_reg), 32);

    -- Salida de la ALU
    Dout <= std_logic_vector(mac_result_comb) when (is_mac = '1' and state = SUM) else
            std_logic_vector(ACC_reg)          when (mac_op = '1' or mac_ini_op = '1') else
            DA + DB   when (ALUctrl = "000") else
            DA - DB   when (ALUctrl = "001") else
            DA AND DB when (ALUctrl = "010") else
            DA OR DB  when (ALUctrl = "011") else
            (others => '0');

end Behavioral;