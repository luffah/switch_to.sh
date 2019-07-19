# switch_to
A script to simply jump to a nammed window in Xorg and to jump back to the original window.

```sh
Usage : switch_to [<options>] <app_name> [<app_cmd>]

# Go to firefox window.
# If not existing: launch it
switch_to firefox firefox

# which is equivalent to
switch_to firefox

# list windows
switch_to -l

# Go to firefox window.
# If not existing: Go to epiphany window
#                  If not existing : echo a message
switch_to firefox switch_to epiphany echo ":("
```

There is 2 versions :
- python (new/clean)
  - use EWMH lib
  - works in `i3`
  - faster to start/jump heavy applications (like `firefox`)
- sh (old/tricky)
  - use `xdotool` (for searching windows)
  - use `xprop` for WM_HINTS (decorations...)
  - use optionnaly `wmctrl` to toggle maximisation and fullscreen
  - use optionnaly `compton` to reverse screen color
  - use optionnaly `dmenu` to select window
  - eye candy
  - faster to jump on applications

## specific to switch_to.py
```sh

# Go to the terminal nammed ".t.starting with a shell."
# If not existing:
# - open a new terminal ( -t )
# - move/resize it to right ( place with percentage in -pc)
switch_to.py -p 50c 0 50c 100c  -t "starting with a shell"
```
## specific to switch_to.sh
```sh
# If firefox window  not exist:
# - open a launch eponym process
# - remove decoration (-u)
switch_to.sh -u firefox

# Go to the terminal nammed ".t.starting with a shell."
# If not existing:
# - open a new terminal ( -t in -ut )
# - remove decoration ( -u in -ut ) 
# - move/resize it to right ( place with percentage in -pc)
switch_to.sh -pc 50 0 50 100  -ut "starting with a shell"

# Go to Bla bla nammed window.
# If not existing: change the name property of the active window
switch_to.sh "Bla bla"  xprop -id "\${current_active_wid}" -set WM_NAME  "Bla bla"


# or to navigate between window
switch_to.sh --dmenu
```

# Installation
`make install`
will ask to synaptic to install `xdotool`
and then will run a test and install the script in `/usr/local/bin/`


`make uninstall` remove the script from `/usr/local/bin/`


Important note : `xdotool` can't find `gnome-terminal` since it is not managed by X.
In order to have a title in `gnome-terminal`, you may add this line to your bashrc.
```
if [ "${WINDOW_NAME}" ];then
  echo -ne "\033]0;${WINDOW_NAME}\007"
fi
```

# Known issues
- `swicth_to.sh` can't list applications openned in `i3`, use `switch_to.py` instead

# Alternatives
* with [wmctrl](http://tripie.sweb.cz/utils/wmctrl/)

  a simple run or raise : `wmctrl -a <app_name> || <app_cmd>`

* [brocket](https://github.com/dmikalova/brocket) : it uses `wmctrl` and `xprop`

* [run-or-raise - position.org](http://fr.positon.org/tag/wmctrl) : it uses both `wmctrl` and `xdotool`

`switch_to.sh` does less things but none jump back to previously used window.
