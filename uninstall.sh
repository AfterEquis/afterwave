#!/usr/bin/env bash

# Script de desinstalación para Combined Audio Selector
set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${RED}Desinstalando Combined Audio Selector...${RESET}"

# 1. Detener y deshabilitar el servicio
echo "Deteniendo y deshabilitando servicio de systemd..."
systemctl --user disable --now combine-headsets.service 2>/dev/null || true

# 2. Eliminar archivos
echo "Eliminando archivos instalados..."
rm -f "$HOME/Scripts/seleccionar_audio.py"
rm -f "$HOME/Scripts/gemini/combine-headsets.sh"
rm -f "$HOME/Scripts/seleccionar_audio.sh"
rm -f "$HOME/Scripts/configurar_combinacion.sh"
rm -f "$HOME/.config/systemd/user/combine-headsets.service"

# 3. Recargar systemd
echo "Actualizando configuración de systemd..."
systemctl --user daemon-reload

echo -e "${GREEN}✔ ¡Desinstalación completada con éxito!${RESET}"
