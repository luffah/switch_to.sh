# switch_to.sh
A simple script that allows to jump to a nammed window in Xorg and to jump back to the original window.
```
Usage : switch_to.sh [-t|--terminal] <app_name> [<app_cmd>]
	-t|--terminal	auto title a terminal with the suffix <app_name>
	<app_name>	shall be a quoted string if it contains spac
	<app_cmd>	can contain %title which will be remplaced by <app_name> or the title of the window when the option -t is provided
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

#### Using wmctrl (GPL) -> no, already done
Using `wmctrl` with `xprop -root | grep "_NET_ACTIVE_WINDOW(WINDOW)"`, [brocket](https://github.com/dmikalova/brocket) well do the job.

It could be interesting to propose terminal auto namming and jump back features to brocket maintainer. There's job on documenting too.

#### Using Xdo (BSD) -> no, because there is EWMH
An other alternative could be using `xdo` which only manipulate windows knowing the window id. Anyway with xprop, you can have the window list and informations. 
```
#Window list with xprop
xprop -root | grep "_NET_CLIENT_LIST_STACKING(WINDOW)" `
#Window information with xprop
xprop -id <window_id> | grep "(STRING)"
```

#### Using EWMH (LPL) with python -> maybe
A cool python library nammed [python-emwh](https://github.com/parkouss/pyewmh) shall do the work faster than a simple bash script.
