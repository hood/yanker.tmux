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

cleanup() {
  printf '\e[?7h\e[?25h'
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Written by yanker.sh: height width gutter_style selected_style copy_cmd
. "$tmp/opts"

GUTTER=$'\e['"$gutter_style"'m'
SELECTED=$'\e['"$selected_style"'m'
RESET=$'\e[0m'

shopt -s extglob

# Visible width of $1, ignoring SGR and OSC (e.g. hyperlink) escapes.
ESC=$'\e'
visible_len() {
  local t="${1//"$ESC"\[*([0-9;:])m/}"
  t="${t//"$ESC"\]*([!"$ESC"])"$ESC"\\/}"
  REPLY=${#t}
}

# Expand tabs to spaces on 8-column stops of the original pane, so the
# gutter does not shift them. Result in REPLY.
expand_tabs() {
  local s="$1" out="" col=0 pre pad sp
  while [[ "$s" == *$'\t'* ]]; do
    pre="${s%%$'\t'*}"
    s="${s#*$'\t'}"
    visible_len "$pre"
    col=$(( col + REPLY ))
    pad=$(( 8 - col % 8 ))
    printf -v sp '%*s' "$pad" ''
    out+="$pre$sp"
    col=$(( col + pad ))
  done
  REPLY="$out$s"
}

# snapshot = <height> plain lines, then <height> colored lines
colored=(); plain=(); shown=()
i=0
while IFS= read -r l || [ -n "$l" ]; do
  expand_tabs "$l"
  if [ "$i" -lt "$height" ]; then
    plain+=("$l"); shown+=("$REPLY")
  else
    colored+=("$REPLY")
  fi
  i=$(( i + 1 ))
done < "$tmp/snapshot"
n=${#colored[@]}
[ "$n" -eq 0 ] && exit 0
gw=${#n}
rows=$n
cols=$width

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
      printf -v line '%s%*d %s\e[K%s' "$SELECTED" "$gw" "$num" "${shown[i]}" "$RESET"
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
