#!/bin/sh
###  Switch_to.sh
###
#### Simple script that allows to jump to between named windows
###
###  by luffah <www.luffah.xyz>
###
###  Licensed under GPLv3. 
###  Free as in freedom.
###  Free to use. Free to share. Free to modify. Free to verify.
logfile="/tmp/switch_to.log"
# Put something inside DEBUG to have logs
DEBUG=""
logthis(){
	[ -n "${DEBUG}" ] && echo "`date` $*" >> ${logfile}
}

# XdoTool is required
which xdotool > /dev/null
if [ "$?" -gt 0 ]
then
  echo "Missing 'xdotool' to run this script"
fi
if [ -z "$1" ]
then
  echo "Usage : $0 [-t|--terminal] <app_name> [<app_cmd>]"
  echo  "	-t|--terminal	auto name a terminal with the suffix <app_name>"
fi

# If -t option is used, then you need a terminal definition which have -T (-title( option)
defterm="x-terminal-emulator"
find_name_able_term(){
  ok="`${defterm} --help 2> /dev/null | grep -- -T`"
  if [ -z "${ok}" ]
  then
    which lxterminal > /dev/null && defterm=lxterminal || \
      which mate-terminal > /dev/null && defterm=xterm || \
      which xterm > /dev/null && defterm=xterm
  fi
  logthis "Using ${defterm}."
}

### Arguments parsing ###
termprefix=".t."
termode=""
case "$1" in 
  --terminal|-t)
    termmode="$1"
    find_name_able_term
    shift
    ;;
esac
case "$1" in 
  --terminal-prefix|-tp)
    termmode="$1"
    find_name_able_term
    shift
    termprefix="$1"
    shift
    ;;
esac
wname=$1
shift
wprog="$*"
[ -z "${wname}" ] && echo "No window name provided. Exit." && exit 1

[ -n "${termmode}" ] && wname="${termprefix}${wname}."
if [ -n "${wprog}" ]; then
  [ -n "${termmode}" ] && wprog="${wprog} ${wname}"
else
  [ -n "${termmode}" ] && wprog="${defterm} -T ${wname}" || wprog="${wname}"
fi
logthis ${wname}
logthis ${wprog}
###

### Variables ###
LOCAL_ACTIVE_WID=""

## import globals ###
# Window to activate if are already and the asked window (switch)
LAST_ACTIVE_WID_file="/tmp/LAST_${wname}_WID"
LAST_ACTIVE_WID="`[ -f ${LAST_ACTIVE_WID_file} ] && cat \"${LAST_ACTIVE_WID_file}\"`"

####

current_active_wid="`xdotool getactivewindow`"

logthis "def current_active_wid=${current_active_wid}" 

window_to_activate="${LOCAL_ACTIVE_WID}"
[ -z "${window_to_activate}" ] &&\
 window_to_activate="`xdotool search -name ${wname} | tail -1`"

[ -z "${window_to_activate}" ] &&\
 window_to_activate="`xdotool search ${wname} | tail -1`"

logthis "def window_to_activate=${window_to_activate}" 

if [ "${current_active_wid}" = "${window_to_activate}" ]
then
	LOCAL_ACTIVE_WID="${current_active_wid}"
	window_to_activate="${LAST_ACTIVE_WID}"
fi

if [ -z "${window_to_activate}" ]
then
  ${wprog} &
  sleep .3s
  window_to_activate="`xdotool search -name ${wname} | tail -1`"
fi
LAST_ACTIVE_WID="${current_active_wid}"

logthis "current_active_wid=${current_active_wid}" 
logthis "window_to_activate=${window_to_activate}" 

if [ -n "${window_to_activate}" ]
then 
	xdotool windowactivate "${window_to_activate}"
fi
## export globals ###
echo "${LAST_ACTIVE_WID}" > ${LAST_ACTIVE_WID_file}
#####################

