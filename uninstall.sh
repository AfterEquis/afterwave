#!/usr/bin/env bash

# Script de desinstalación para Combined Audio Selector
set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${RED}Desinstalando Combined Audio Selector (Deteniendo servicios)...${RESET}"

# 1. Detener y deshabilitar el servicio
echo "Deteniendo y deshabilitando servicio de systemd..."
systemctl --user disable --now combine-headsets.service 2>/dev/null || true

# 2. Eliminar archivo de servicio
echo "Eliminando archivo de servicio de systemd..."
rm -f "$HOME/.config/systemd/user/combine-headsets.service"

# 3. Recargar systemd
echo "Actualizando configuración de systemd..."
systemctl --user daemon-reload

echo -e "${GREEN}✔ ¡Desinstalación completada con éxito!${RESET}"
echo "Los archivos del repositorio no han sido eliminados de esta carpeta."
