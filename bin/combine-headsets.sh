#!/usr/bin/env bash

# Archivos de configuración
MOD_FILE="$HOME/.combined_headsets.mods"
DEFAULTS_FILE="$HOME/.combined_headsets.defaults"
CONFIG_FILE="$HOME/.combined_headsets.conf"

# Nombres y descripciones amigables para los dispositivos combinados virtuales
COMBINED_SINK_NAME="double_headsets_playback"
COMBINED_SINK_DESC="Escuchar-por-Ambos-Cascos"

COMBINED_BUS_NAME="double_headsets_mic_bus"
COMBINED_BUS_DESC="Bus-Oculto-Micros"

COMBINED_SOURCE_NAME="double_headsets_mic_source"
COMBINED_SOURCE_NAME_DESC="Hablar-por-Ambos-Cascos"

function stop_combining() {
    echo "=== Desactivando combinación ==="
    
    # Restaurar dispositivos por defecto originales y mover las transmisiones activas
    if [ -f "$DEFAULTS_FILE" ]; then
        read -r PREV_SINK PREV_SOURCE < "$DEFAULTS_FILE"
        echo "Restaurando salida por defecto original: $PREV_SINK"
        pactl set-default-sink "$PREV_SINK" 2>/dev/null
        echo "Restaurando entrada por defecto original: $PREV_SOURCE"
        pactl set-default-source "$PREV_SOURCE" 2>/dev/null
        
        # Mover transmisiones activas de vuelta a la salida original
        echo "Restaurando transmisiones de audio a la salida original..."
        python3 -c "
import json, subprocess
proc = subprocess.run(['pactl', '--format=json', 'list', 'sink-inputs'], capture_output=True, text=True)
if proc.returncode == 0 and proc.stdout.strip():
    try:
        inputs = json.loads(proc.stdout)
        if isinstance(inputs, dict): inputs = [inputs]
        for inp in inputs:
            properties = inp.get('properties', {})
            is_virtual = properties.get('node.virtual') == 'true'
            media_name = properties.get('media.name', '')
            if is_virtual or 'double_headsets' in media_name or 'combined_headsets' in media_name or 'loopback' in media_name or 'Combine stream' in media_name:
                continue
            index = inp.get('index')
            if index is not None:
                subprocess.run(['pactl', 'move-sink-input', str(index), '$PREV_SINK'])
    except: pass
" 2>/dev/null

        rm "$DEFAULTS_FILE"
    fi

    if [ -f "$MOD_FILE" ]; then
        # Leer todos los IDs de módulos guardados
        read -r -a ALL_MODS < "$MOD_FILE"
        # Descargarlos en orden inverso
        for ((i=${#ALL_MODS[@]}-1; i>=0; i--)); do
            local mod_id="${ALL_MODS[i]}"
            if [ -n "$mod_id" ]; then
                echo "Descargando módulo ID: $mod_id..."
                pactl unload-module "$mod_id" 2>/dev/null
            fi
        done
        rm "$MOD_FILE"
        echo " -> Combinación desactivada con éxito."
    else
        echo "No se encontró ningún registro de módulos activos en '$MOD_FILE'."
        # Limpieza genérica por seguridad
        pactl unload-module module-combine-sink 2>/dev/null
        pactl unload-module module-remap-source 2>/dev/null
        pactl unload-module module-null-sink 2>/dev/null
        pactl unload-module module-loopback 2>/dev/null
    fi
}

function start_combining() {
    if [ -f "$MOD_FILE" ]; then
        echo "Ya existe una combinación activa o un archivo de registro residual."
        stop_combining
        echo ""
    fi

    # Cargar configuración desde el archivo conf
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No existe el archivo de configuración en $CONFIG_FILE."
        echo "Ejecuta el script de selección para configurarlo primero."
        exit 1
    fi

    source "$CONFIG_FILE"

    # Verificar que haya dispositivos seleccionados
    if [ ${#COMBINED_SINKS[@]} -eq 0 ] && [ ${#COMBINED_SOURCES[@]} -eq 0 ]; then
        echo "Error: No se seleccionó ningún dispositivo para combinar."
        exit 1
    fi

    # Guardar dispositivos por defecto actuales antes de cambiarlos
    CURRENT_DEFAULT_SINK=$(pactl info | grep "Default Sink" | awk '{print $3}')
    CURRENT_DEFAULT_SOURCE=$(pactl info | grep "Default Source" | awk '{print $3}')
    
    if [ "$CURRENT_DEFAULT_SINK" != "$COMBINED_SINK_NAME" ] && [ "$CURRENT_DEFAULT_SINK" != "$COMBINED_BUS_NAME" ]; then
        echo "$CURRENT_DEFAULT_SINK $CURRENT_DEFAULT_SOURCE" > "$DEFAULTS_FILE"
    fi

    echo "=== Iniciando combinación de dispositivos ==="
    local MODULES_TO_SAVE=()

    # 1. Configurar Salidas Combinadas (Sinks)
    local SINK_MOD=""
    if [ ${#COMBINED_SINKS[@]} -gt 0 ]; then
        echo "1. Creando dispositivo de escucha combinado..."
        SINK_MOD=$(pactl load-module module-null-sink \
            sink_name="$COMBINED_SINK_NAME" \
            sink_properties="device.description=$COMBINED_SINK_DESC node.virtual=false")
        
        if [ $? -eq 0 ] && [ -n "$SINK_MOD" ]; then
            echo "   [✓] Dispositivo de escucha listo (ID: $SINK_MOD)"
            MODULES_TO_SAVE+=("$SINK_MOD")
        else
            echo "   [✗] ERROR: No se pudo crear la salida combinada."
            exit 1
        fi

        # Conectar loopbacks a cada una de las salidas físicas seleccionadas
        for s in "${COMBINED_SINKS[@]}"; do
            echo "   Conectando salida virtual a salida física: $s..."
            local lp_mod=$(pactl load-module module-loopback \
                source="${COMBINED_SINK_NAME}.monitor" \
                sink="$s" \
                latency_msec=1)
            
            if [ $? -eq 0 ] && [ -n "$lp_mod" ]; then
                echo "   [✓] Conexión lista (ID: $lp_mod)"
                MODULES_TO_SAVE+=("$lp_mod")
            else
                echo "   [✗] ERROR: No se pudo conectar a la salida: $s."
                # Limpiar los cargados hasta el momento
                for m in "${MODULES_TO_SAVE[@]}"; do pactl unload-module "$m" 2>/dev/null; done
                exit 1
            fi
        done
    fi

    # 2. Configurar Entradas Combinadas (Sources)
    local BUS_MOD=""
    local REMAP_MOD=""
    if [ ${#COMBINED_SOURCES[@]} -gt 0 ]; then
        echo "2. Creando bus de mezcla oculto para micrófonos..."
        BUS_MOD=$(pactl load-module module-null-sink \
            sink_name="$COMBINED_BUS_NAME" \
            sink_properties="device.description=$COMBINED_BUS_DESC node.virtual=true")
        
        if [ $? -eq 0 ] && [ -n "$BUS_MOD" ]; then
            echo "   [✓] Bus de mezcla listo (ID: $BUS_MOD)"
            MODULES_TO_SAVE+=("$BUS_MOD")
        else
            echo "   [✗] ERROR: No se pudo crear el bus de mezcla."
            for m in "${MODULES_TO_SAVE[@]}"; do pactl unload-module "$m" 2>/dev/null; done
            exit 1
        fi

        echo "3. Creando micrófono virtual remapeado..."
        REMAP_MOD=$(pactl load-module module-remap-source \
            master="${COMBINED_BUS_NAME}.monitor" \
            source_name="$COMBINED_SOURCE_NAME" \
            source_properties="device.description=$COMBINED_SOURCE_NAME_DESC node.virtual=false")

        if [ $? -eq 0 ] && [ -n "$REMAP_MOD" ]; then
            echo "   [✓] Micrófono virtual listo (ID: $REMAP_MOD)"
            MODULES_TO_SAVE+=("$REMAP_MOD")
        else
            echo "   [✗] ERROR: No se pudo crear el micrófono virtual."
            for m in "${MODULES_TO_SAVE[@]}"; do pactl unload-module "$m" 2>/dev/null; done
            exit 1
        fi

        # Conectar loopbacks desde cada micrófono físico seleccionado al bus
        for src in "${COMBINED_SOURCES[@]}"; do
            echo "   Conectando micrófono físico al bus: $src..."
            local lp_mod=$(pactl load-module module-loopback \
                source="$src" \
                sink="$COMBINED_BUS_NAME" \
                latency_msec=1)
            
            if [ $? -eq 0 ] && [ -n "$lp_mod" ]; then
                echo "   [✓] Conexión de micrófono lista (ID: $lp_mod)"
                MODULES_TO_SAVE+=("$lp_mod")
            else
                echo "   [✗] ERROR: No se pudo conectar el micrófono: $src."
                for m in "${MODULES_TO_SAVE[@]}"; do pactl unload-module "$m" 2>/dev/null; done
                exit 1
            fi
        done
    fi

    # Guardar todos los módulos cargados
    echo "${MODULES_TO_SAVE[*]}" > "$MOD_FILE"

    # Establecer predeterminados
    if [ -n "$SINK_MOD" ]; then
        echo "Estableciendo salida combinada como predeterminada..."
        pactl set-default-sink "$COMBINED_SINK_NAME"
    fi
    if [ -n "$REMAP_MOD" ]; then
        echo "Estableciendo entrada combinada como predeterminada..."
        pactl set-default-source "$COMBINED_SOURCE_NAME"
    fi

    # Esperar y redirigir
    sleep 1.5
    if [ -n "$SINK_MOD" ]; then
        echo "Redirigiendo transmisiones de audio activas a la salida combinada..."
        python3 -c "
import json, subprocess
proc = subprocess.run(['pactl', '--format=json', 'list', 'sink-inputs'], capture_output=True, text=True)
if proc.returncode == 0 and proc.stdout.strip():
    try:
        inputs = json.loads(proc.stdout)
        if isinstance(inputs, dict): inputs = [inputs]
        for inp in inputs:
            properties = inp.get('properties', {})
            is_virtual = properties.get('node.virtual') == 'true'
            media_name = properties.get('media.name', '')
            if is_virtual or 'double_headsets' in media_name or 'combined_headsets' in media_name or 'loopback' in media_name or 'Combine stream' in media_name:
                continue
            index = inp.get('index')
            if index is not None:
                subprocess.run(['pactl', 'move-sink-input', str(index), '$COMBINED_SINK_NAME'])
    except: pass
" 2>/dev/null
    fi

    echo "========================================================================="
    echo " ¡COMBINACIÓN DE CASCOS COMPLETADA!"
    echo "========================================================================="
}

case "$1" in
    start)
        start_combining
        ;;
    stop)
        stop_combining
        ;;
    *)
        echo "Uso: $0 {start|stop}"
        exit 1
        ;;
esac
