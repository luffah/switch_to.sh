# switch_to.sh
A simple script that allows to jump to a nammed window in Xorg and to jump back to the original window.
```
Usage : switch_to.sh  <app_name> 
      : switch_to.sh  <app_name> <app_cmd>
      : switch_to.sh [<options>] <app_name> [<app_cmd>]
      : switch_to.sh [-m <x> <y> <w> <h>] [-t]  <app_name> [<app_cmd>]

Arguments :
 <app_name>	either executable, window title or window class
           	-> shall be a quoted string if it contains any space

 <app_cmd>	command line for launching the application
          	-> can contain %title which will be remplaced by
          	   the window title (<app_name> or
          	   the title computed when using option -t)

Options :
 -t |--terminal	auto name a terminal ".t.<app_name>."
 -tp|--terminal-prefix	change the terminal prefix (".t.")
 -ts|--terminal-suffix	change the terminal suffix (".")
 -m |--move	<x> <y> <w> <h>
          	move/resize (X,Y,width,height e.g. 0 50% 50% 100%)
 -p |--place	[new window] move/resize (X,Y,width,height e.g. 0 50% 50% 100%)
 -d |--delay	[new window] delay before switching to or resizing the window (0.6s)
 -n |--no-exec	don't create any new window
Tricky options :
 --percent	[before --move or --place] force coordonates in percent
 -mc|-pc	short options for '--percent --move' and '--percent --place'
 -l|--list	list windows (with optionnal pattern)
 -ln|--next	jump to next window (with optionnal pattern)
```

# Installation
```make install```
will ask to synaptic to install ```xdotool``` 
and then will run a test and install the script in ```/usr/local/bin/```

```make uninstall``` remove the script from ```/usr/local/bin/```

# Alternatives
* [wmctrl](http://tripie.sweb.cz/utils/wmctrl/)

  `switch_to.sh` is slightly equivalent to `wmctrl -a <app_name> | <app_cmd>` with the difference that `wmctrl` doesn't (currently) allow to jump back to the previous window. 
* [brocket](https://github.com/dmikalova/brocket) : it uses `wmctrl` and `xprop`

  `switch_to.sh` does less things that `brocket` but this one doesn't jump back too...
* [run-or-raise - position.org](http://fr.positon.org/tag/wmctrl) : it uses both `wmctrl` and `xdotool` 

# And the future
The question will be about performance of using xdotool (BSD).

Too, the alternatives are quite good.

Do we need a future ?

#### Using wmctrl (GPL)
Using `wmctrl` instead of `xdotool` could radically shorten the script, but imply refactoring. 

#### Using Xdo (BSD) 
Using `xdo` instead of `xdotool` offer a chance to simplify the code while keeping the structure. 

#### Using EWMH (LPL) with python
A cool python library nammed [python-emwh](https://github.com/parkouss/pyewmh) shall do the work faster than a simple bash script.
