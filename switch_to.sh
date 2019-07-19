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
###
###  Last Update : 07.06.2018

### extra functionnalities require compton and dmenu

logfile="/dev/stderr"
# Put something inside DEBUG to have logs
DEBUG="${DEBUG:-}"

logthis(){
	[ -n "${DEBUG}" ] && echo "`date` $*" >> ${logfile}
}

which xdotool > /dev/null
if [ "$?" -gt 0 ]; then
  echo "Missing 'xdotool' to run this script"
  exit 1
fi

getch() {
  old=$(stty -g)
  stty raw -echo min 0 time 100
  printf '%s' $(dd bs=16 count=1 2>/dev/null)
  stty $old
}
prompt(){
   printf "%s\r" "${rev} Press a key to continue or 'q' to quit.${rs}"
   ch=`getch`
     printf "%s\r" "                                               "
   if [ "${ch}" = 'q' ]; then
     echo
     exit 0
   fi
}
usage(){
  setup_colors
  echo """${grt}Usage${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> ${rs}
     ${gre} :${rs} ${mag}`basename $0` ${yel} <app_name> <app_cmd>${rs}
     ${gre} :${rs} ${mag}`basename $0` ${yel}${rs}[${yol}<options>${rs}] [${yol}-t${rs}]${yel} <app_name> ${rs}[${yel}<app_cmd>${rs}]
     ${gre} :${rs} ${mag}`basename $0` ${rs}${yol}-l${rs} <app_name>
     ${gre} :${rs} ${mag}`basename $0` ${rs}${yol}--dmenu${rs}
"""
   prompt
   echo """${grt}Options${rs} :
 ${yol}-n ${rs}|${yol}--no-exec${rs}	don't create any new window
 ${yol}-t ${rs}|${yol}--terminal${rs}	auto name a terminal \"${termprefix}<app_name>${termsuffix}
 ${yol}-m ${rs}|${yol}--move${rs}    	${yel}<x> <y> <w> <h>${rs}
 ${yol}-ns${rs}            	don't switch${rs}
"""
   prompt
   echo """${grt}Options which only apply for a new window${rs} :
 ${yol}-p ${rs}|${yol}--place${rs}	${yel}<x> <y> <w> <h>${rs}
 ${yol}-d ${rs}|${yol}--delay${rs}	a delay for heavy applications (${activation_delay})
 ${yol}-u ${rs}|${yol}--undecorated${rs}	disable decoration 
"""
   prompt
   echo """${grt}Arguments${rs} :
 ${yel}<app_name>${rs}
 either executable, window title or window class
 -> shall be a quoted string if it contains any space

 ${yel}<app_cmd>${rs}
 command line for launching the application
 -> can contain ${yel}%title${rs} which will be remplaced by
    the window title (${yel}<app_name>${rs} or
    the title computed when using option ${yol}-t${rs})

 ${yel}<x> <y> <w> <h>${rs}
 positionX positionY width height.
 Example value : 0 50% 50% 100%
"""
   prompt
   echo """${grt}Tricky options${rs} :
 ${yol}--percent --move${rs}|${yol}--percent --place${rs}
 ${yol}-mc${rs}|${yol}-pc${rs}	${yel}<x> <y> <w> <h>${rs}
 ${yol}-mcu${rs}|${yol}-pcu${rs}
	-> use percentage instead of pixel
  -> adding 'c' is equivalent to '${yol}--percent${rs}'
  -> adding 'u' is equivalent to '${yol}--undecorated${rs}'
"""
   prompt
   echo """${grt}Do not use${rs} :
    ${yol}--dmenu${rs} or ${yol}--jumpback${rs}
 or ${yol}-l ${rs}|${yol}--list${rs} or ${yol}-ln${rs}|${yol}--next${rs}
 or ${yol}-i${rs}
 or ${yol}-ud${rs}|${yol}--undecorate${rs} or ${yol}-rd${rs}|${yol}--decorate${rs}
 or ${yol}-tp${rs}|${yol}--terminal-prefix${rs} or ${yol}-ts${rs}|${yol}--terminal-suffix${rs}
"""
   prompt
   echo """${grt}Examples${rs} :
${mag}`basename $0` ${yol}gvim${rs}
${mag}`basename $0` ${yol}gvim ${yel}gvim -u NONE${rs}
${mag}`basename $0` ${yol}-t ${yel}ret${rs}
${mag}`basename $0` ${yol}-pc ${yel}50 0 50 100 ${yol}-t ${yel}ret${rs}
${mag}`basename $0` ${yol}-l firefox${rs}
"""
   prompt
   cat <<EOF
Thanks for reading the help of switch_to.sh.
EOF
}

setup_colors(){
  grt=`tput setaf 2; tput bold; tput smul`
  gre=`tput setaf 2; tput bold; tput rmul`
  rev=`tput bold; tput rev; tput setab 0`
  mag=`tput setaf 5`
  yel=`tput setaf 3`
  yol=`tput setaf 6`
  rs=`tput sgr0`
}

setup_styles(){
  setup_colors
  # format options
  FWID='%-9s'
  FPID='%-6s'
  if [ "${SHORT_THEME}" ]; then
  FCLASS='%-21.21s'
  FTITLE='%-21.21s'
  else
  FCLASS='%-21s'
  FTITLE='%-21s'
  fi
  if [ "${NO_THEME}" ]; then
    FORMATLIST="${FWID} ${FPID} ${FCLASS} ${FTITLE}\n"
    FORMATLISTACTIV="${FWID} ${FPID} ${FCLASS} ${FTITLE}\n"
    LISTHEADER='NONE'
  else
    FORMATLIST="${mag}${FWID} ${rs}${gre} ${FPID}${rs}${yol} ${FCLASS} ${rs}${yel} ${FTITLE}${rs}\n"
    FORMATLISTACTIV="${mag}${rev}${FWID} ${rs}${gre}${rev} ${FPID} ${rs}${yol}${rev} ${FCLASS} ${yel}${rev} ${FTITLE} ${rs}\n"
  fi
  if [ "$LISTHEADER" != "NONE" ]; then
    if [ -z "$LISTHEADER" ];then
      LISTHEADER="`printf \"${FORMATLISTACTIV}\" WINDOWID PID WM_CLASS WM_NAME`"
    fi
  else
    LISTHEADER=''
  fi
}
logthis "Args	: $*"


new_window(){
  RET="failed"
  eval "TERM= WINDOW_NAME=\"${wname}\" ${wprog} &" && PID=$! || return "failed"
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
  
  test -z "${RET}" && new_win=1
}

activate_window(){
  if [ -z "${window_to_activate}" ]
  then
    return 1
  fi
  logthis "def window_to_activate=${window_to_activate}" 
  if [ -z "${force_resize}" -a "${current_active_wid}" = "${window_to_activate}" ]
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

parse_place(){
  ret=0
  test -n "`echo $2 | sed -n '/^-\?[0-9]\+%\?$/p'`" && ret=1 && \
  test -n "`echo $3 | sed -n '/^-\?[0-9]\+%\?$/p'`" && ret=2 && \
  test -n "`echo $4 | sed -n '/^-\?[0-9]\+%\?$/p'`" && ret=3 && \
  test -n "`echo $5 | sed -n '/^-\?[0-9]\+%\?$/p'`" && ret=4 

  if [ "${percent_place}" ]; then
    test ${ret} -ge 1 && coordx=`echo $2 | sed 's/%\?$/%/'`
    test ${ret} -ge 2 && coordy=`echo $3 | sed 's/%\?$/%/'`
    test ${ret} -ge 3 && sizew=`echo $4 | sed 's/%\?$/%/'`
    test ${ret} -ge 4 && sizeh=`echo $5 | sed 's/%\?$/%/'`
  else
    test ${ret} -ge 1 && coordx=`echo $2 | sed 's/^0$/0%/'`
    test ${ret} -ge 2 && coordy=`echo $3 | sed 's/^0$/0%/'`
    test ${ret} -ge 3 && sizew=`echo $4 | sed 's/^0$/0%/'`
    test ${ret} -ge 4 && sizeh=`echo $5 | sed 's/^0$/0%/'`
  fi
  return $ret
}

### Parameters variables ###
unset termode defterm force_resize force_name force_compatible_term undecorate redecorate noexec new_win LAST_ACTIVE_WID invert_colors window_to_activate win_found
termprefix=".t."
termsuffix="."
activation_delay="0.6"
not_back="1"
current_active_wid="`xdotool getactivewindow`"
switch_to_window="True"

logthis "current_active_wid=${current_active_wid}"
### script options ###
# onlyvisible="--onlyvisible"
onlyvisible=""

### Arguments parsing ###
### If no parameter then show help
if [ -z "$1" -o "$1" = "-h" ]
then
  usage
  exit 1
fi

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
    --place)
      parse_place $1
      shift $?
      ;;
    --percent)
      percent_place="$1"
      ;;
    -p*)
      if [ "`echo $1 | grep c`" ]; then percent_place="$1"; fi
      if [ "`echo $1 | grep u`" ]; then
        undecorate="$1"
        undecorate_new_win="$1"
      fi
      parse_place $*
      shift $?
      ;;
    --move|-m*)
      if [ "`echo $1 | grep c`" ]; then percent_place="$1"; fi
      if [ "`echo $1 | grep u`" ]; then undecorate="$1"; fi
      force_resize="$1"
      parse_place $*
      shift $?
      ;;
    --no-exec|-n)
      noexec="1"
      ;;
    --jumpback)
      if [ "${current_active_wid}" ]; then
        LAST_ACTIVE_WID_ID_file="/tmp/LAST_${current_active_wid}"
        if [ -f "${LAST_ACTIVE_WID_ID_file}" ]; then
          LAST_ACTIVE_WID="`[ -f ${LAST_ACTIVE_WID_ID_file} ] && cat \"${LAST_ACTIVE_WID_ID_file}\"`" 
          LAST_ACTIVE_WID_ID_file="/tmp/LAST_${LAST_ACTIVE_WID}"
          xdotool windowactivate ${LAST_ACTIVE_WID} && \
            echo "${current_active_wid}" > ${LAST_ACTIVE_WID_ID_file}
        fi
      fi
      next=1
      ;;
    --dmenu)
      # require dmenu with multiline support (command line flag -l)
      id=`NO_THEME=1 $0 -l | dmenu -i -l -10 -p "$name"` \
      && xdotool windowactivate ${id%% *}
      if [ "${id%% *}" ]; then
        LAST_ACTIVE_WID_ID_file="/tmp/LAST_${id%% *}"
        echo "${current_active_wid}" > ${LAST_ACTIVE_WID_ID_file}
      fi
      next=1
      ;;
    --list|-l)
      # example : ./switch_to.sh -l '\.t\..*\.'
      if [ "$2" ]; then
        pattern="${2}"
        shift
      else
        pattern="."
      fi
      setup_styles
      # current="`xdotool getactivewindow`"
      test -n "${LISTHEADER}" && echo "${LISTHEADER}"
      xdotool search ${onlyvisible} --name --class "${pattern}" | filter_alive \
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
    setup_styles
    test -n "${LISTHEADER}" && echo "${LISTHEADER}"
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
-fs|--fulscreen)
  maximized="1"
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
  if [ "${termmode}" ];then
    # If -t option is used, then you need a terminal definition which have -T (-title( option)
    defterm=`readlink /etc/alternatives/x-terminal-emulator | xargs basename`
    wname="${termprefix}${wname}${termsuffix}"
  fi
  if [ -z "${noexec}" ]; then
    if [ -n "${wprog}" ];  then
      logthis "Orig cmd: ${wprog}"
      wprog="`echo \"${wprog}\" | sed \"s/%title/\\\"${wname}\\\"/g\"`"
    elif [ "${termmode}" ]; then
      logthis "Term mode: ${termmode}"
      if [ "${force_compatible_term}" ]; then
        case ${defterm} in
          lxterminal|st|mate-terminal*|xterm|xfce4-terminal*);;
          *)
            ok="`${defterm} --help 2> /dev/null | grep -- -T`"
            if [ -z "${ok}" ]
            then
              which st && defterm=st || \
                which xfce4-terminal && defterm=xfce4-terminal  || \
                which lxterminal && defterm=lxterminal  || \
                which mate-terminal && defterm=mate-terminal || \
                which xterm && defterm=xterm
            fi > /dev/null
            ;;
        esac
      fi
      case ${defterm} in
        st)
          opt="-t \"${wname}\" -c ${wname}"
          ;;
        mate-terminal*)
          opt="-t \"${wname}\""
          ;;
        *)
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
    LAST_ACTIVE_WID_file="/tmp/LAST_$(echo "${wname}" | tr -d '\\ /')_WID"
    LAST_ACTIVE_WID="$([ -f ${LAST_ACTIVE_WID_file} ] && cat "${LAST_ACTIVE_WID_file}")"
    ####
  fi
  wname_re="$(echo "${wname}" | sed 's/\([.*]\)/\\\1/g')"
  # activate_window || \
  window_to_activate="$(xdotool search  ${onlyvisible} --class "${wname_re}" | select_window)" \
    activate_window || \
    window_to_activate="$(xdotool search  ${onlyvisible} --name "${wname_re}" | select_window)" \
    activate_window || \
    test -n "${noexec}" || new_window
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

if [ "${window_to_activate}" ]; then
  LAST_ACTIVE_WID_ID_file="/tmp/LAST_${window_to_activate}"
  echo "${LAST_ACTIVE_WID}" > ${LAST_ACTIVE_WID_ID_file}
fi

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
fi

if [ -n "${new_win}${force_resize}" -a -n "${not_back}" -a -n "${coordx}${coordy}${sizew}${sizeh}" -a -n "${window_to_activate}" ]; then
  # activation is required for gnome-shell # bug ?
  xdotool windowactivate ${window_to_activate}
  #
  if [ "${coordx}${coordy}" ];then
     xdotool windowmove ${window_to_activate} ${coordx} ${coordy}
  fi
  if [ "${sizew}${sizeh}" ];then
     xdotool windowsize ${window_to_activate} ${sizew} ${sizeh}
  fi
fi

if [ -n "${new_win}" -a -n "${maximized}" ]; then
  wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz 2> /dev/null
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

