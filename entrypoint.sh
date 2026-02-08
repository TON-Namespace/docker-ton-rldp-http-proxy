#!/bin/bash
set -euo pipefail

# ────────────────────────────────────────────────
# Default values
# ────────────────────────────────────────────────
PORT="${PORT:-8080}"
ADNL_PORT="${ADNL_PORT:-3333}"
CONFIG_PATH="${CONFIG_PATH:-/ton-proxy/global.config.json}"
KEYRING_DIR="/ton-proxy/keyring"
GENERATE_ID_BIN="/usr/local/bin/generate-random-id"

# ────────────────────────────────────────────────
# Special mode: --generate-keys or --init
# ────────────────────────────────────────────────
if [[ "${1:-}" == "--generate-keys" || "${1:-}" == "--init" ]]; then
    echo ""
    echo "===== TON RLDP-HTTP-PROXY Key Generation Mode ====="
    echo ""

    if [ ! -d "$KEYRING_DIR" ]; then
        echo "Creating keyring directory: $KEYRING_DIR"
        mkdir -p "$KEYRING_DIR"
        chown 1001:1001 "$KEYRING_DIR"
    fi

    echo "Running: $GENERATE_ID_BIN --appimage-extract-and-run -m adnlid"
    echo "This will generate a new ADNL keypair..."
    echo ""

    # Run generator and capture output
    set +e  # temporarily allow errors to capture output
    output=$("$GENERATE_ID_BIN" --appimage-extract-and-run -m adnlid 2>&1)
    exitcode=$?
    set -e

    echo "$output"
    echo ""

    if [ $exitcode -ne 0 ]; then
        echo "ERROR: generate-random-id failed (exit code $exitcode)"
        echo "Check if the binary is executable and in $GENERATE_ID_BIN"
        exit 1
    fi

    # Extract hex filename (first word on first line, usually uppercase hex)
    key_filename=$(echo "$output" | head -n1 | awk '{print $1}' | grep -E '^[0-9A-F]{64}$')

    # Extract base64 ADNL address (second word)
    adnl_address=$(echo "$output" | head -n1 | awk '{print $2}')

    if [ -z "$key_filename" ] || [ -z "$adnl_address" ]; then
        echo "ERROR: Could not parse output of generate-random-id"
        echo "Expected format: HEX_FILENAME base64_address"
        echo "Got:"
        echo "$output"
        exit 1
    fi

    # The private key is saved automatically by generate-random-id into current dir (WORKDIR=/ton-proxy)
    # Move it to keyring if not already there
    key_path="./$key_filename"
    if [ -f "$key_path" ]; then
        echo "Private key generated: $key_path"
        mv -f "$key_path" "$KEYRING_DIR/$key_filename"
        chown 1001:1001 "$KEYRING_DIR/$key_filename"
        echo "Moved to keyring: $KEYRING_DIR/$key_filename"
    else
        echo "Warning: Private key file $key_path not found in current directory"
        echo "It might have been saved directly to keyring or elsewhere"
    fi

    echo ""
    echo "===== NEXT STEPS ====="
    echo "1. Your ADNL address (use this in docker-compose as SERVER_ADNL_ADDRESS):"
    echo "   $adnl_address"
    echo ""
    echo "2. Your key is now in: $KEYRING_DIR/$key_filename"
    echo "   Make sure this directory is mounted/persisted on host:"
    echo "   -v ./keyring:/ton-proxy/keyring"
    echo ""
    echo "3. Exit this container, then start normally (without --generate-keys)"
    echo ""
    exit 0
fi

# ────────────────────────────────────────────────
# Normal proxy start mode (no special flag)
# ────────────────────────────────────────────────

# 1. Check global config
if [ ! -f "$CONFIG_PATH" ]; then
    echo "ERROR: Global config file not found: $CONFIG_PATH"
    echo "Mount it: -v ./global.config.json:/ton-proxy/global.config.json:ro"
    exit 1
fi
echo "Global config found: $CONFIG_PATH"

# 2. Check keyring exists and not empty
if [ ! -d "$KEYRING_DIR" ]; then
    echo "ERROR: Keyring directory not found: $KEYRING_DIR"
    echo "Generate keys first with --generate-keys and mount the directory"
    exit 1
fi

if [ -z "$(ls -A "$KEYRING_DIR")" ]; then
    echo "ERROR: Keyring directory is empty: $KEYRING_DIR"
    echo "Run with --generate-keys first or add keys manually"
    exit 1
fi
echo "Keyring directory OK: $KEYRING_DIR ($(ls "$KEYRING_DIR" | wc -l | xargs) file(s))"

# 3. Check mandatory env vars
if [ -z "${SERVER_PUBLIC_IP:-}" ]; then
    echo "ERROR: SERVER_PUBLIC_IP is required (your public server IP)"
    exit 1
fi

if [ -z "${SERVER_ADNL_ADDRESS:-}" ]; then
    echo "ERROR: SERVER_ADNL_ADDRESS is required"
    echo "Use the base64 address from --generate-keys output"
    exit 1
fi
echo "ADNL address: ${SERVER_ADNL_ADDRESS:0:12}... (ok)"

# ────────────────────────────────────────────────
# Build & run proxy command
# ────────────────────────────────────────────────
cmd=("/usr/local/bin/rldp-http-proxy")
cmd+=("--appimage-extract-and-run")
cmd+=("-p" "$PORT")
cmd+=("-a" "${SERVER_PUBLIC_IP}:${ADNL_PORT}")
cmd+=("-C" "$CONFIG_PATH")
cmd+=("-A" "$SERVER_ADNL_ADDRESS")

# Optional flags
[ -n "${VERBOSITY:-}" ]       && cmd+=("-v" "$VERBOSITY")
[ -n "${CLIENT_PORT:-}" ]     && cmd+=("-c" "$CLIENT_PORT")
[ -n "${LOCAL:-}" ]           && cmd+=("-L" "$LOCAL")
[ -n "${DB:-}" ]              && cmd+=("-D" "$DB")
[ -n "${REMOTE:-}" ]          && cmd+=("-R" "$REMOTE")
[ -n "${STORAGE_GATEWAY:-}" ] && cmd+=("-S" "$STORAGE_GATEWAY")
[ -n "${PROXY_ALL:-}" ]       && cmd+=("-P" "$PROXY_ALL")
[ -n "${LOGNAME:-}" ]         && cmd+=("-l" "$LOGNAME")

[ "${DAEMONIZE:-false}" = "true" ] && cmd+=("-d")

echo ""
echo "Starting rldp-http-proxy:"
printf '  %q' "${cmd[@]}"
echo ""
echo ""

exec "${cmd[@]}"
