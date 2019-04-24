ifndef TARGETDIR
  TARGETDIR=/usr/local/bin
endif

ifndef TARGET
  TARGET=${TARGETDIR}/switch_to.sh
endif

DO=
ifeq (${USER},$(stat -c "%U" -d ${TARGET}))
	DO=sudo
endif

default: help

deps: ## Install dependencies
	which xdotool || ${DO} apt install xdotool

test: ## Run a test with a xterm window
	sh ./switch_to.sh -d .1 -pcu 0 0 50 50 -t "Testing script switch_to.sh"  \
 xterm -e 'sleep 0.8; echo Testing window placement;sleep 1; echo Testing window list; sh ./switch_to.sh -l . ; echo Now the installation can start;sleep 2' && \
	sleep .2 && \
 sh ./switch_to.sh -m 0 11% -n -t "Testing script switch_to.sh" && \
	sleep .2 && \
 sh ./switch_to.sh -m 0 22% -n -t "Testing script switch_to.sh" && \
	sleep .2 && \
 sh ./switch_to.sh -m 0 33% -n -t "Testing script switch_to.sh" && \
	sleep .2 && \
 sh ./switch_to.sh -i -mc 0 50 50 50 -n -t "Testing script switch_to.sh" && \
 sleep .2 && \
 sh ./switch_to.sh -mc 50 50 50 50 -n -t "Testing script switch_to.sh" && \
 sleep .2 && \
 sh ./switch_to.sh -mc 50 0 50 50 -n -t "Testing script switch_to.sh" && \
 sleep .2 && \
 sh ./switch_to.sh -mc 0 0 50 50 -n -t "Testing script switch_to.sh" && \
 sleep .2 && \
 sh ./switch_to.sh -mc 0 50 50 50 -i -rd -t "Testing script switch_to.sh" && sleep 2
 

install_py: ## install py version to ${TARGETDIR} (/usr/local/bin/)
	${DO} cp --preserve=mode ./switch_to.py ${TARGETDIR}/
	
install:deps test ## install to ${TARGET} (/usr/local/bin/)
	${DO} cp  --preserve=mode ./switch_to.sh ${TARGET}
	
uninstall: ## uninstall from ${TARGET} (/usr/local/bin/)
	${DO} rm -i ${TARGET}

help: ## Show this help
	@sed -n \
	 's/^\(\([a-zA-Z_-]\+\):.*\)\?#\(#\s*\([^#]*\)$$\|\s*\(.*\)\s*#$$\)/\2=====\4=====\5/p' \
	 $(MAKEFILE_LIST) | \
	 awk 'BEGIN {FS = "====="}; {printf "\033[1m%-4s\033[4m\033[36m%-14s\033[0m %s\n", $$3, $$1, $$2 }' | \
	 sed 's/\s\{14\}//'
