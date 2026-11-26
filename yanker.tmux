#!/usr/bin/env bash
# TPM entry point: binds the yanker key(s) and exposes @yanker-cmd for custom bindings.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Value of option $1, or $2 when unset. Set-but-empty ('') stays empty, which disables a key.
opt() {
  if [ -n "$(tmux show-option -gq "$1")" ]; then
    tmux show-option -gqv "$1"
  else
    printf '%s' "$2"
  fi
}

key="$(opt @yanker-key Y)"
root_key="$(opt @yanker-root-key '')"
cmd="$dir/scripts/yanker.sh '#{pane_id}' '#{client_name}'"

tmux set-option -g @yanker-cmd "$dir/scripts/yanker.sh"

[ -n "$key" ] && tmux bind-key "$key" run-shell -b "$cmd"
[ -n "$root_key" ] && tmux bind-key -n "$root_key" run-shell -b "$cmd"
exit 0
