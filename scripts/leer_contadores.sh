#!/bin/bash
# Script para extraer contadores de rendimiento directamente del VCD
cd "$(dirname "$0")/.."
VCD="simulation/aoc2_p2_testbench.vcd"

# Función para encontrar el símbolo de una señal en el VCD
get_sym() {
  local scope="$1"
  # Busca el símbolo de la señal 'count' dentro del scope indicado (ignora mayusculas en scope)
  sed -n "/scope module ${scope,,}/,/upscope/p" "$VCD" | grep -w "count" | head -1 | awk '{print $4}'
}

# Ultimo valor binario del simbolo dado
last_val() {
  local sym="$1"
  [ -z "$sym" ] && echo "?" && return
  grep -F " ${sym}" "$VCD" | grep '^b' | tail -1 | awk '{print $1}' | sed 's/^b//'
}

b2d() {
  local b="$1"
  [ -z "$b" ] || [ "$b" == "?" ] && echo "0" && return
  echo "$((2#${b}))" 2>/dev/null || echo "0"
}

run_test() {
  local NAME="$1" STOP="$2"
  bash ejecutar_proyecto2.sh default --test-ram="$NAME" --vcd --stop-time="$STOP" > /dev/null 2>&1
  
  if [ ! -f "$VCD" ]; then printf '%-16s  ERROR: No VCD\n' "$NAME"; return; fi

  local SYM_M=$(get_sym "cont_m")
  local SYM_R=$(get_sym "cont_r")
  local SYM_W=$(get_sym "cont_w")
  local SYM_CB=$(get_sym "cont_cb")
  local SYM_IO=$(get_sym "cont_io")

  printf '%-20s  cont_m=%-2s  cont_r=%-2s  cont_w=%-2s  cont_cb=%-2s  cont_IO=%-2s\n' \
    "$NAME" "$(b2d $(last_val $SYM_M))" "$(b2d $(last_val $SYM_R))" "$(b2d $(last_val $SYM_W))" "$(b2d $(last_val $SYM_CB))" "$(b2d $(last_val $SYM_IO))"
}

echo ''
echo '========================================================================'
echo '  AOC2 P2 - VERIFICACIÓN DE CONTADORES (Simulación Real)'
echo '========================================================================'
echo 'Test                  cont_m   cont_r   cont_w   cont_cb  cont_IO'
echo '------------------------------------------------------------------------'
run_test 1_Scratchpad      1500ns
run_test 2_Lecturas        2000ns
run_test 3_Escrituras      2000ns
run_test 4_CopyBack        3000ns
run_test 5_Errores         2500ns
run_test 6_FIFO            3000ns
run_test 7_Arbitraje       1000ns
run_test 8_WriteMissDirty  2500ns
run_test 9_HitVia1         2500ns
echo '------------------------------------------------------------------------'
echo 'Validación completada.'
echo '========================================================================'
