# yanker.tmux

Yank lines from the visible tmux pane by line number. No copy-mode dance.

Hit the key, line numbers show up over the pane, type `12 y` and line 12 is in your clipboard.

```
 1 $ make test
 2 go test ./...
 3 --- FAIL: TestParse (0.00s)
 4     parse_test.go:42: expected 3, got 4        <- 3,4 y
 5 FAIL
 6 $                                                    3,4
```

## Keys

| keys            | action                                                  |
|-----------------|---------------------------------------------------------|
| `12 y`          | yank line 12                                            |
| `3,12 y`        | yank lines 3..12 (`-` or space work too, any order)     |
| `Enter`         | same as `y`                                             |
| `Backspace`     | edit                                                    |
| `Esc` `q` `C-c` | cancel                                                  |

Works in copy mode too, numbers follow the scrolled view.

Yanked text lands in the tmux paste buffer, the system clipboard and OSC 52 (if `set-clipboard` is on).

## Requirements

- tmux >= 3.2 (uses `display-popup`)
- bash (3.2 is fine, so stock macOS works)

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'hood/yanker.tmux'
```

Manual:

```sh
git clone https://github.com/hood/yanker.tmux ~/.tmux/plugins/yanker.tmux
```

```tmux
run-shell ~/.tmux/plugins/yanker.tmux/yanker.tmux
```

## Options

Set them before the plugin is loaded.

```tmux
set -g @yanker-key Y                    # prefix binding, '' to disable
set -g @yanker-root-key M-y             # optional binding without prefix
set -g @yanker-gutter-style '90'        # SGR params for line numbers
set -g @yanker-selected-style '30;43'   # SGR params for selected lines
set -g @yanker-copy-command 'pbcopy'    # default: pbcopy / wl-copy / xclip / xsel
```

## How it works

1. Snapshots the visible part of the pane with `capture-pane` (colors kept for display, plain text for yanking).
2. Opens a borderless popup exactly on top of the pane and redraws it with a line number gutter.
3. Reads keys, highlights the selection, then pushes the text to `load-buffer -w` and your clipboard tool.

## Limitations

- Numbers are screen rows, so a long wrapped line counts as several rows.
- Arrow keys cancel the picker.

## License

MIT
