#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
TEST_HOME="$TMP_DIR/home"
SOCKET="agent-status-scope-$$"

cleanup() {
    tmux -L "$SOCKET" kill-server 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

STATUS_DIR="$TEST_HOME/.cache/tmux-agent-status"
PANE_DIR="$STATUS_DIR/panes"
mkdir -p "$PANE_DIR"

tmux -L "$SOCKET" -f /dev/null new-session -d -s workroom "sleep 60"
tmux -L "$SOCKET" new-session -d -s unrelated "sleep 60"

workroom_pane=$(tmux -L "$SOCKET" list-panes -t workroom -F '#{pane_id}')
unrelated_pane=$(tmux -L "$SOCKET" list-panes -t unrelated -F '#{pane_id}')

printf 'done' > "$PANE_DIR/workroom_${workroom_pane}.status"
printf 'codex' > "$PANE_DIR/workroom_${workroom_pane}.agent"
printf 'done' > "$PANE_DIR/unrelated_${unrelated_pane}.status"
printf 'claude' > "$PANE_DIR/unrelated_${unrelated_pane}.agent"
printf 'agents' > "$STATUS_DIR/.sidebar-mode"

tmux -L "$SOCKET" set-option -t workroom @agent-sidebar-scope current
tmux -L "$SOCKET" run-shell "env HOME='$TEST_HOME' '$REPO_DIR/scripts/sidebar-collector.sh' --once"
tmux -L "$SOCKET" split-window -d -t workroom -h \
    "env HOME='$TEST_HOME' '$REPO_DIR/scripts/sidebar.sh'"

sleep 1

sidebar_pane=$(tmux -L "$SOCKET" list-panes -t workroom \
    -F '#{pane_id}	#{pane_current_command}' |
    awk '$2 == "bash" { print $1; exit }')
rendered=$(tmux -L "$SOCKET" capture-pane -p -t "$sidebar_pane" -S -100)

if ! grep -Fq "INBOX" <<< "$rendered"; then
    echo "Assertion failed: current scope should preserve Inbox" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
fi

if ! grep -Fq "workroom" <<< "$rendered"; then
    echo "Assertion failed: current scope should show its workroom session" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
fi

if grep -Fq "unrelated" <<< "$rendered"; then
    echo "Assertion failed: current scope should hide unrelated sessions" >&2
    printf '%s\n' "$rendered" >&2
    exit 1
fi

echo "sidebar current scope integration checks passed"
