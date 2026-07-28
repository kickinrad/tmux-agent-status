#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_HOME="$TMP_DIR/home"
FAKE_BIN="$TMP_DIR/bin"
CALLS="$TMP_DIR/workroom-calls"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    display-message) printf 'workroom-test\n'; exit 0 ;;
esac
exit 0
EOF

cat >"$FAKE_BIN/workroom" <<EOF
#!/usr/bin/env bash
printf '%s\\t%s\\t' "\$1" "\$2" >>"$CALLS"
cat >>"$CALLS"
printf '\\n' >>"$CALLS"
EOF

chmod +x "$FAKE_BIN/tmux" "$FAKE_BIN/workroom"

run_hook() {
    local adapter="$1"
    local harness="$2"
    local session_id="$3"

    printf '{"session_id":"%s","hook_event_name":"SessionStart"}\n' "$session_id" |
        PATH="$FAKE_BIN:$PATH" \
        HOME="$TEST_HOME" \
        TMUX="/tmp/tmux-test,4242,0" \
        TMUX_PANE="%9" \
        WORKROOM_ID="workroom-test" \
        "$REPO_DIR/hooks/$adapter" SessionStart

    grep -F "record-session	$harness	" "$CALLS" >/dev/null
    grep -F "\"session_id\":\"$session_id\"" "$CALLS" >/dev/null
}

run_hook "codex-hook.sh" "codex" "11111111-1111-4111-8111-111111111111"
run_hook "better-hook.sh" "claude" "22222222-2222-4222-8222-222222222222"

echo "workroom session recording checks passed"
