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

### require XdoTool but not eternally
### most operations could benefit of change to xdo

# logfile="/tmp/switch_to.log"
# logfile="/dev/stderr"
# Put something inside DEBUG to have logs
# DEBUG="true"

logthis(){
	[ -n "${DEBUG}" ] && echo "`date` $*" >> ${logfile}
}

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
# onlyvisible="--onlyvisible"
onlyvisible=""

### Styles for terminal
grt="$(tput setaf 2; tput bold; tput smul)"
gre="$(tput setaf 2; tput bold; tput rmul)"
gxt="$(tput setaf 2; tput bold; tput rmul)"
rev=`tput bold; tput rev; tput setab 0`
mag=`tput setaf 5; `
yel=`tput setaf 3;`
yol=`tput setaf 6;`
rs=`tput sgr0`

FWID="%-9s"
FPID="%-6s"
if [ "${FLAT_THEME}" ]; then
  FLONG="%-21.21s"
  FORMATLIST="${mag}${FWID}${rev} ${rs}${gxt} ${FPID}${rev} ${rs}${yol} ${FLONG}${rev} ${rs}${yel} ${FLONG}${rev} ${rs}\n"
else
  FLONG="%-21s"
  FORMATLIST="${mag}${FWID} ${rs}${gxt} ${FPID}${rs}${yol} ${FLONG} ${rs}${yel} ${FLONG}${rs}\n"
fi
FORMATLISTACTIV="${mag}${rev}${FWID} ${rs}${gxt}${rev} ${FPID} ${rs}${yol}${rev} ${FLONG} ${yel}${rev} ${FLONG} ${rs}\n"
LISTHEADER="`printf \"${FORMATLISTACTIV}\" WINDOWID PID WM_CLASS WM_NAME`"

### If no parameter
if [ -z "$1" -o "$1" = "-h" ]
then
  echo "${grt}Usage${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> ${rs}"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> <app_cmd>${rs}"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${yel}${rs}[${yol}<options>${rs}]${yel} <app_name> ${rs}[${yel}<app_cmd>${rs}]"
  echo "     ${gre} :${rs} ${mag}`basename $0` ${rs}[${yol}-m${rs} ${yel}<x> <y> <w> <h>${rs}] [${yol}-t${rs}]${yel}  <app_name> ${rs}[${yel}<app_cmd>${rs}]"
  echo
  echo "${grt}Arguments${rs} :"
  echo " ${yel}<app_name>${rs}	either executable, window title or window class"
  echo "           	-> shall be a quoted string if it contains any space"
  echo
  echo " ${yel}<app_cmd>${rs}	command line for launching the application"
  echo "          	-> can contain ${yel}%title${rs} which will be remplaced by"
  echo "          	   the window title (${yel}<app_name>${rs} or"
  echo "          	   the title computed when using option ${yol}-t${rs})"
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
  echo "${grt}Tricky options${rs} :"
  echo " ${yol}${yol}--percent${rs}	[before --move or --place] force coordonates in percent"
  echo " ${yol}-mc${rs}|${yol}-pc${rs}	short options for '--percent --move' and '--percent --place'${rs}"
  echo " ${yol}-l${rs}|${yol}--list${rs}	list windows (with optionnal pattern)${rs}"
  echo " ${yol}-ln${rs}|${yol}--next${rs}	jump to next window (with optionnal pattern)${rs}"
  exit 1
fi

current_active_wid="`xdotool getactivewindow`"
logthis "current_active_wid=${current_active_wid}"

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
  if [ -n "${PID}" ]; then
      window_to_activate="`xdotool search --pid ${PID} --sync`"
  else
    window_to_activate="`xdotool search --classname \"${wname}\" | tail -1`"
    if [ -z "${window_to_activate}" ]; then
         window_to_activate="`xdotool search --name \"${wname}\" | tail -1 `"
      fi
  fi
  logthis "window_to_activate=${window_to_activate}" 
  if [ -n "${window_to_activate}" ]
  then 
    RET=`xdotool windowactivate "${window_to_activate}" 2>&1 | grep "failed"`
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

filter_alive(){
  while read i; do
      activ="`xprop -id ${i}  | grep '_NET_WM_DESKTOP' `"
      if [ "${activ}" ]; then
          echo ${i}
      fi
  done
}

select_other_window(){
  grep -v "${current_active_wid}" | while read i; do
      xprops="`xprop -id ${i}  | egrep '_NET_WM_DESKTOP|_MOTIF_WM_HINTS' `"
      activ="`echo \"${xprops}\"  | grep '_NET_WM_DESKTOP' `"
      bar="`echo \"${xprops}\"  | grep '_MOTIF_WM_HINTS' `"
      if [ "${activ}" -a -z "${bar}" ]; then
          echo ${i}
      fi
  done | tail -1
}

select_window(){
  while read i; do
      xprops="`xprop -id ${i}  | egrep '_NET_WM_DESKTOP|_MOTIF_WM_HINTS' `"
      activ="`echo \"${xprops}\"  | grep '_NET_WM_DESKTOP' `"
      bar="`echo \"${xprops}\"  | grep '_MOTIF_WM_HINTS' `"
      if [ "${activ}" -a -z "${bar}" ]; then
          echo ${i}
      fi
  done | tail -1
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
    --place|-p|-pc)
      if [ "$1" = "-pc" ]; then percent_place="$1"; fi
      change_coord="$1"
      if [ "${percent_place}" ]; then
        coordx=`echo $2 | sed 's/%\?$/%/'`
        coordy=`echo $3 | sed 's/%\?$/%/'`
        sizew=`echo $4 | sed 's/%\?$/%/'`
        sizeh=`echo $5 | sed 's/%\?$/%/'`
      else
        coordx=`echo $2 | sed 's/^0$/0%/'`
        coordy=`echo $3 | sed 's/^0$/0%/'`
        sizew=`echo $4 | sed 's/^0$/0%/'`
        sizeh=`echo $5 | sed 's/^0$/0%/'`
      fi
      shift 5
      ;;
    --percent)
      percent_place="$1"
      shift 1
      ;;
    --move|-m|-mc)
      if [ "$1" = "-mc" ]; then percent_place="$1"; fi
      force_resize="1"
      change_coord="$1"
      if [ "${percent_place}" ]; then
        coordx=`echo $2 | sed 's/%\?$/%/'`
        coordy=`echo $3 | sed 's/%\?$/%/'`
        sizew=`echo $4 | sed 's/%\?$/%/'`
        sizeh=`echo $5 | sed 's/%\?$/%/'`
      else
        coordx=`echo $2 | sed 's/^0$/0%/'`
        coordy=`echo $3 | sed 's/^0$/0%/'`
        sizew=`echo $4 | sed 's/^0$/0%/'`
        sizeh=`echo $5 | sed 's/^0$/0%/'`
      fi
      shift 5
      ;;
    --no-exec|-n)
      noexec="1"
      shift
      ;;
    --list|-l)
      # example : ./switch_to.sh -l '\.t\..*\.'
      if [ "$2" ]; then
        pattern="${2}"
        shift 2
      else
        pattern="."
        shift 1
      fi
      # current="`xdotool getactivewindow`"
      echo "${LISTHEADER}"
      xdotool search ${onlyvisible} --name "${pattern}" | filter_alive \
         | while read i
    do
      status="`xprop -id ${i} | egrep '_NET_WM_NAME|WM_CLASS|_MOTIF_WM_HINTS'`"
      progclass="`echo \"${status}\" | grep 'WM_CLASS' | cut -d'=' -f2- | sed 's/\"//g;s/\s\+//g'`"
      progname="`echo \"${status}\" | grep '_NET_WM_NAME' | cut -d'=' -f2- | sed 's/\s*\"\(.*\)\"\s*/\1/'`"
      hinted="`echo \"${status}\"  | grep '_MOTIF_WM_HINTS' `"
      PID="`xdotool getwindowpid ${i}`"
      format="${FORMATLIST}"
      if [ "${current_active_wid}" = "${i}" ];then
        format="${FORMATLISTACTIV}"
      fi
      if [ "${hinted}" ]; then
         i="_${i}"
      fi
      printf "${format}" "${i}" "${PID}" "${progclass}" "${progname}"
    done
    list="1"
    ;;
  --next|-next|-ln)
    # same as above but switch on first encountered
    # example : ./switch_to.sh -ln '\.t\..*\.'
    if [ "$2" ]; then
      pattern="${2}"
      shift 2
    else
      pattern="."
      shift 1
    fi
    echo "${LISTHEADER}"
    xdotool search ${onlyvisible} --name "${pattern}" \
      | select_other_window \
      | while read i
  do
    status="`xprop -id ${i} | egrep '_NET_WM_NAME|WM_CLASS'`"
    progclass="`echo \"${status}\" | grep 'WM_CLASS' | cut -d'=' -f2- `"
    progname="`echo \"${status}\" | grep '_NET_WM_NAME' | cut -d'=' -f2- `"
    PID="`xdotool getwindowpid ${i}`"
    printf "${FORMATLIST}" "${i}" "${PID}" "${progclass}" "${progname}"
    xdotool windowactivate ${i}
    break
  done
  next="1"
  ;;
*)
  break
  ;;
esac
done

if [ "${list}${next}" ]; then exit 0;fi

### Processing
# last 2 args : Window name and program
wname="$1"

if [ "${wname}" ];then
  shift
  wprog=""
  while [ "$1" ]
  do
    #  logthis "Param	: $1"
    echo "$1" | grep ' ' > /dev/null \
      && wprog="${wprog} \"`echo "${1}" | sed 's/"/\\\"/g'`\"" \
      || wprog="${wprog} ${1}"
    shift
  done
  [ "${termmode}" ] && wname="${termprefix}${wname}${termsuffix}"
  if [ -n "${wprog}" -a -z "${noexec}" ];  then
    #  logthis "Orig cmd	: ${wprog}"
    wprog="`echo \"${wprog}\" | sed \"s/%title/\\\"${wname}\\\"/g\"`"
  else
    [ "${termmode}" ] && wprog="`open_nammed_terminal ${wname}`" || wprog="${wname}"
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
  fi
  activate_window || \
    window_to_activate="`xdotool search  ${onlyvisible} -classname \"${wname}\" | select_window`" \
    activate_window || \
    window_to_activate="`xdotool search  ${onlyvisible} -name \"${wname}\" | select_window`" \
    activate_window || \
    test -n "${noexec}" || new_window && new_win=true

  LAST_ACTIVE_WID="${current_active_wid}"

  ## export globals ###
  if [ -z "${noexec}" ]; then
    echo "${LAST_ACTIVE_WID}" > ${LAST_ACTIVE_WID_file}
  fi
elif [ "${noexec}" ]; then
  # if no parameter, process the current window
  window_to_activate="${current_active_wid}"
else
  echo "No window name provided. Exit." && exit 1
fi

if [ "${new_win}${force_resize}" -a "${not_back}" -a "${change_coord}" -a "${window_to_activate}" ]; then
  # activation is required for gnome-shell # bug ?
  xdotool windowactivate ${window_to_activate}
  #
  xdotool windowsize ${window_to_activate} ${sizew} ${sizeh}
  xdotool windowmove ${window_to_activate} ${coordx} ${coordy}
fi
#####################

