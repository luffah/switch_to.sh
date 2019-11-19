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
  - performances:
    - 0.2s to jump to an existing window
    - 0.4s for a new terminal
    - 1.5s for a navigator
  - works with any window manage that is EWMH compliant
  - use EWMH lib
  - customizable output
- sh (old/tricky)
  - preformances:
    - 0.1s to jump to an existing window
    - 1.5s for a new terminal
    - 2.5s for a navigator
  - works with any window manager that works well with xdotool
  - use `xdotool` (for searching windows), `xprop` for WM_HINTS (decorations...) and optionnaly : `wmctrl` to toggle maximisation and fullscreen; `compton` to reverse screen color; `dmenu` to select window
  - colorfull output

The table below describe compatibility between script version and window manager.

| Window Manager | switch_to.sh            | switch_to.py                               |
|----------------|-------------------------|--------------------------------------------|
|  bspwm         | OK                      | OK                                         |
| compiz         | not tested              | not tested                                 |
| fluxbox        | not tested              | not tested                                 |
| gnome          | OK                      | not tested                                 |
| herbstluftwm   | OK                      | Require to set focus_stealing_prevention 0 |
| i3             | don't work with monocle | OK                                         |
| kde/plasma     | not tested              | not tested                                 |
| openbox        | OK                      | OK                                         |
| xfce           | OK                      | OK                                         |

Note: automatic window placement shall not work with a tiling window manager.

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
- `switch_to.sh` can't list applications openned in `i3`, use `switch_to.py` instead
- the both versions are not compliant (example `-i` means "ignore case" in py version, and "invert color" in sh version)

# Alternatives
* with [wmctrl](http://tripie.sweb.cz/utils/wmctrl/)

  a simple run or raise : `wmctrl -a <app_name> || <app_cmd>`

* [brocket](https://github.com/dmikalova/brocket) : it uses `wmctrl` and `xprop`

* [run-or-raise - position.org](http://fr.positon.org/tag/wmctrl) : it uses both `wmctrl` and `xdotool`

`switch_to` does less things but none jump back to previously used window.
