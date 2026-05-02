import os
import subprocess
import sys
import time

# Arreglo para que los emojis y caracteres especiales no fallen en Windows
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# --- Terminal Colors ---
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_header():
    os.system('cls' if os.name == 'nt' else 'clear')
    print(f"{Colors.BOLD}{Colors.OKCYAN}")
    print("  ╔══════════════════════════════════════════════════════════════╗")
    print("  ║           AOC2 PROYECTO 2 - TEST RUNNER                      ║")
    print("  ║        (Verificación de Arquitectura de Caché)               ║")
    print("  ╚══════════════════════════════════════════════════════════════╝")
    print(f"{Colors.ENDC}")

def get_available_tests():
    ram_dir = "proyecto2/ram-i"
    files = [f for f in os.listdir(ram_dir) if "test" in f.lower() and f.endswith(".vhd")]
    tests = []
    for f in files:
        name = f.replace("memoriaRAM_I_", "").replace(".vhd", "").replace("Test_", "")
        tests.append((f, name))
    
    return sorted(tests, key=lambda x: x[1])

def run_test(file_name, display_name, silent=False):
    if not silent:
        print(f"\n{Colors.BOLD}{Colors.OKBLUE} [TEST] Ejecutando: {display_name}{Colors.ENDC}")
        print("-" * 60)
    
    ram_arg = file_name.replace("memoriaRAM_I_", "").replace(".vhd", "")
    stop_time = "800ns" if "arbitraje" in display_name.lower() else "2000ns"
    
    # En CI (Linux), usamos bash directamente. En Windows, usamos WSL.
    cmd_base = "bash"
    if sys.platform == 'win32':
        cmd_base = "wsl -d Ubuntu bash"
        
    shell_cmd = f"{cmd_base} ejecutar_proyecto2.sh default --test-ram={ram_arg} --vcd --stop-time={stop_time}"

    try:
        if not silent: print(f"{Colors.OKCYAN} -> Simulando...{Colors.ENDC}")
        result = subprocess.run(shell_cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            if not silent:
                print(f"{Colors.FAIL}[ERROR] Fallo en simulación.{Colors.ENDC}")
                print(result.stderr)
            return "ERROR"
        
        # Validación
        verify_name = display_name
        if "bucle" in display_name.lower(): verify_name = "8_Bucle"

        if not silent: print(f"{Colors.OKCYAN} -> Verificando espectativas...{Colors.ENDC}")
        verify_cmd = [sys.executable, "scripts/verify_cache.py", "--test", verify_name]
        v_result = subprocess.run(verify_cmd, capture_output=silent, text=True)
        
        return "PASSED" if v_result.returncode == 0 else "FAILED"
        
    except Exception as e:
        if not silent: print(f"{Colors.FAIL} [!] Error: {str(e)}{Colors.ENDC}")
        return "ERROR"

def run_all(tests):
    results = []
    print(f"\n{Colors.BOLD}{Colors.OKCYAN}Iniciando Batería de Pruebas Completa...{Colors.ENDC}")
    print("=" * 60)
    
    for fname, dname in tests:
        print(f" -> {dname:25s} ... ", end="", flush=True)
        status = run_test(fname, dname, silent=True)
        
        if status == "PASSED":
            print(f"{Colors.OKGREEN}[OK]{Colors.ENDC}")
        elif status == "FAILED":
            print(f"{Colors.FAIL}[FAIL]{Colors.ENDC}")
        else:
            print(f"{Colors.WARNING}[ERROR]{Colors.ENDC}")
            
        results.append((dname, status))
    
    print("\n" + "=" * 60)
    print(f"{Colors.BOLD} RESUMEN FINAL:{Colors.ENDC}")
    print("-" * 40)
    total_passed = 0
    for name, status in results:
        color = Colors.OKGREEN if status == "PASSED" else Colors.FAIL
        print(f"  - {name:25s}: {color}{status}{Colors.ENDC}")
        if status == "PASSED": total_passed += 1
    
    print("-" * 40)
    final_color = Colors.OKGREEN if total_passed == len(tests) else Colors.WARNING
    print(f" TOTAL: {final_color}{total_passed}/{len(tests)} superados{Colors.ENDC}")
    print("=" * 60)
    
    return total_passed == len(tests)

def main():
    tests = get_available_tests()
    
    if "--all" in sys.argv:
        print(f"{Colors.BOLD}{Colors.OKBLUE}Modo CI Detectado. Ejecutando todo...{Colors.ENDC}")
        success = run_all(tests)
        sys.exit(0 if success else 1)

    while True:
        print_header()
        tests = get_available_tests()
        
        print(f"{Colors.BOLD}Seleccione una opción:{Colors.ENDC}")
        print(f"  {Colors.OKCYAN}a){Colors.ENDC} EJECUTAR TODOS LOS TESTS")
        print("-" * 30)
        
        for i, (fname, dname) in enumerate(tests):
            print(f"  {Colors.OKBLUE}{i+1:2d}){Colors.ENDC} {dname}")
        
        print(f"  {Colors.WARNING} q){Colors.ENDC} Salir")
        
        choice = input(f"\n{Colors.BOLD}Opción > {Colors.ENDC}").strip().lower()
        
        if choice == 'q':
            print(f"\n{Colors.OKGREEN}Saliendo...{Colors.ENDC}")
            break
        elif choice == 'a':
            run_all(tests)
            input(f"\n{Colors.BOLD}Presione ENTER para continuar...{Colors.ENDC}")
        else:
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(tests):
                    fname, dname = tests[idx]
                    status = run_test(fname, dname)
                    print(f"\n{Colors.BOLD}Resultado Final: {Colors.OKGREEN if status == 'PASSED' else Colors.FAIL}{status}{Colors.ENDC}")
                    input(f"\n{Colors.BOLD}Presione ENTER para continuar...{Colors.ENDC}")
                else:
                    print(f"{Colors.FAIL}Opción fuera de rango.{Colors.ENDC}")
                    time.sleep(1)
            except ValueError:
                print(f"{Colors.FAIL}Opción no válida.{Colors.ENDC}")
                time.sleep(1)

if __name__ == "__main__":
    main()
