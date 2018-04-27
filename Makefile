deps:
	sh ./install/deps.sh

test:
	sh ./switch_to.sh -d .1 -pc 0 0 50% 50% -t "Testing script switch_to.sh"  \
 xterm -T %title  -e 'sleep 0.3; echo Testing window placement;sleep 1; echo Testing window list; sh ./switch_to.sh -l . ; echo Now the installation can start;sleep 2'
	sleep .4 && \
 sh ./switch_to.sh -m 50% 50% 50% 50% -n -t "Testing script switch_to.sh" && \
	sleep .4 && \
 sh ./switch_to.sh -mc 50 0 50 50 -n -t "Testing script switch_to.sh"

install:deps test
	sudo cp ./switch_to.sh /usr/local/bin/switch_to.sh
	sudo chmod 755 /usr/local/bin/switch_to.sh

uninstall:
	sudo rm -i /usr/local/bin/switch_to.sh
