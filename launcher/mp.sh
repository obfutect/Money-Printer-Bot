#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
REPO="obfutect/Money-Printer-Bot"
BINARY_NAME="money-printer"
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$INSTALL_DIR/.mp.pid"
VERSION_FILE="$INSTALL_DIR/.version"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
LOG_FILE=""     # Set to a path to log to file, e.g. "$INSTALL_DIR/bot.log". Empty = stdout.
# ─────────────────────────────────────────────────────────────────────────────
# ── Passthrough flags (run binary directly, no PID/update logic) ─────────────
PASSTHROUGH_FLAGS=("--help" "--action" "--unwrap" "--wrap" "-u" "-w")
# ─────────────────────────────────────────────────────────────────────────────

API_URL="https://api.github.com/repos/$REPO/releases/latest"

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "No PID file found, bot does not appear to be running."
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        echo "Killing bot (PID $pid)..."
        kill -9 "$pid"
        echo "Done."
    else
        echo "PID $pid is not running (stale PID file)."
    fi

    rm -f "$PID_FILE"
}

cmd_start() {
    # ── Check for running instance ───────────────────────────────────────────
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Bot is already running (PID $pid). Stop it first."
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # ── Fetch latest release info ────────────────────────────────────────────
    echo "Checking for updates..."
    local release_json
    release_json=$(curl -fsSL "$API_URL")

    local latest_tag
    latest_tag=$(echo "$release_json" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        echo "WARNING: Could not fetch latest version from GitHub. Starting existing binary."
    else
        local current_tag=""
        [[ -f "$VERSION_FILE" ]] && current_tag=$(cat "$VERSION_FILE")

        if [[ "$latest_tag" == "$current_tag" ]] && [[ -x "$BINARY_PATH" ]]; then
            echo "Already at latest version ($current_tag)."
        else
            echo "New version found: $latest_tag (current: ${current_tag:-none}). Downloading..."

            # Find the .tar.gz asset URL
            local asset_url
            asset_url=$(echo "$release_json" | grep '"browser_download_url"' | grep '\.tar\.gz"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

            if [[ -z "$asset_url" ]]; then
                echo "ERROR: Could not find a .tar.gz asset in release $latest_tag."
                exit 1
            fi

            local tmp_dir
            tmp_dir=$(mktemp -d)
            trap 'rm -rf "$tmp_dir"' EXIT

            echo "Downloading $asset_url..."
            curl -fsSL -o "$tmp_dir/release.tar.gz" "$asset_url"

            echo "Extracting..."
            tar -xzf "$tmp_dir/release.tar.gz" -C "$tmp_dir"

            local new_binary
            new_binary=$(find "$tmp_dir" -name "$BINARY_NAME" -type f | head -1)

            if [[ -z "$new_binary" ]]; then
                echo "ERROR: Binary '$BINARY_NAME' not found inside archive."
                exit 1
            fi

            chmod +x "$new_binary"
            mv "$new_binary" "$BINARY_PATH"
            echo "$latest_tag" > "$VERSION_FILE"
            echo "Updated to $latest_tag."
        fi
    fi

    # ── Launch ───────────────────────────────────────────────────────────────
    echo "Starting bot with args: $*"
    if [[ -n "$LOG_FILE" ]]; then
        nohup "$BINARY_PATH" "$@" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "Bot started (PID $!). Log: $LOG_FILE"
    else
        "$BINARY_PATH" "$@" &
        local bot_pid=$!
        echo $bot_pid > "$PID_FILE"
        trap 'echo "Stopping..."; kill -9 $bot_pid 2>/dev/null; rm -f "$PID_FILE"; exit' INT TERM
        wait $bot_pid
        rm -f "$PID_FILE"
    fi
}

# ── Entry point ───────────────────────────────────────────────────────────────
# Check for passthrough flags first
for arg in "$@"; do
    for flag in "${PASSTHROUGH_FLAGS[@]}"; do
        if [[ "$arg" == "$flag"* ]]; then
            exec "$BINARY_PATH" "$@"
        fi
    done
done

# If first argument starts with '-', treat the whole invocation as 'start'
if [[ $# -eq 0 ]] || [[ "$1" == -* ]]; then
    cmd_start "$@"
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    start)  cmd_start "$@" ;;
    stop)   cmd_stop ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Use 'start [args...]' or 'stop'."
        exit 1
        ;;
esac