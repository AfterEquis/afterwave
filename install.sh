#!/usr/bin/env bash

# Script de instalación para AfterWave
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Obtener la ruta absoluta del repositorio clonado
INSTALL_DIR=$(cd "$(dirname "$0")" && pwd)

echo -e "${BLUE}Instalando y configurando servicio para AfterWave...${RESET}"
echo "Ruta de instalación detectada: $INSTALL_DIR"

# 1. Asegurar permisos de ejecución en la carpeta bin
chmod +x "$INSTALL_DIR/bin/seleccionar_audio.py"
chmod +x "$INSTALL_DIR/bin/combine-headsets.sh"

# 2. Crear directorio de systemd de usuario si no existe
mkdir -p "$HOME/.config/systemd/user"

# 3. Crear el archivo del servicio dinámico apuntando a esta carpeta
echo "Generando servicio systemd..."
cat << EOF > "$HOME/.config/systemd/user/combine-headsets.service"
[Unit]
Description=AfterWave Audio Service (Simultaneous Output & Input)
After=pipewire-pulse.service wireplumber.service
Requires=pipewire-pulse.service wireplumber.service

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/bin/combine-headsets.sh start
ExecStop=$INSTALL_DIR/bin/combine-headsets.sh stop
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF

# 4. Habilitar servicio en systemd
echo "Habilitando servicio en systemd (usuario)..."
systemctl --user daemon-reload
systemctl --user enable combine-headsets.service

echo -e "${GREEN}✔ ¡Instalación completada con éxito!${RESET}"
echo -e "Puedes iniciar el menú directamente desde esta carpeta con: ${BLUE}./bin/seleccionar_audio.py${RESET}"
