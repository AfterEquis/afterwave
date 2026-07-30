#!/usr/bin/env python3
import json
import subprocess
import sys
import os
import tty
import termios
import select

CONFIG_FILE = os.path.expanduser("~/.combined_headsets.conf")
SERVICE_NAME = "combine-headsets.service"

def run_cmd(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr

def get_audio_devices():
    # Obtener Sinks (Salidas)
    ret_sink, out_sink, _ = run_cmd(['pactl', '--format=json', 'list', 'sinks'])
    sinks = []
    if ret_sink == 0 and out_sink.strip():
        try:
            data = json.loads(out_sink)
            if isinstance(data, dict): data = [data]
            sinks = data
        except: pass

    # Obtener Sources (Entradas)
    ret_source, out_source, _ = run_cmd(['pactl', '--format=json', 'list', 'sources'])
    sources = []
    if ret_source == 0 and out_source.strip():
        try:
            data = json.loads(out_source)
            if isinstance(data, dict): data = [data]
            sources = data
        except: pass

    return sinks, sources

def filter_devices(sinks, sources):
    physical_sinks = []
    for s in sinks:
        name = s.get('name', '')
        props = s.get('properties', {})
        is_virtual = props.get('node.virtual') == 'true' or 'double_headsets' in name or 'mic_doble' in name
        if not is_virtual and not name.endswith('.monitor'):
            desc = props.get('device.description') or s.get('description') or name
            physical_sinks.append({'name': name, 'desc': desc})

    physical_sources = []
    for src in sources:
        name = src.get('name', '')
        props = src.get('properties', {})
        is_virtual = props.get('node.virtual') == 'true' or 'double_headsets' in name or 'mic_doble' in name
        if not is_virtual and not name.endswith('.monitor'):
            desc = props.get('device.description') or src.get('description') or name
            physical_sources.append({'name': name, 'desc': desc})

    return physical_sinks, physical_sources

def read_current_config():
    import re
    selected_sinks = set()
    selected_sources = set()
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                content = f.read()
            sinks_match = re.search(r'COMBINED_SINKS=\(\s*(.*?)\s*\)', content, re.DOTALL)
            if sinks_match:
                selected_sinks = set(re.findall(r'"([^"]*)"', sinks_match.group(1)))
            sources_match = re.search(r'COMBINED_SOURCES=\(\s*(.*?)\s*\)', content, re.DOTALL)
            if sources_match:
                selected_sources = set(re.findall(r'"([^"]*)"', sources_match.group(1)))
        except: pass
    return selected_sinks, selected_sources

def get_key(timeout=0.1):
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        # Esperar hasta 'timeout' segundos a ver si hay datos en stdin
        r, _, _ = select.select([sys.stdin], [], [], timeout)
        if r:
            # Usar os.read para evitar el buffering interno de Python
            b = os.read(fd, 1)
            if b == b'\x1b':
                # Esperar hasta 50ms por la secuencia de la flecha
                r2, _, _ = select.select([sys.stdin], [], [], 0.05)
                if r2:
                    seq = os.read(fd, 2)
                    if seq in (b'[A', b'OA'): return 'up'
                    elif seq in (b'[B', b'OB'): return 'down'
                    elif seq in (b'[C', b'OC'): return 'right'
                    elif seq in (b'[D', b'OD'): return 'left'
                return 'esc'
            elif b == b' ': return 'space'
            elif b in (b'\r', b'\n'): return 'enter'
            elif b in (b'q', b'Q'): return 'quit'
            # ctrl-c
            elif b == b'\x03': return 'quit'
            return b.decode('utf-8', errors='ignore')
        return None
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def get_equalizer_frame(step):
    import math
    chars = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    
    # 3 barras a cada lado animadas por ondas sinusoidales
    l1 = chars[int((math.sin(step * 0.4) + 1.0) * 3.5)]
    l2 = chars[int((math.sin(step * 0.6 + 1.2) + 1.0) * 3.5)]
    l3 = chars[int((math.sin(step * 0.8 + 2.4) + 1.0) * 3.5)]
    
    r1 = chars[int((math.sin(step * 0.8 + 2.4) + 1.0) * 3.5)]
    r2 = chars[int((math.sin(step * 0.6 + 1.2) + 1.0) * 3.5)]
    r3 = chars[int((math.sin(step * 0.4) + 1.0) * 3.5)]
    
    return f"{l1}{l2}{l3}", f"{r3}{r2}{r1}"

def render(items, current_idx, selected_sinks, selected_sources, step, eq_frame):
    # Colores ANSI locales
    CYAN = "\033[1;36m"
    GREEN = "\033[1;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[1;34m"
    MAGENTA = "\033[1;35m"
    RED = "\033[1;31m"
    DIM = "\033[90m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

    border_colors = [CYAN, BLUE, MAGENTA, RED, YELLOW, GREEN]
    # Cambiar de color cada 2 frames (200ms) para un efecto suave
    b_color = border_colors[(step // 2) % len(border_colors)]

    # Mover al origen (0,0) sin borrar pantalla completa (cero parpadeo)
    sys.stdout.write("\033[H")
    
    eq_left, eq_right = eq_frame
    
    # Generar línea divisoria animada (flujo de luz deslizante)
    div_pattern = "──┈┈──┈┈"
    div_shift = step % len(div_pattern)
    div_line = (div_pattern * 10)[div_shift:div_shift+40]
    animated_divider = f"  {DIM}{div_line}{RESET}"
    
    # end="\033[K\n" limpia la línea de residuos anteriores sin parpadear
    print(f"  {b_color}┌────────────────────────────────────────┐{RESET}", end="\033[K\n")
    print(f"  {b_color}│ {RESET}{CYAN}{eq_left}{RESET}           {BOLD}AfterWave{RESET}            {CYAN}{eq_right}{RESET} {b_color}│{RESET}", end="\033[K\n")
    print(f"  {b_color}└────────────────────────────────────────┘{RESET}", end="\033[K\n")
    print("", end="\033[K\n")

    has_printed_sink_header = False
    has_printed_source_header = False

    for idx, item in enumerate(items):
        if item['type'] == 'divider':
            continue

        if item['type'] == 'sink' and not has_printed_sink_header:
            print(f"  {BOLD}🔊 DISPOSITIVOS DE ESCUCHA (SALIDA){RESET}", end="\033[K\n")
            print(animated_divider, end="\033[K\n")
            has_printed_sink_header = True

        elif item['type'] == 'source' and not has_printed_source_header:
            print("", end="\033[K\n")
            print(f"  {BOLD}🎙️ DISPOSITIVOS DE HABLA (ENTRADA){RESET}", end="\033[K\n")
            print(animated_divider, end="\033[K\n")
            has_printed_source_header = True

        # Determinar si está seleccionado
        is_selected = False
        if item['type'] == 'sink':
            is_selected = item['name'] in selected_sinks
        elif item['type'] == 'source':
            is_selected = item['name'] in selected_sources

        # Casilla de verificación
        chk = f"{GREEN}[X]{RESET}" if is_selected else f"{DIM}[ ]{RESET}"
        
        # Dibujar cursor e item
        if idx == current_idx:
            # El cursor respira lateralmente: " ➜" o "➜ " para dar sensación de pulso
            cursor_frames = [f" {CYAN}➜{RESET}", f"{CYAN}➜{RESET} "]
            indicator = cursor_frames[step % len(cursor_frames)]
            print(f"  {indicator} {chk} {BOLD}{CYAN}{item['desc']}{RESET}", end="\033[K\n")
        else:
            print(f"     {chk} {item['desc']}", end="\033[K\n")

    print("", end="\033[K\n")
    print(animated_divider, end="\033[K\n")
    print(f"  {BOLD}Controles:{RESET}", end="\033[K\n")
    print(f"    {CYAN}▲/▼{RESET} Moverse  |  {CYAN}Espacio{RESET} Seleccionar  |  {GREEN}Enter{RESET} Aplicar  |  {RED}Q/Esc{RESET} Salir", end="\033[K\n")
    print(animated_divider, end="\033[K\n")
    sys.stdout.flush()

def main():
    # Colores locales para mensajes de finalización
    GREEN = "\033[1;32m"
    BLUE = "\033[1;34m"
    RED = "\033[1;31m"
    YELLOW = "\033[1;33m"
    RESET = "\033[0m"

    # Ocultar cursor del terminal para la interfaz
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()

    try:
        sinks, sources = get_audio_devices()
        physical_sinks, physical_sources = filter_devices(sinks, sources)

        if not physical_sinks and not physical_sources:
            print(f"{RED}No se encontraron dispositivos de audio físicos conectados.{RESET}")
            return

        # Leer selección actual para marcar por defecto
        selected_sinks, selected_sources = read_current_config()

        # Construir lista plana de elementos para la interfaz
        items = []
        for s in physical_sinks:
            items.append({
                'type': 'sink',
                'name': s['name'],
                'desc': s['desc']
            })
        if physical_sinks and physical_sources:
            items.append({
                'type': 'divider'
            })
        for src in physical_sources:
            items.append({
                'type': 'source',
                'name': src['name'],
                'desc': src['desc']
            })

        current_idx = 0
        if items and items[current_idx]['type'] == 'divider':
            current_idx = 1

        # Limpiar pantalla una sola vez al inicio
        sys.stdout.write("\033[H\033[2J")
        sys.stdout.flush()

        step = 0
        # Loop de navegación interactiva
        while True:
            eq_left, eq_right = get_equalizer_frame(step)
            render(items, current_idx, selected_sinks, selected_sources, step, (eq_left, eq_right))
            
            # Non-blocking key read con 100ms de timeout para animar el ecualizador y colores
            key = get_key(0.1)

            if key is None:
                step += 1
                continue

            if key == 'quit' or key == 'esc':
                sys.stdout.write("\033[H\033[2J")
                print(f"{YELLOW}Selección cancelada. No se han aplicado cambios.{RESET}")
                break

            elif key == 'up':
                current_idx = (current_idx - 1) % len(items)
                if items[current_idx]['type'] == 'divider':
                    current_idx = (current_idx - 1) % len(items)

            elif key == 'down':
                current_idx = (current_idx + 1) % len(items)
                if items[current_idx]['type'] == 'divider':
                    current_idx = (current_idx + 1) % len(items)

            elif key == 'space':
                item = items[current_idx]
                if item['type'] == 'sink':
                    if item['name'] in selected_sinks:
                        selected_sinks.remove(item['name'])
                    else:
                        selected_sinks.add(item['name'])
                elif item['type'] == 'source':
                    if item['name'] in selected_sources:
                        selected_sources.remove(item['name'])
                    else:
                        selected_sources.add(item['name'])

            elif key == 'enter':
                sys.stdout.write("\033[H\033[2J")
                print(f"{BLUE}Aplicando configuración...{RESET}")
                
                # Escribir archivo de configuración
                config_content = "# Archivo generado automáticamente por seleccionar_audio.py\n"
                config_content += "COMBINED_SINKS=(\n"
                for s in selected_sinks:
                    config_content += f"  \"{s}\"\n"
                config_content += ")\n\n"
                
                config_content += "COMBINED_SOURCES=(\n"
                for src in selected_sources:
                    config_content += f"  \"{src}\"\n"
                config_content += ")\n"

                try:
                    with open(CONFIG_FILE, 'w') as f:
                        f.write(config_content)
                except Exception as e:
                    print(f"{RED}Error al escribir configuración: {e}{RESET}")
                    sys.exit(1)

                # Si no hay nada seleccionado, apagamos el servicio
                if not selected_sinks and not selected_sources:
                    print(f"{YELLOW}No hay dispositivos seleccionados. Deteniendo servicio combinado...{RESET}")
                    run_cmd(['systemctl', '--user', 'stop', SERVICE_NAME])
                    print(f"{GREEN}✔ Combinación desactivada.{RESET}")
                else:
                    print(f"{BLUE}Reiniciando servicio de audio combinado...{RESET}")
                    ret, _, err = run_cmd(['systemctl', '--user', 'restart', SERVICE_NAME])
                    if ret == 0:
                        print(f"{GREEN}✔ ¡Combinación de dispositivos de audio aplicada con éxito!{RESET}")
                    else:
                        print(f"{RED}Error al iniciar el servicio: {err}{RESET}")
                break
            
            # Incrementar el paso de animación con cada tecla pulsada también
            step += 1
    finally:
        # Asegurarse de volver a mostrar el cursor al salir
        sys.stdout.write("\033[?25h")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
