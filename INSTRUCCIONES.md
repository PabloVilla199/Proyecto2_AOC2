# Guía de Ejecución y Análisis - Proyecto 2 AOC2

Este directorio ha sido organizado para facilitar la validación de la jerarquía de memoria (Caché 2-way Copy-Back).

## Estructura de Carpetas
- `scripts/`: Herramientas de extracción y visualización.
- `docs/`: Documentación detallada de la arquitectura y casos de uso.
- `outputs/`: Resultados de las simulaciones previas (logs y gráficas).
- `proyecto1/` y `proyecto2/`: Código fuente VHDL.

## Cómo ejecutar una nueva prueba
1. Ejecuta el script principal de simulación:
   ```bash
   wsl ./ejecutar_proyecto2.sh --vcd
   ```
   *Elige el test que desees (1-5).*

2. Extrae las señales importantes a un archivo de texto:
   ```powershell
   python scripts/extract_signals.py > outputs/nuevo_analisis.txt
   ```

3. (Opcional) Genera la galería de capturas en HTML:
   ```powershell
   python scripts/generate_gallery.py
   ```
   *El archivo se generará como `outputs/reporte_grafico_caps.html` (asegúrate de moverlo si lo generas de nuevo).*

## Archivos de Salida Clave
- `outputs/signals_output_test4.txt`: Análisis detallado del Copy-Back.
- `outputs/reporte_grafico_caps.html`: Visualización profesional de los hitos del proyecto.
