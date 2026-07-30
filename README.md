# AfterWave 🔊🎙️

Un gestor interactivo y visual para combinar múltiples auriculares y micrófonos físicos en Linux usando **PipeWire** (o PulseAudio) y **systemd**.

Este proyecto te permite seleccionar qué dispositivos de salida (auriculares) y qué dispositivos de entrada (micrófonos) quieres usar al mismo tiempo, combinándolos de manera transparente en un único dispositivo virtual de escucha y de habla en tu sistema.

---

## ✨ Características

- 🔍 **Detección dinámica:** Escanea automáticamente todas las entradas y salidas de audio físicas conectadas (sin configuraciones estáticas).
- 🖥️ **Interfaz interactiva en Terminal:**
  - **Ecualizador Dinámico:** Animación en tiempo real de barras de volumen en los laterales del título basada en ondas sinusoidales matemáticas.
  - **Efecto de Respiración:** El indicador `➜` realiza un movimiento suave simulando un latido lateral.
  - **Líneas divisorias animadas:** Efecto "flujo de luz" en movimiento continuo por los divisores de sección.
  - **Ciclo de Color:** El marco de la cabecera va cambiando de color de forma fluida (Arcoíris).
- ⚙️ **Servicio systemd en segundo plano:** Creado como un servicio de usuario (`systemd --user`) para que tu configuración combinada se active de forma automática al iniciar sesión.
- 🔀 **Redirección en Caliente:** Mueve tus transmisiones de audio activas (Spotify, Discord, navegadores, juegos, etc.) al dispositivo combinado sin necesidad de reiniciar las aplicaciones.

---

## 🛠️ Requisitos

- **Sistema Operativo:** Linux
- **Servidor de Sonido:** PipeWire (con emulación PulseAudio instalada) o PulseAudio nativo.
- **Utilidad:** `pactl` (disponible por defecto en la mayoría de distribuciones como Fedora, Arch, Ubuntu, Manjaro, etc.).
- **Lenguaje:** Python 3 (sin dependencias externas, usa librerías estándar).

---

## 🚀 Instalación y Uso

1. **Clona este repositorio:**
   ```bash
   git clone https://github.com/AfterEquis/afterwave.git
   cd afterwave
   ```

2. **Ejecuta el script de instalación:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   *Esto configurará y habilitará el servicio de systemd para tu usuario apuntando directamente a los scripts en esta carpeta.*

3. **Ejecuta el configurador:**
   ```bash
   ./bin/seleccionar_audio.py
   ```

---

## 🎮 Controles del Menú

- **Flechas `▲ / ▼`:** Navegar por la lista de dispositivos de entrada y salida.
- **Tecla `Espacio`:** Seleccionar/Deseleccionar (`[X]` o `[ ]`) el dispositivo enfocado.
- **Tecla `Enter`:** Guardar la configuración en tu archivo `~/.combined_headsets.conf` y aplicar la combinación de inmediato.
- **Teclas `Q` o `Esc`:** Salir del configurador sin aplicar cambios.

---

## 🔧 ¿Cómo funciona técnicamente?

El script crea y gestiona de manera dinámica varios módulos en PipeWire mediante la utilidad `pactl`:

### Entrada (Micrófonos)

```text
 [ Micrófono Físico 1 ] ──> (Loopback) ──┐
                                         ▼
 [ Micrófono Físico 2 ] ──> (Loopback) ──┼──> [ Bus de Mezcla Oculto ]
                                         │       (double_headsets_mic_bus)
 [ Micrófono Físico N ] ──> (Loopback) ──┘           │
                                                     ▼
                                              (Remap Source)
                                                     │
                                                     ▼
                                            [ Micrófono Combinado ]
                                            (Hablar-por-Ambos-Cascos)
                                                     │
                                                     ▼
                                            Aplicaciones: Discord, etc.
```

### Salida (Auriculares)

```text
 Reproducción del PC (Spotify, Juegos, etc.)
               │
               ▼
   [ Dispositivo Combinado ]
  (Escuchar-por-Ambos-Cascos)
               │
      ┌────────┴────────┐
      │ (Loopback)      │ (Loopback)
      ▼                 ▼
 [ Auricular 1 ]   [ Auricular 2 ]
```

1. **Salida Combinada:** Crea un dispositivo nulo virtual (`double_headsets_playback`) y carga un bucle de retorno (`module-loopback`) hacia cada uno de los auriculares que hayas seleccionado.
2. **Entrada Combinada:** Crea un bus de mezcla oculto (`double_headsets_mic_bus`), redirige la señal de tus micrófonos seleccionados hacia él, y luego remapea la salida del bus en un micrófono virtual (`double_headsets_mic_source`) visible por tus aplicaciones.

---

## 🧹 Desinstalación

Si deseas eliminar el configurador de tu sistema, puedes ejecutar el desinstalador:
```bash
chmod +x uninstall.sh
./uninstall.sh
```
*Esto detendrá el servicio de systemd, eliminará los archivos de configuración y los scripts instalados en tu directorio de inicio.*
