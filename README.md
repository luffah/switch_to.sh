# switch_to.sh
A simple script that allows to jump to a nammed window in Xorg and to jump back to the original window.
```sh
# Usage : switch_to.sh [<options>] <app_name> [<app_cmd>]

# Go to firefox window.
# If not existing: launch it
switch_to.sh firefox firefox
# which is equivalent to
switch_to.sh firefox

# Go to firefox window.
# If not existing:
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

# Go to firefox window.
# If not existing: Go to epiphany window
#                  If not existing : echo a message
switch_to.sh firefox switch_to.sh epiphany echo ":("

# Get window ids
switch_to.sh -l

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

# Alternatives
* [wmctrl](http://tripie.sweb.cz/utils/wmctrl/)

  `switch_to.sh` is slightly equivalent to `wmctrl -a <app_name> | <app_cmd>` with the difference that `wmctrl` doesn't (currently) allow to jump back to the previous window. 
* [brocket](https://github.com/dmikalova/brocket) : it uses `wmctrl` and `xprop`

  `switch_to.sh` does less things that `brocket` but this one doesn't jump back too...
* [run-or-raise - position.org](http://fr.positon.org/tag/wmctrl) : it uses both `wmctrl` and `xdotool` 

# And the future
The question will be about performance of using xdotool (BSD) and about implementing an 'exposé'.

Too, the alternatives are quite good.

Do we need a future ?

#### Using wmctrl (GPL)
Using `wmctrl` instead of `xdotool` could radically shorten the script, but imply refactoring. 

#### Using Xdo (BSD) 
Using `xdo` instead of `xdotool` offer a chance to simplify the code while keeping the structure. 

#### Using EWMH (LPL) with python
A cool python library nammed [python-emwh](https://github.com/parkouss/pyewmh) shall do the work faster than a simple bash script.
