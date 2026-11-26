# Record with: vhs demo/demo.tape  (from the repo root)
Output assets/demo.gif

Set Shell bash
Set FontSize 20
Set Width 1200
Set Height 560
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 90ms

Hide
Type "env -u TMUX tmux -L yanker-demo -f demo/tmux.conf new -s demo -c $PWD/demo" Enter
Sleep 1.5s
Type "clear" Enter
Sleep 300ms
Show

Type "./run-tests" Enter
Sleep 2s

# single line
Escape
Type "y"
Sleep 1.2s
Type "5"
Sleep 1s
Type "y"
Sleep 1.5s
Ctrl+b
Type "]"
Sleep 2.5s
Ctrl+u
Sleep 800ms

# range
Escape
Type "y"
Sleep 1s
Type "4"
Sleep 600ms
Type ","
Sleep 400ms
Type "6"
Sleep 1.2s
Enter
Sleep 1.5s
Ctrl+b
Type "]"
Sleep 3.5s

Hide
Ctrl+u
Type "tmux -L yanker-demo kill-server" Enter
