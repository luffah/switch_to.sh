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
logfile="/dev/stderr"
# Put something inside DEBUG to have logs
DEBUG=""

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
force_name=""
force_compatible_term=""
undecorate=""
redecorate=""
noexec=""
activation_delay="0.6"

### Globals processing variables ###
win_found=""
not_back="1"
window_to_activate=""
current_active_wid=""
LAST_ACTIVE_WID=""
# onlyvisible="--onlyvisible"
onlyvisible=""
invert_colors=""
switch_to_window="True"
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
  echo """${grt}Usage${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> ${rs}
     ${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> <app_cmd>${rs}
     ${gre} :${rs} ${mag}`basename $0` ${yel}${rs}[${yol}<options>${rs}]${yel} <app_name> ${rs}[${yel}<app_cmd>${rs}]
     ${gre} :${rs} ${mag}`basename $0` ${rs}[${yol}-m${rs} ${yel}<x> <y> <w> <h>${rs}] [${yol}-t${rs}]${yel}  <app_name> ${rs}[${yel}<app_cmd>${rs}]

${grt}Arguments${rs} :
 ${yel}<app_name>${rs}	either executable, window title or window class
           	-> shall be a quoted string if it contains any space

 ${yel}<app_cmd>${rs}	command line for launching the application
          	-> can contain ${yel}%title${rs} which will be remplaced by
          	   the window title (${yel}<app_name>${rs} or
          	   the title computed when using option ${yol}-t${rs})

${grt}Options${rs} :
 ${yol}-n ${rs}|${yol}--no-exec${rs}	don't create any new window
 ${yol}-t ${rs}|${yol}--terminal${rs}	auto name a terminal \"${termprefix}<app_name>${termsuffix}
 ${yol}-tp${rs}|${yol}--terminal-prefix${rs}	change the terminal prefix (\"${termprefix}\")
 ${yol}-ts${rs}|${yol}--terminal-suffix${rs}	change the terminal suffix (\"${termsuffix}\")
 ${yol}-m ${rs}|${yol}--move${rs}	${yel}<x> <y> <w> <h>${rs}
          ${rs}	move/resize (X,Y,width,height e.g. 0 50% 50% 100%)
 ${yol}-ud${rs}|${yol}--undecorate${rs}	remove decoration
 ${yol}-rd${rs}|${yol}--decorate${rs}	restore decoration

${grt}Options which only apply for a new window${rs} :
 ${yol}-p ${rs}|${yol}--place${rs}	move/resize (X,Y,width,height e.g. 0 50% 50% 100%)
 ${yol}-d ${rs}|${yol}--delay${rs}	delay in seconds before switching to or resizing the window (${activation_delay})
 ${yol}-u ${rs}|${yol}--undecorated${rs}	remove decoration on a new window

${grt}Tools${rs} :
 ${yol}-l ${rs}|${yol}--list${rs}	list windows (with optionnal pattern)${rs}
 ${yol}-ln${rs}|${yol}--next${rs}	jump to next window (with optionnal pattern)${rs}

${grt}Tricky options${rs} :
 ${yol}--percent${rs}	[before ${yol}--move${rs} or ${yol}--place${rs}] force coordonates in percent
 ${yol}-mc${rs}|${yol}-pc${rs}	short options for '${yol}--percent --move${rs}' and '${yol}--percent --place${rs}'
 ${yol}-mcu${rs}|${yol}-pcu${rs}	like '${yol}-mc${rs}' and '${yol}-pc${rs}' with '${yol}--undecorated${rs}'
"""
  exit 1
fi

logthis "Args	: $*"

current_active_wid="`xdotool getactivewindow`"
logthis "current_active_wid=${current_active_wid}"

# If -t option is used, then you need a terminal definition which have -T (-title( option)
defterm=`readlink /etc/alternatives/x-terminal-emulator | xargs basename`

new_window(){
  RET="failed"
  eval "WINDOW_NAME=\"${wname}\" ${wprog} &" && PID=$! || return "failed"
  logthis "PID=${PID}"
  # wait the programm to change pid ...
  sleep ${activation_delay}
  if ! ps -p $PID > /dev/null; then
    PID=""
  fi
  window_to_activate=''
  if [ -n "${PID}" ]; then
    window_to_activate=`xdotool search --pid ${PID} | sort -r`
    if [ -z "${window_to_activate}" ];then
      sleep ${activation_delay}
   else
     # more complex is the process, more we need to wait
     # if only one, no need to wait.... then wait nb windows-1
     for i in ${window_to_activate#* };do
       sleep ${activation_delay}
     done
    fi
  fi
  if [ -z "${window_to_activate}" ];then
    window_to_activate=`xdotool search --classname "${wname}" | sort -r`
    if [ -z "${window_to_activate}" ]; then
      window_to_activate=`xdotool search --name "${wname}"  | sort -r`
    fi
    # fall back on search prog
    if [ -z "${window_to_activate}" ]; then
      progname="`echo $wprog | cut -f1`"
      window_to_activate=`xdotool search --class "${progname}" | sort -r`
    fi
  fi
  logthis "window_to_activate=${window_to_activate}"
  for i in ${window_to_activate};do
    RET=`xdotool windowactivate "${i}" 2>&1 | grep "failed"`
    if [ -z "${RET}" ];then
      if [ -n "${force_name}" -a -n "${window_to_activate}" ];then
        logthis "force WM_NAME"
        xprop -id ${window_to_activate} -set WM_NAME "${wname}"
      fi
      window_to_activate=$i
      break
    fi
  done
  
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
  if [ -n "${window_to_activate}" -a "${switch_to_window}" ]
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
  grep -v "${current_active_wid}" | select_window
}

select_window(){
  while read i; do
      xprops="`xprop -id ${i}  | egrep '_NET_WM_DESKTOP|_NET_WM_WINDOW_TYPE' `"
      activ="`echo \"${xprops}\"  | grep '_NET_WM_DESKTOP' `"
      isdock="`echo \"${status}\"  | grep '_NET_WM_WINDOW_TYPE_DOCK' `"
      if [ "${activ}" -a -z "${isdock}" ]; then
          echo ${i}
      fi
  done | tail -1
}

### Arguments parsing ###
while true; do
  # echo $*
  case "$1" in 
    --terminal|-t|-ut|-tu)
      if [ "`echo $1 | grep u`" ]; then
        undecorate="$1"
        undecorate_new_win="$1"
      fi
      termmode="$1"
      force_name="$1"
      ;;
    --delay|-d)
      if [ -n "${2}" ]; then
        activation_delay="$2"
        shift
      fi
      ;;
    --terminal-prefix|-tp|-tpu)
      if [ "`echo $1 | grep u`" ]; then
        undecorate="$1"
        undecorate_new_win="$1"
      fi
      termmode="$1"
      termprefix="$2"
      force_name="$1"
      shift
      ;;
    --place)
      coordx=`echo $2 | sed 's/^0$/0%/'`
      coordy=`echo $3 | sed 's/^0$/0%/'`
      sizew=`echo $4 | sed 's/^0$/0%/'`
      sizeh=`echo $5 | sed 's/^0$/0%/'`
      shift 3
      ;;
    -p*)
      if [ "`echo $1 | grep c`" ]; then percent_place="$1"; fi
      if [ "`echo $1 | grep u`" ]; then
        undecorate="$1"
        undecorate_new_win="$1"
      fi
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
      shift 4
      ;;
    --undecorated|-u)
      undecorate="$1"
      undecorate_new_win="$1"
      ;;
    --undecorate|-ud)
      noexec="$1"
      undecorate="$1"
      ;;
    --decorate|--redecorate|-rd)
      noexec="$1"
      redecorate="$1"
      ;;
    --percent)
      percent_place="$1"
      ;;
    --move|-m*)
      if [ "`echo $1 | grep c`" ]; then percent_place="$1"; fi
      if [ "`echo $1 | grep u`" ]; then undecorate="$1"; fi
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
      shift 4
      ;;
    --no-exec|-n)
      noexec="1"
      ;;
    --list|-l)
      # example : ./switch_to.sh -l '\.t\..*\.'
      if [ "$2" ]; then
        pattern="${2}"
        shift
      else
        pattern="."
      fi
      # current="`xdotool getactivewindow`"
      echo "${LISTHEADER}"
      xdotool search ${onlyvisible} --name "${pattern}" | filter_alive \
        | while read i; do
        # _MOTIF_WM_HINTS says window is decorated or not
        # status="`xprop -id ${i} | egrep '_NET_WM_NAME|WM_CLASS|_MOTIF_WM_HINTS|_NET_WM_WINDOW_TYPE`"
        status="`xprop -id ${i} | egrep '_NET_WM_NAME|WM_CLASS|_MOTIF_WM_HINTS|_NET_WM_WINDOW_TYPE'`"
        progclass="`echo \"${status}\" | grep 'WM_CLASS' | cut -d'=' -f2- | sed 's/\"//g;s/\s\+//g'`"
        progname="`echo \"${status}\" | grep '_NET_WM_NAME' | cut -d'=' -f2- | sed 's/\s*\"\(.*\)\"\s*/\1/'`"
        isdock="`echo \"${status}\"  | grep '_NET_WM_WINDOW_TYPE_DOCK' `"
        PID="`xdotool getwindowpid ${i}`"
        format="${FORMATLIST}"
        if [ "${current_active_wid}" = "${i}" ];then
          format="${FORMATLISTACTIV}"
        fi
        if [ "${isdock}" ]; then
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
      shift
    else
      pattern="."
    fi
    echo "${LISTHEADER}"
    xdotool search ${onlyvisible} --name "${pattern}" \
      | select_other_window \
      | while read i; do
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
  -i|--invert)
    invert_colors="true"
    ;;
  -ns)
    noexec="1"
    switch_to_window=""
    ;;
  *)
    break
    ;;
  esac
  shift
done

if [ "${list}${next}" ]; then exit 0;fi

### Processing
# last 2 args : Window name and program
wname="$1"
   
####     /      /
####    '.----.'
####   .' 0  0 '.
####    |  ..  | 
####  .'-. o  .-'.
####  \   '..'   /
#### Now, we got all parameters, exept the command to launch
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
  if [ -z "${noexec}" ]; then
    if [ -n "${wprog}" ];  then
      logthis "Orig cmd: ${wprog}"
      wprog="`echo \"${wprog}\" | sed \"s/%title/\\\"${wname}\\\"/g\"`"
    elif [ "${termmode}" ]; then
      logthis "Term mode: ${termmode}"
      if [ "${force_compatible_term}" ]; then
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
      fi
      case ${defterm} in
        st)
          opt="-t \"${wname}\" -c ${wname}"
          ;;
        lxterminal|mate-terminal|xterm)
          opt="-T \"${wname}\""
          ;;
      esac
      logthis "Using -- ${defterm} ${opt} --"
      wprog="${defterm} ${opt}"
    else
      wprog="${wname}"
    fi
  fi
  logthis "Name     : ${wname}"
  logthis "Command  : ${wprog}"
  ####       __
  ####   .-.'__'.-.
  #### .'..'    '..'.
  ####(  |  0  0  |  )
  #### >-|        |-<  
  ####(  |  *..*  |  )
  #### '-.'.____.'.-'
  ####   '--'||'--'    
  #### all the parameters are defined 
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
    test -n "${noexec}" || new_window && new_win=1

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

####     llllll   
####  llllllllllll
####   .' 0, 0 '.
####   ( *.__.* ) 
####  .'-.____.-'.
#### /     |      \
#### Window to activate is now found 

if [ "${undecorate_new_win}" ];then
  if [ -z "${new_win}" -o -z "${undecorate}" ];then
    undecorate=""
  fi
fi
if [ -n "${undecorate}" -a -n "${window_to_activate}" ];then
  xprop -id ${window_to_activate} -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS '0x2, 0x0, 0x0, 0x0, 0x0'
fi

if [ -n "${redecorate}" -a -n "${window_to_activate}" ];then
  xprop -id ${window_to_activate} -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS '0x2, 0x0, 0x1, 0x0, 0x0'
  test -n "${noexec}" && exit
fi

if [ -n "${new_win}${force_resize}" -a -n "${not_back}" -a -n "${change_coord}" -a -n "${window_to_activate}" ]; then
  # activation is required for gnome-shell # bug ?
  xdotool windowactivate ${window_to_activate}
  #
  xdotool windowsize ${window_to_activate} ${sizew} ${sizeh}
  xdotool windowmove ${window_to_activate} ${coordx} ${coordy}
fi

if [ "${invert_colors}" ]; then
  if [ "$(pidof compton)" ]; then
    pkill compton
  else
    pkill compton
    CLASS=$(xprop -id "${window_to_activate}"  | grep "WM_CLASS" | awk '{print $4}')
    COND="class_g=${CLASS}"
    compton --invert-color-include "$COND" &
  fi
fi
#####################

