#!/usr/bin/env bash
# Snapshot the visible part of a pane and open the picker in a popup on top of it.
# usage: yanker.sh <pane_id> <client_name>
set -eu

dir="$(cd "$(dirname "$0")" && pwd)"
pane="${1:?pane id}"
client="${2:-}"

IFS=$'\t' read -r height width in_mode scroll < <(
  tmux display-message -p -t "$pane" \
    '#{pane_height}	#{pane_width}	#{pane_in_mode}	#{?scroll_position,#{scroll_position},0}'
)

# In copy mode the visible area is offset into history by scroll_position.
start=0
[ "$in_mode" = 1 ] && start=$(( -scroll ))
end=$(( start + height - 1 ))

tmp="$(mktemp -d "${TMPDIR:-/tmp}/yanker.XXXXXX")"
tmux capture-pane -p -e -t "$pane" -S "$start" -E "$end" > "$tmp/colored"
tmux capture-pane -p    -t "$pane" -S "$start" -E "$end" > "$tmp/plain"

popup=(display-popup -E -B -t "$pane" -x P -y P -w "$width" -h "$height")
[ -n "$client" ] && popup+=(-c "$client")

if ! tmux "${popup[@]}" "'$dir/picker.sh' '$tmp' '$client'"; then
  rm -rf "$tmp"
fi
