#!/bin/bash
set -e

# Setup trap for graceful termination
trap 'echo "[Antigravity] Zamykanie kontenera..."; kill $(jobs -p) 2>/dev/null || true; exit 0' SIGTERM SIGINT

# Configurable environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}
INSTANCE_NAME=${INSTANCE_NAME:-"OMV-Antigravity"}
ENABLE_WEB_TERMINAL=${ENABLE_WEB_TERMINAL:-"true"}
WEB_TERMINAL_PORT=${WEB_TERMINAL_PORT:-"7681"}
AUTO_START_REMOTE=${AUTO_START_REMOTE:-"true"}

# 1. Handle PUID & PGID (essential for OpenMediaVault / NAS permissions)
CURRENT_UID=$(id -u antigravity)
CURRENT_GID=$(id -g antigravity)

if [ "$PGID" != "$CURRENT_GID" ]; then
    groupmod -o -g "$PGID" antigravity 2>/dev/null || true
fi

if [ "$PUID" != "$CURRENT_UID" ]; then
    usermod -o -u "$PUID" antigravity 2>/dev/null || true
fi

# 2. Docker socket group integration (if mounted)
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    if ! getent group "$DOCKER_GID" >/dev/null 2>&1; then
        groupadd -g "$DOCKER_GID" dockerhost 2>/dev/null || true
    fi
    DOCKER_GROUP_NAME=$(getent group "$DOCKER_GID" | cut -d: -f1)
    if [ -n "$DOCKER_GROUP_NAME" ]; then
        usermod -aG "$DOCKER_GROUP_NAME" antigravity 2>/dev/null || true
    fi
fi

# 3. Ensure required directories exist with correct ownership
mkdir -p /home/antigravity/.gemini/config \
         /home/antigravity/.gemini/antigravity-cli \
         /home/antigravity/.config \
         /home/antigravity/.local/bin \
         /home/antigravity/.cache \
         /workspace

chown -R antigravity:antigravity /home/antigravity/.gemini \
                                 /home/antigravity/.config \
                                 /home/antigravity/.local \
                                 /home/antigravity/.cache \
                                 /workspace

# 4. Configure Instance Name for Remote Control
if [ -n "$INSTANCE_NAME" ]; then
    CONFIG_FILE="/home/antigravity/.gemini/config/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "{\"userSettings\": {\"cliRemoteControlHostname\": \"$INSTANCE_NAME\"}}" > "$CONFIG_FILE"
    else
        TMP_CFG=$(mktemp)
        jq --arg name "$INSTANCE_NAME" '.userSettings.cliRemoteControlHostname = $name' "$CONFIG_FILE" > "$TMP_CFG" 2>/dev/null || \
            echo "{\"userSettings\": {\"cliRemoteControlHostname\": \"$INSTANCE_NAME\"}}" > "$TMP_CFG"
        mv "$TMP_CFG" "$CONFIG_FILE"
    fi
    chown antigravity:antigravity "$CONFIG_FILE"
fi

# 5. Start Web Terminal (ttyd) if enabled
if [ "$ENABLE_WEB_TERMINAL" = "true" ]; then
    TTYD_AUTH_ARGS=""
    if [ -n "$WEB_TERMINAL_USER" ] && [ -n "$WEB_TERMINAL_PASS" ]; then
        TTYD_AUTH_ARGS="-c ${WEB_TERMINAL_USER}:${WEB_TERMINAL_PASS}"
    fi

    echo "[Antigravity] Uruchamianie Web Terminal na porcie ${WEB_TERMINAL_PORT}..."
    gosu antigravity ttyd -p "$WEB_TERMINAL_PORT" $TTYD_AUTH_ARGS -W bash &
fi

# 6. Check Authentication & Launch Service
if [ "$AUTO_START_REMOTE" = "true" ] && [ "$1" = "agy" ] && [ "$2" = "remote-control" ] && [ "$3" = "serve" ]; then
    # Sprawdzenie czy CLI jest zalogowane
    if gosu antigravity agy remote-control serve 2>&1 | grep -q "not signed in"; then
        echo "=========================================================================="
        echo " [Antigravity CLI] Wymagana JEDNORAZOWA autoryzacja Google OAuth!"
        echo "--------------------------------------------------------------------------"
        echo " Aby polaczyc kontener z Remote Access (antigravity.google.com):"
        echo ""
        if [ "$ENABLE_WEB_TERMINAL" = "true" ]; then
            echo " Metoda 1 (Najwygodniejsza - w przegladarce):"
            echo "   1. Otworz w przegladarce: http://<ADRES_IP_SERWERA>:${WEB_TERMINAL_PORT}"
            echo "   2. Wpisz polecenie: agy-login (lub: agy)"
            echo "   3. Kliknij/otworz wygenerowany link i zaloguj sie na konto Google."
            echo "   4. Wklej wygenerowany kod z przegladarki do terminala."
            echo ""
        fi
        echo " Metoda 2 (Przez terminal SSH / konsolę serwera):"
        echo "   Uruchom na hoście polecenie:"
        echo "     docker compose exec -it antigravity agy-login"
        echo "   i wykonaj instrukcje na ekranie."
        echo ""
        echo " Po pomyslnej autoryzacji sesja zapisze sie w podmontowanym katalogu config"
        echo " i kontener automatycznie polaczy sie z Google Remote Control."
        echo "=========================================================================="
        echo "[Antigravity] Oczekiwanie na autoryzacje uzytkownika..."

        while true; do
            sleep 5 &
            wait $!
            if ! gosu antigravity agy remote-control serve 2>&1 | grep -q "not signed in"; then
                echo "=========================================================================="
                echo " [Antigravity CLI] Autoryzacja wykryta pomyslnie!"
                echo "=========================================================================="
                break
            fi
        done
    fi

    echo "=========================================================================="
    echo " [Antigravity CLI] Uruchamianie uslugi Remote Control..."
    echo " Nazwa instancji: ${INSTANCE_NAME}"
    echo " Dostep zdalny: https://antigravity.google.com"
    echo "=========================================================================="

    exec gosu antigravity agy remote-control serve
else
    # Run arbitrary command
    exec gosu antigravity "$@"
fi
