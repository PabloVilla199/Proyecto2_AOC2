#!/bin/bash

set -euo pipefail

TEST_NAME="default"
VIEW_WAVEFORM="--view"
STOP_TIME="50000ns"
WAVE_FORMAT="ghw"
COMPILE_ONLY=0
CLEAN_ONLY=0
RAM_TEST="1_Scratchpad"
STOP_TIME="1601ns"
WAVE_FORMAT="ghw"
COMPILE_ONLY=0
CLEAN_ONLY=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="${PROJECT_DIR}/simulation"
TB_ENTITY="testbench"
WAVE_BASE="${SIM_DIR}/aoc2_p2_testbench"
WAVE_GHW="${WAVE_BASE}.ghw"
WAVE_VCD="${WAVE_BASE}.vcd"

show_help() {
    echo "Uso: ./ejecutar_proyecto2.sh [default|compile|clean] [opciones]"
    echo ""
    echo "Acciones disponibles:"
    echo "  default            Compila y ejecuta el testbench actual del proyecto"
    echo "  compile            Solo compila"
    echo "  clean              Limpia artefactos de GHDL y ondas"
    echo ""
    echo "Opciones:"
    echo "  --view             Abre GTKWave al final si hay onda generada (activado por defecto)"
    echo "  --stop-time=TIME   Ej: 5us, 5000ns, 50000ns"
    echo "  --vcd              Genera VCD en lugar de GHW"
    echo "  --ghw              Genera GHW (por defecto)"
    echo "  --test-ram=X       Elige la prueba a ejecutar. Opciones disponibles:"
    echo "                         1_Scratchpad"
    echo "                         2_Lecturas"
    echo "                         3_Escrituras"
    echo "                         4_CopyBack"
    echo "                         5_Errores"
    echo "  - Las ondas se guardan en simulation/, que ya esta ignorado por git."
}

normalize_test_name() {
    case "$1" in
        default|run|test|tb) echo "default" ;;
        compile|build) echo "compile" ;;
        clean) echo "clean" ;;
        *) echo "" ;;
    esac
}

ensure_tools() {
    if ! command -v ghdl >/dev/null 2>&1; then
        echo -e "${RED}âœ— No se encontro 'ghdl' en PATH${NC}"
        exit 1
    fi

    if [ "$VIEW_WAVEFORM" = "--view" ] && ! command -v gtkwave >/dev/null 2>&1; then
        echo -e "${RED}âœ— No se encontro 'gtkwave' en PATH${NC}"
        exit 1
    fi
}

clean_artifacts() {
    echo -e "${YELLOW}Limpiando artefactos de simulacion...${NC}"
    rm -f "${PROJECT_DIR}/work-obj93.cf" "${WAVE_GHW}" "${WAVE_VCD}"
    mkdir -p "$SIM_DIR"
    find "$SIM_DIR" -maxdepth 1 -type f \( -name '*.ghw' -o -name '*.vcd' \) -delete
    ghdl --clean >/dev/null 2>&1 || true
    echo -e "${GREEN}âœ“ Limpieza completada${NC}"
}

compile_project() {
    local -a vhdl_files
    local -a filtered_files
    local file

    echo -e "${YELLOW}Compilando proyecto...${NC}"
    mkdir -p "$SIM_DIR"
    cd "$PROJECT_DIR"
    ghdl --clean >/dev/null 2>&1 || true

    mapfile -t vhdl_files < <(find proyecto1 proyecto2 -type f -name '*.vhd' | sort)

    if [ "${#vhdl_files[@]}" -eq 0 ]; then
        echo -e "${RED}âœ— No se encontraron ficheros .vhd para compilar${NC}"
        exit 1
    fi

    for file in "${vhdl_files[@]}"; do
        # Filtro estricto para evitar duplicados de memoriaRAM_I
        if [[ "$file" == *"memoriaRAM_I"* ]]; then
            # Si es un archivo de RAM-I, solo lo incluimos si coincide con el test seleccionado
            if [[ "$file" == *"${RAM_TEST}"* ]]; then
                filtered_files+=("$file")
            fi
            continue
        fi
        
        # Otros filtros existentes para RAM-D
        case "$file" in
            proyecto2/ram-d/memoriaRAM_128_32_2026_bucle_lectura.vhd|\
            proyecto2/ram-d/memoriaRAM_64_32_enable.vhd)
                continue
                ;;
        esac
        filtered_files+=("$file")
    done

    ghdl -a --std=08 --ieee=synopsys -fexplicit -fsynopsys "${filtered_files[@]}"
    ghdl -m --std=08 --ieee=synopsys -fexplicit -fsynopsys "$TB_ENTITY"
    echo -e "${GREEN}âœ“ Compilacion exitosa${NC}"
}

run_simulation() {
    local wave_file

    echo -e "${YELLOW}Ejecutando simulacion...${NC}"
    echo -e "${YELLOW}Stop-time: $STOP_TIME${NC}"

    rm -f "$WAVE_GHW" "$WAVE_VCD"

    if [ "$WAVE_FORMAT" = "vcd" ]; then
        wave_file="$WAVE_VCD"
        ghdl -r --std=08 --ieee=synopsys -fexplicit -fsynopsys "$TB_ENTITY" \
            --ieee-asserts=disable --vcd="$wave_file" --stop-time="$STOP_TIME"
    else
        wave_file="$WAVE_GHW"
        ghdl -r --std=08 --ieee=synopsys -fexplicit -fsynopsys "$TB_ENTITY" \
            --ieee-asserts=disable --wave="$wave_file" --stop-time="$STOP_TIME"
    fi

    if [ -f "$wave_file" ]; then
        echo -e "${GREEN}âœ“ Simulacion completada: $wave_file${NC}"
    else
        echo -e "${RED}âœ— No se genero el fichero de onda esperado${NC}"
        exit 1
    fi
}

view_waveforms() {
    local wave_file

    if [ "$WAVE_FORMAT" = "vcd" ]; then
        wave_file="$WAVE_VCD"
    else
        wave_file="$WAVE_GHW"
    fi

    if [ -f "$wave_file" ]; then
        if [ -f "proyecto2/ondas_cache.gtkw" ]; then
            gtkwave "$wave_file" "proyecto2/ondas_cache.gtkw" >/dev/null 2>&1 &
            echo -e "${GREEN}âœ“ GTKWave abierto con: $wave_file y ondas_cache.gtkw${NC}"
        else
            gtkwave "$wave_file" >/dev/null 2>&1 &
            echo -e "${GREEN}âœ“ GTKWave abierto con: $wave_file${NC}"
        fi
    else
        echo -e "${RED}âœ— No existe el fichero de onda para visualizar${NC}"
        exit 1
    fi
}

# Variables globales para detectar si el flag se paso
RAM_TEST_PROVIDED=0

for arg in "$@"; do
    case "$arg" in
        --help)
            show_help
            exit 0
            ;;
        --view)
            VIEW_WAVEFORM="--view"
            ;;
        --stop-time=*)
            STOP_TIME="${arg#*=}"
            ;;
        --vcd)
            WAVE_FORMAT="vcd"
            ;;
        --ghw)
            WAVE_FORMAT="ghw"
            ;;
        --test-ram=*)
            RAM_TEST="${arg#*=}"
            RAM_TEST_PROVIDED=1
            ;;
        *)
            if [[ "$arg" != --* ]]; then
                TEST_NAME="$arg"
            fi
            ;;
    esac
done

TEST_NAME_NORMALIZED="$(normalize_test_name "$TEST_NAME")"

if [ -z "$TEST_NAME_NORMALIZED" ]; then
    echo -e "${RED}âœ— Opcion no valida: $TEST_NAME${NC}"
    echo ""
    show_help
    exit 1
fi

if [ "$TEST_NAME_NORMALIZED" = "compile" ]; then
    COMPILE_ONLY=1
elif [ "$TEST_NAME_NORMALIZED" = "clean" ]; then
    CLEAN_ONLY=1
fi

# Menu interactivo si no es clean y no se ha especificado RAM_TEST
if [ "$CLEAN_ONLY" -eq 0 ] && [ "$RAM_TEST_PROVIDED" -eq 0 ]; then
    echo -e "${YELLOW}==========================================${NC}"
    echo -e "${YELLOW} Elige la prueba RAM-I a ejecutar (1-5):${NC}"
    echo -e "${YELLOW}==========================================${NC}"
    echo " 1) 1_Scratchpad (Aciertos basicos)"
    echo " 2) 2_Lecturas (Fallos y aciertos)"
    echo " 3) 3_Escrituras (Write-Around / Hit)"
    echo " 4) 4_CopyBack (Reemplazo bloque sucio)"
    echo " 5) 5_Errores (Excepciones de bus)"
    echo " 6) 6_FIFO (Estres de reemplazo)"
    echo " 7) 7_Arbitraje (Conflicto de bus)"
    echo " 8) 8_Bucle (Programa bucle_lectura original)"
    read -p "Opcion [por defecto 1]: " opcion_ram
    case "$opcion_ram" in
        2) RAM_TEST="2_Lecturas" ;;
        3) RAM_TEST="3_Escrituras" ;;
        4) RAM_TEST="4_CopyBack" ;;
        5) RAM_TEST="5_Errores" ;;
        6) RAM_TEST="6_FIFO" ;;
        7) RAM_TEST="7_Arbitraje" ;;
        8) RAM_TEST="bucle_lectura" ;;
        *) RAM_TEST="1_Scratchpad" ;;
    esac
fi

ensure_tools

if [ "$CLEAN_ONLY" -eq 1 ]; then
    clean_artifacts
    exit 0
fi

echo -e "${GREEN}=== AOC2 Proyecto 2 ===${NC}"
echo -e "Modo: ${YELLOW}$TEST_NAME_NORMALIZED${NC}"
echo -e "Prueba RAM seleccionada: ${YELLOW}$RAM_TEST${NC}"

compile_project

if [ "$COMPILE_ONLY" -eq 1 ]; then
    exit 0
fi

run_simulation

if [ "$VIEW_WAVEFORM" = "--view" ]; then
    view_waveforms
fi

echo -e "${GREEN}âœ“ Flujo completado${NC}"
