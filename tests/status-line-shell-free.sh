#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin="$repo_dir/tmux-agent-status.tmux"

grep -Fq "#{@agent-status-summary}" "$plugin"
if grep -Eq 'set-option -g status-interval 1|status-right.*status-line\.sh\)' "$plugin"; then
    echo "status integration still enables polling or appends a renderer" >&2
    exit 1
fi

grep -Fq 'tmux set-option -g @agent-status-summary "$summary"' \
    "$repo_dir/scripts/lib/status-summary.sh"

if grep -Eq 'sleep 0\.25|signal_sidebar_clients USR2 active' \
    "$repo_dir/scripts/sidebar-collector.sh"; then
    echo "collector still performs subsecond sidebar animation polling" >&2
    exit 1
fi

echo "PASS: status summary redraw path is shell-free"
