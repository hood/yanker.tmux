#!/usr/bin/env bash
# TPM entry point: binds the yanker key(s).

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

opt() {
  local v
  v="$(tmux show-option -gqv "$1")"
  printf '%s' "${v:-$2}"
}

key="$(opt @yanker-key Y)"
root_key="$(opt @yanker-root-key '')"
cmd="$dir/scripts/yanker.sh '#{pane_id}' '#{client_name}'"

[ -n "$key" ] && tmux bind-key "$key" run-shell -b "$cmd"
[ -n "$root_key" ] && tmux bind-key -n "$root_key" run-shell -b "$cmd"
exit 0
