#!/usr/bin/env bash
# Ejecuta `ejecutar_proyecto2.sh` para una lista de pruebas RAM-I y guarda
# la salida (stdout+stderr) en archivos en logs/. Genera un resumen en
# logs/summary.txt con código de salida y tiempo.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/ejecutar_proyecto2.sh"
LOG_DIR="$ROOT_DIR/logs"
STOP_TIME="2000ns"

mkdir -p "$LOG_DIR"

tests=(
  "1_Scratchpad"
  "2_Lecturas"
  "3_Escrituras"
  "4_CopyBack"
  "5_Errores"
  "6_FIFO"
  "7_Arbitraje"
  "bucle_lectura"
  "WriteMissDirty"
  "HitVia1"
)

summary_file="$LOG_DIR/summary.txt"
echo "Run started: $(date -u)" > "$summary_file"
echo "Stop time: $STOP_TIME" >> "$summary_file"
echo "" >> "$summary_file"

for t in "${tests[@]}"; do
  log="$LOG_DIR/test_${t}.txt"
  echo "--- Running test: $t ---"
  echo "Test: $t" >> "$summary_file"
  start_ts=$(date +%s)

  # Ejecutar el script y capturar salida
  if bash "$SCRIPT" default --test-ram="$t" --vcd --stop-time="$STOP_TIME" > "$log" 2>&1; then
    rc=0
    status="OK"
  else
    rc=$?
    status="ERROR"
  fi

  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))

  echo "  status: $status (rc=$rc)" >> "$summary_file"
  echo "  log: $log" >> "$summary_file"
  echo "  elapsed_seconds: $elapsed" >> "$summary_file"
  echo "" >> "$summary_file"

  echo " -> $t: $status (rc=$rc, log=$log)"
done

echo "Run finished: $(date -u)" >> "$summary_file"
echo "Summary written to: $summary_file"

exit 0
