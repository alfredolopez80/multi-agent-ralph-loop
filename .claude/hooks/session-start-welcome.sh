#!/bin/bash

# SessionStart Hook: Personalized welcome message

# VERSION: 2.69.0
# v2.69.0: FIX CRIT-001 - Removed duplicate stdin read, use $INPUT from SEC-111
set -euo pipefail

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# CRIT-001 FIX: Removed duplicate stdin read - use $INPUT from SEC-111

# Extract session info from $INPUT (SEC-111 already read stdin)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

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
