#!/bin/sh
###  Switch_to.sh
###
#### Simple script that allows to jump to between named windows
###
###  by luffah <contact@luffah.xyz>
###
###  Licensed under GPLv3. 
###  Free as in freedom.
###  Free to use. Free to share. Free to modify. Free to verify.
logfile="/tmp/switch_to.log"
# logfile="/dev/stdout"
# Put something inside DEBUG to have logs
DEBUG="true"
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
  echo "Usage : `basename $0` [-m <x> <y> <w> <h>] [-t|--terminal] <app_name> [<app_cmd>]"
  echo  "	-t|--terminal	auto name a terminal with the suffix <app_name>"
  echo  "	-m|--move	move/resize (X,Y,width,height e.g. 0 50% 50% 100%)"
  echo  "	<app_name>	shall be a quoted string if it contains spac"
  echo  "	<app_cmd>	can contain %title which will be remplaced by <app_name> or the title of the window when the option -t is provided"
  exit 1
fi

# If -t option is used, then you need a terminal definition which have -T (-title( option)
defterm=`readlink /etc/alternatives/x-terminal-emulator | xargs basename`
open_nammed_terminal(){
  case ${defterm} in
    lxterminal|st|mate-terminal|xterm);;
    *)
      ok="`${defterm} --help 2> /dev/null | grep -- -T`"
      if [ -z "${ok}" ]
      then
          which st > /dev/null && defterm=st || \
          which lxterminal > /dev/null && defterm=lxterminal  || \
          which mate-terminal > /dev/null && defterm=xterm || \
          which xterm > /dev/null && defterm=xterm
      fi
      ;;
  esac
  case ${defterm} in
    st)
      opt="-t \"$1\" -c $1"
      ;;
    *)
      opt="-T \"$1\""
      ;;
  esac
  logthis "Using ${defterm}."
  echo "${defterm} ${opt}"
}

new_window(){
  # eval "${wprog}" &
  eval ${wprog} &
  # window_to_activate="`xdotool search --sync --pid $!`"

  sleep .8s
  window_to_activate="`xdotool getactivewindow`"

  logthis "window_to_activate=${window_to_activate}" 

  if [ -n "${window_to_activate}" ]
  then 
    RET=`xdotool windowactivate "${window_to_activate}" 2>&1 | grep "failed"`
    return `test -z "${RET}"; echo $?`
  fi
}

activate_window(){
  if [ -z "${window_to_activate}" ]
  then
    return 1
  fi
  logthis "def window_to_activate=${window_to_activate}" 

  if [ "${current_active_wid}" = "${window_to_activate}" ]
  then
    LOCAL_ACTIVE_WID="${current_active_wid}"
    window_to_activate="${LAST_ACTIVE_WID}"
  fi

  logthis "window_to_activate=${window_to_activate}" 

  if [ -n "${window_to_activate}" ]
  then 
    RET=`xdotool windowactivate "${window_to_activate}" 2>&1 | grep "failed"`
    return `test -z "${RET}"; echo $?`
  fi
}

### Arguments parsing ###
termprefix=".t."
termode=""
change_coord=""
while true; do
case "$1" in 
  --terminal|-t)
    termmode="$1"
    shift
    ;;
  --terminal-prefix|-tp)
    termmode="$1"
    termprefix="$2"
    shift 2
    ;;
  --move|-m)
    change_coord="$1"
    coord="$2 $3"
    # y="$3"
    winsize="$4 $5"
    # h="$5"
    shift 5
    ;;
  *)
    break
    ;;
esac
done
wname="$1"
shift
wprog=""
while [ -n "$1" ]
do
#  logthis "Param	: $1"
 echo "$1" | grep ' ' > /dev/null \
  && wprog="${wprog} \"`echo "${1}" | sed 's/"/\\\"/g'`\"" \
  || wprog="${wprog} ${1}"
 shift
done
[ -z "${wname}" ] && echo "No window name provided. Exit." && exit 1

[ -n "${termmode}" ] && wname="${termprefix}${wname}."
if [ -n "${wprog}" ];  then
#  logthis "Orig cmd	: ${wprog}"
  wprog="`echo \"${wprog}\" | sed \"s/%title/\\\"${wname}\\\"/g\"`"
else
  [ -n "${termmode}" ] && wprog="`open_nammed_terminal ${wname}`" || wprog="${wname}"
fi
logthis "Name     : ${wname}"
logthis "Command  : ${wprog}"
###

### Variables ###
LOCAL_ACTIVE_WID=""

## import globals ###
# Window to activate if are already and the asked window (switch)
LAST_ACTIVE_WID_file="/tmp/LAST_`echo ${wname} | tr -d '\\ /'`_WID"
LAST_ACTIVE_WID="`[ -f ${LAST_ACTIVE_WID_file} ] && cat \"${LAST_ACTIVE_WID_file}\"`"

####

current_active_wid="`xdotool getactivewindow`"
logthis "current_active_wid=${current_active_wid}" 

window_to_activate="${LOCAL_ACTIVE_WID}"
activate_window || \
 window_to_activate="`xdotool search -classname \"${wname}\" | tail -1`" \
 activate_window || \
 window_to_activate="`xdotool search -name \"${wname}\" | tail -1`" \
 activate_window  || \
 new_window


if [ -n "${change_coord}" -a -n "${window_to_activate}" ]; then
   xdotool windowmove ${window_to_activate} ${coord}
   xdotool windowsize ${window_to_activate} ${winsize}
fi

LAST_ACTIVE_WID="${current_active_wid}"

## export globals ###
echo "${LAST_ACTIVE_WID}" > ${LAST_ACTIVE_WID_file}
#####################

