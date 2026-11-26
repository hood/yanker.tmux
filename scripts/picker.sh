#!/usr/bin/env bash
# Interactive line picker, runs inside the popup.
# usage: picker.sh <snapshot_dir> <client_name>
#
# keys: <n> y          yank line n
#       <n>,<m> y      yank lines n..m  (separator: , - space)
#       Enter          same as y
#       Backspace      edit
#       Esc q C-c C-g  cancel

tmp="$1"
client="${2:-}"

opt() {
  local v
  v="$(tmux show-option -gqv "$1")"
  printf '%s' "${v:-$2}"
}

GUTTER=$'\e['"$(opt @yanker-gutter-style 90)"'m'
SELECTED=$'\e['"$(opt @yanker-selected-style '30;43')"'m'
copy_cmd="$(opt @yanker-copy-command '')"
RESET=$'\e[0m'

cleanup() {
  printf '\e[?7h\e[?25h'
  rm -rf "$tmp"
}
trap cleanup EXIT

colored=(); plain=()
while IFS= read -r l || [ -n "$l" ]; do colored+=("$l"); done < "$tmp/colored"
while IFS= read -r l || [ -n "$l" ]; do plain+=("$l"); done < "$tmp/plain"
n=${#colored[@]}
[ "$n" -eq 0 ] && exit 0
gw=${#n}

read -r rows cols < <(stty size 2>/dev/null || echo "$n 80")

a=""      # first line number (as typed)
b=""      # second line number
stage=0   # 0: typing a, 1: typing b

range() {
  lo=0 hi=-1
  [ -z "$a" ] && return
  lo=$a hi=$a
  if [ "$stage" = 1 ] && [ -n "$b" ]; then
    if [ "$b" -lt "$a" ]; then lo=$b; else hi=$b; fi
  fi
}

render() {
  range
  local buf=$'\e[H' i num line
  for (( i = 0; i < n; i++ )); do
    num=$(( i + 1 ))
    if [ "$num" -ge "$lo" ] && [ "$num" -le "$hi" ]; then
      printf -v line '%s%*d %s\e[K%s' "$SELECTED" "$gw" "$num" "${plain[i]}" "$RESET"
    else
      printf -v line '%s%*d%s %s%s\e[K' "$GUTTER" "$gw" "$num" "$RESET" "${colored[i]}" "$RESET"
    fi
    buf+="$line"
    (( i < n - 1 )) && buf+=$'\r\n'
  done

  local status
  if [ -z "$a" ]; then
    status=" yank: <n>[,<m>] y "
  elif [ "$stage" = 1 ]; then
    status=" $a,$b "
  else
    status=" $a "
  fi
  local col=$(( cols - ${#status} + 1 ))
  [ "$col" -lt 1 ] && col=1
  buf+=$'\e['"$rows;$col"'H'"$SELECTED$status$RESET"
  printf '%s' "$buf"
}

# Append digit $1 to field named $2 if it stays a valid line number.
push_digit() {
  local cur="${!2}" next
  next="$cur$1"
  [ "$next" = 0 ] && return
  [ "$next" -gt "$n" ] && return
  eval "$2=\$next"
}

copy_to_clipboard() {
  if [ -n "$copy_cmd" ]; then
    sh -c "$copy_cmd"
  elif command -v pbcopy >/dev/null; then
    pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null; then
    wl-copy
  elif command -v xclip >/dev/null; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null; then
    xsel -ib
  else
    cat >/dev/null
  fi
}

yank() {
  range
  local text="" i
  for (( i = lo - 1; i < hi; i++ )); do
    text+="${plain[i]}"
    (( i < hi - 1 )) && text+=$'\n'
  done
  printf '%s' "$text" | tmux load-buffer -w -
  printf '%s' "$text" | copy_to_clipboard

  local what="line $lo"
  [ "$lo" != "$hi" ] && what="lines $lo-$hi"
  if [ -n "$client" ]; then
    tmux display-message -c "$client" "yanked $what"
  else
    tmux display-message "yanked $what"
  fi
  exit 0
}

printf '\e[?7l\e[?25l\e[2J'
render

while IFS= read -rsn1 key; do
  case "$key" in
    [0-9])
      if [ "$stage" = 0 ]; then push_digit "$key" a; else push_digit "$key" b; fi ;;
    ,|-|' ')
      [ -n "$a" ] && stage=1 ;;
    y|'')
      [ -n "$a" ] && yank ;;
    $'\x7f'|$'\b')
      if [ "$stage" = 1 ] && [ -n "$b" ]; then b="${b%?}"
      elif [ "$stage" = 1 ]; then stage=0
      else a="${a%?}"
      fi ;;
    $'\e'|q|$'\x03'|$'\x07')
      exit 0 ;;
  esac
  render
done
