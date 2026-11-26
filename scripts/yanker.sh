#!/usr/bin/env bash
# Snapshot the visible part of a pane and open the picker in a popup on top of it.
# usage: yanker.sh [pane_id] [client_name]
#   Without arguments it targets the active pane and the client that ran it,
#   so a custom binding can be just: run-shell -b "#{@yanker-cmd}"
#
# Every tmux call costs a client round trip, so this does all of its work in
# three: one to read geometry and options, one to capture, one to open the popup.
set -eu

dir="$(cd "$(dirname "$0")" && pwd)"
pane="${1:-}"
client="${2:-}"
if [ -z "$pane" ]; then
  IFS=$'\x1f' read -r pane client < <(tmux display-message -p $'#{pane_id}\x1f#{client_name}')
fi

IFS=$'\x1f' read -r height width in_mode scroll gutter selected popup_style copy_cmd < <(
  tmux display-message -p -t "$pane" \
    "$(printf '%s\x1f' '#{pane_height}' '#{pane_width}' '#{pane_in_mode}' \
      '#{?scroll_position,#{scroll_position},0}' '#{@yanker-gutter-style}' \
      '#{@yanker-selected-style}' '#{@yanker-popup-style}' '#{@yanker-copy-command}')"
)

# In copy mode the visible area is offset into history by scroll_position.
start=0
[ "$in_mode" = 1 ] && start=$(( -scroll ))
end=$(( start + height - 1 ))

tmp="$(mktemp -d "${TMPDIR:-/tmp}/yanker.XXXXXX")"

# Plain text (what gets yanked) followed by the colored version (what gets shown).
tmux capture-pane -p -t "$pane" -S "$start" -E "$end" \; \
     capture-pane -p -e -t "$pane" -S "$start" -E "$end" > "$tmp/snapshot"

{
  printf 'height=%q\n' "$height"
  printf 'width=%q\n' "$width"
  printf 'gutter_style=%q\n' "${gutter:-90}"
  printf 'selected_style=%q\n' "${selected:-30;43}"
  printf 'copy_cmd=%q\n' "$copy_cmd"
} > "$tmp/opts"

popup=(display-popup -E -B -t "$pane" -x P -y P -w "$width" -h "$height")
[ -n "$client" ] && popup+=(-c "$client")

# Passing argv (not a command string) skips default-shell and its startup files.
# -s and the "terminal" colour need a recent tmux; fall back to the default style.
if ! tmux "${popup[@]}" -s "${popup_style:-fg=terminal,bg=terminal}" \
       "$dir/picker.sh" "$tmp" "$client" 2>/dev/null &&
   ! tmux "${popup[@]}" "$dir/picker.sh" "$tmp" "$client"; then
  rm -rf "$tmp"
fi
