# switch_to.sh
A simple script that allows to jump between nammed windows in Xorg.
```
Usage : switch_to.sh [-t|--terminal] <app_name> [<app_cmd>]
	-t|--terminal	auto name a terminal with the suffix <app_name>
	<app_name>	shall be a quoted string if it contains spac
	<app_cmd>	can contain %title which will be remplaced by <app_name> or the title of the window when the option -t is provided
```

# Installation
```make install```
will ask to synaptic to install ```xdotool``` 
and then will run a test and install the script in ```/usr/local/bin/```

```make uninstall``` remove the script from ```/usr/local/bin/```
