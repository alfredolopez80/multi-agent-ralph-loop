#!/bin/bash

# SessionStart Hook: Personalized welcome message

# VERSION: 2.57.0
set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')
SOURCE=$(echo "$HOOK_INPUT" | jq -r '.source // "startup"')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')

# Get current time for welcome message
HOUR=$(date +"%H")
if [ "$HOUR" -lt 12 ]; then
    GREETING="Buenos días"
elif [ "$HOUR" -lt 18 ]; then
    GREETING="Buenas tardes"
else
    GREETING="Buenas noches"
fi

# Build the welcome message
WELCOME_MSG="🎉 $GREETING, Alfredo!!

Bienvenido de nuevo. Vamos a trabajar en algo increíble hoy.

📂 Proyecto actual: ${CWD:-$(pwd)}

💡 Para empezar, puedes:
   • Escribirme directamente lo que necesitas
   • Usar /help para ver comandos disponibles
   • Ejecutar /ralph-loop para bucles iterativos

Estoy listo cuando tú lo estés. 🚀"

# Output the welcome message to stdout (goes to context)
echo "$WELCOME_MSG"

# Also print directly to TTY for immediate visibility
if [ -t 1 ]; then
    echo "$WELCOME_MSG" > /dev/tty
fi

# Show macOS notification for immediate visibility
osascript -e "display notification \"$GREETING, Alfredo! Bienvenido de nuevo.\" with title \"Claude Code\" subtitle \"Sesión iniciada\" sound name \"Glass\""

exit 0
