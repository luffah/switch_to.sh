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

# logfile="/tmp/switch_to.log"
# logfile="/dev/stderr"
# Put something inside DEBUG to have logs
# DEBUG="true"

logthis(){
	[ -n "${DEBUG}" ] && echo "`date` $*" >> ${logfile}
}

# XdoTool is required
which xdotool > /dev/null
if [ "$?" -gt 0 ]; then
  echo "Missing 'xdotool' to run this script"
  exit 1
fi

### Parameters variables ###
termprefix=".t."
termsuffix="."
termode=""
change_coord=""
force_resize=""
noexec=""
activation_delay="0.6s"

### Globals processing variables ###
win_found=""
not_back="1"
window_to_activate=""
current_active_wid=""
LAST_ACTIVE_WID=""

### Styles for terminal
grt="$(tput setaf 2; tput bold; tput smul)"
gre="$(tput setaf 2; tput bold; tput rmul)"
gxt="$(tput setaf 2; tput bold; tput rmul)"
mag=`tput setaf 5`
yel=`tput setaf 3`
yol=`tput setaf 6`
rs=`tput sgr0`

### If no parameter
if [ -z "$1" -o "$1" = "-h" ]
then
  echo "${grt}Usage${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> ${rs}"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> <app_cmd>${rs}"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${yel}${rs}[${yol}<options>${rs}]${yel} <app_name> ${rs}[${yel}<app_cmd>${rs}]"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${rs}[${yol}-m${rs} ${yel}<x> <y> <w> <h>${rs}] [${yol}-t${rs}]${yel}  <app_name> ${rs}[${yel}<app_cmd>${rs}]"
  echo
  echo "${grt}Arguments${rs} :"
  echo " ${yel}<app_name>${rs}	shall be a quoted string if it contains spac"
  echo " ${yel}<app_cmd>${rs}	can contain %title which will be remplaced by <app_name> or the title of the window when the option -t is provided"
  echo ${yol}${rs}
  echo "${grt}Options${rs} :"
  echo " ${yol}-t ${rs}|${yol}--terminal${rs}	auto name a terminal \"${termprefix}<app_name>${termsuffix}\""
  echo " ${yol}-tp${rs}|${yol}--terminal-prefix${rs}	change the terminal prefix (\"${termprefix}\")"
  echo " ${yol}-ts${rs}|${yol}--terminal-suffix${rs}	change the terminal suffix (\"${termsuffix}\")"
  echo " ${yol}-m ${rs}|${yol}--move${rs}	${yel}<x> <y> <w> <h>${rs}"
  echo "          ${rs}	move/resize (X,Y,width,height e.g. 0 50% 50% 100%)"
  echo " ${yol}-p ${rs}|${yol}--place${rs}	[new window] move/resize (X,Y,width,height e.g. 0 50% 50% 100%)"
  echo " ${yol}-d ${rs}|${yol}--delay${rs}	[new window] delay before switching to or resizing the window (${activation_delay})"
  echo " ${yol}-n ${rs}|${yol}--no-exec${rs}	don't create any new window"
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
  logthis "Using -- ${defterm} ${opt} --"
  echo "${defterm} ${opt}"
}

new_window(){
  RET="failed"
  eval "${wprog} &" && PID=$!
  logthis "PID=${PID}"
  # wait the programm to change pid ...
  sleep ${activation_delay}
  if ps -p $PID > /dev/null; then
    echo "present"
  else
    PID=""
  fi
  # while [ -z "${window_to_activate}" -o "${window_to_activate}" = "${current_active_wid}" ]
  # do
  if [ -n "${PID}" ]; then
      window_to_activate="`xdotool search --pid ${PID} --sync`"
  else
    window_to_activate="`xdotool search --classname \"${wname}\" | tail -1`"
    if [ -z "${window_to_activate}" ]; then
         window_to_activate="`xdotool search --name \"${wname}\" | tail -1 `"
      fi
  fi
  # window_to_activate="`xdotool getactivewindow`"
  # done
  logthis "window_to_activate=${window_to_activate}" 

  if [ -n "${window_to_activate}" ]
  then 
    RET=`xdotool windowactivate "${window_to_activate}" 2>&1 | grep "failed"`

    if [ -n "${change_coord}" -a -n "${window_to_activate}" ]; then
      xdotool windowmove ${window_to_activate} ${coord}
      xdotool windowsize ${window_to_activate} ${winsize}
    fi
  fi
  return `test -z "${RET}"; echo $?`
}

activate_window(){
  if [ -z "${window_to_activate}" ]
  then
    return 1
  fi
  logthis "def window_to_activate=${window_to_activate}" 

  if [ "${current_active_wid}" = "${window_to_activate}" ]
  then
    window_to_activate="${LAST_ACTIVE_WID}"
    not_back=""
  fi

  logthis "window_to_activate=${window_to_activate}" 

  if [ -n "${window_to_activate}" ]
  then 
    RET=`xdotool windowactivate "${window_to_activate}" 2>&1 | grep "failed"`
    return `test -z "${RET}"; echo $?`
  fi
}

### Arguments parsing ###
while true; do
case "$1" in 
  --terminal|-t)
    termmode="$1"
    shift
    ;;
  --delay|-d)
    if [ -n "${2}" ]; then
    activation_delay="$2"
    shift 2
    fi
    ;;
  --terminal-prefix|-tp)
    termmode="$1"
    termprefix="$2"
    shift 2
    ;;
  --place|-p)
    change_coord="$1"
    coord="$2 $3"
    # y="$3"
    winsize="$4 $5"
    # h="$5"
    shift 5
    ;;
  --move|-m)
    force_resize="1"
    change_coord="$1"
    coord="$2 $3"
    # y="$3"
    winsize="$4 $5"
    # h="$5"
    shift 5
    ;;
  --no-exec|-n)
    noexec="1"
    shift
    ;;
  --list|-l)
    # noexec="1

     # example : ./switch_to.sh -l '\.t\..*\.'
     if [ "$2" ]; then
       echo "${mag}WINDOWID ${gxt} PID    ${rs}${yol} WM_CLASS       ${yel} WM_NAME ${rs}"
       echo "${mag}--------|${gxt}|------|${rs}${yol}|--------------|${yel}|--------${rs}"
     xdotool search --onlyvisible --name "$2" | while read i
     do
       status="`xprop -id ${i} | egrep '_NET_WM_NAME|WM_CLASS|_NET_WM_DESKTOP'`"
       progclass="`echo \"${status}\" | grep 'WM_CLASS' | cut -d'=' -f2- `"
       progname="`echo \"${status}\" | grep '_NET_WM_NAME' | cut -d'=' -f2- `"
       activ="`echo \"${status}\" | grep '_NET_WM_DESKTOP' `"
       PID="`xdotool getwindowpid ${i}`"
       if [ "${activ}" ]; then
         echo "${mag}${i} ${gxt} ${PID} ${rs}${yol} ${progclass} ${yel} ${progname} ${rs}"
       fi
     done
   fi
   exit 0
   # shift
   ;;
 *)
   break
   ;;
esac
done
### Processing
# last 2 args : Window name and program
wname="$1"
if [ -n "${wname}" ];then
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
  [ -n "${termmode}" ] && wname="${termprefix}${wname}${termsuffix}"
  if [ -n "${wprog}" -a -z "${noexec}" ];  then
    #  logthis "Orig cmd	: ${wprog}"
    wprog="`echo \"${wprog}\" | sed \"s/%title/\\\"${wname}\\\"/g\"`"
  else
    [ -n "${termmode}" ] && wprog="`open_nammed_terminal ${wname}`" || wprog="${wname}"
  fi
  logthis "Name     : ${wname}"
  logthis "Command  : ${wprog}"
  ###
  if [ -z "${noexec}" ]; then
    ## import globals ###
    # Window to activate if are already and the asked window (switch)
    LAST_ACTIVE_WID_file="/tmp/LAST_`echo ${wname} | tr -d '\\ /'`_WID"
    LAST_ACTIVE_WID="`[ -f ${LAST_ACTIVE_WID_file} ] && cat \"${LAST_ACTIVE_WID_file}\"`"
    ####
    current_active_wid="`xdotool getactivewindow`"
    logthis "current_active_wid=${current_active_wid}"
  fi
  onlyvisible="--onlyvisible"

  activate_window || \
    window_to_activate="`xdotool search  ${onlyvisible} -classname \"${wname}\" | tail -1`" \
    activate_window || \
    window_to_activate="`xdotool search  ${onlyvisible} -name \"${wname}\" | tail -1`" \
    activate_window || \
    test -n "${noexec}" || new_window

  LAST_ACTIVE_WID="${current_active_wid}"

  ## export globals ###
  if [ -z "${noexec}" ]; then
    echo "${LAST_ACTIVE_WID}" > ${LAST_ACTIVE_WID_file}
  fi
  if [ -n "${force_resize}" -a -n "${not_back}" -a -n "${change_coord}" -a -n "${window_to_activate}" ]; then
    xdotool windowmove ${window_to_activate} ${coord}
    xdotool windowsize ${window_to_activate} ${winsize}
  fi
elif [ -z "${noexec}" ]; then
  echo "No window name provided. Exit." && exit 1
else
  # if no parameter, process the current window
  window_to_activate="`xdotool getactivewindow`"
  if [ -n "${force_resize}" -a  -n "${change_coord}" -a -n "${window_to_activate}" ]; then
      xdotool windowmove ${window_to_activate} ${coord}
      xdotool windowsize ${window_to_activate} ${winsize}
  fi
fi
#####################

