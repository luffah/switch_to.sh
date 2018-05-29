deps:
	sh ./install/deps.sh

test:
	sh ./switch_to.sh -d .1 -pcu 0 50 50 50 -t "Testing script switch_to.sh"  \
 xterm -e 'sleep 0.8; echo Testing window placement;sleep 5; echo Testing window list; sh ./switch_to.sh -l . ; echo Now the installation can start;sleep 2' && \
	sleep .4 && \
 sh ./switch_to.sh -m 50% 50% 50% 50% -n -t "Testing script switch_to.sh" && \
	sleep .4 && \
 sh ./switch_to.sh -mc 0 50 50 50 -n -t "Testing script switch_to.sh" && \
 sleep .4 && \
 sh ./switch_to.sh -rd -t "Testing script switch_to.sh" && sleep 4
 

install:deps test
	sudo cp ./switch_to.sh /usr/local/bin/switch_to.sh
	sudo chmod 755 /usr/local/bin/switch_to.sh

uninstall:
	sudo rm -i /usr/local/bin/switch_to.sh
