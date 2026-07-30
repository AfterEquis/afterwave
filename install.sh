#!/usr/bin/env bash

# Script de instalación para Combined Audio Selector
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
RESET="\033[0m"

echo -e "${BLUE}Instalando Combined Audio Selector...${RESET}"

# 1. Crear directorios necesarios
mkdir -p "$HOME/Scripts/gemini"
mkdir -p "$HOME/.config/systemd/user"

# 2. Copiar archivos del proyecto
echo "Copiando archivos..."
cp bin/seleccionar_audio.py "$HOME/Scripts/seleccionar_audio.py"
cp bin/combine-headsets.sh "$HOME/Scripts/gemini/combine-headsets.sh"
cp systemd/combine-headsets.service "$HOME/.config/systemd/user/combine-headsets.service"

# 3. Crear el script de ejecución seleccionar_audio.sh
cat << 'EOF' > "$HOME/Scripts/seleccionar_audio.sh"
#!/usr/bin/env bash
python3 "$HOME/Scripts/seleccionar_audio.py"
EOF

# 4. Enlazar configurar_combinacion.sh
cat << 'EOF' > "$HOME/Scripts/configurar_combinacion.sh"
#!/usr/bin/env bash
python3 "$HOME/Scripts/seleccionar_audio.py"
EOF

# 5. Hacer ejecutables los archivos
echo "Ajustando permisos de ejecución..."
chmod +x "$HOME/Scripts/seleccionar_audio.py"
chmod +x "$HOME/Scripts/gemini/combine-headsets.sh"
chmod +x "$HOME/Scripts/seleccionar_audio.sh"
chmod +x "$HOME/Scripts/configurar_combinacion.sh"

# 6. Recargar y habilitar el servicio de systemd
echo "Habilitando servicio en systemd (usuario)..."
systemctl --user daemon-reload
systemctl --user enable combine-headsets.service

echo -e "${GREEN}✔ ¡Instalación completada con éxito!${RESET}"
echo -e "Puedes ejecutar el menú con el comando: ${BLUE}~/Scripts/seleccionar_audio.sh${RESET}"
