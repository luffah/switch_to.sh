deps:
	sh ./install/deps.sh

test:
	sh ./switch_to.sh -d .1 -p 0 0 50% 50% -t "Testing script switch_to.sh"  \
 xterm -T %title  -e 'sleep 0.3; echo The test is ok;sleep 1; echo Now the installation can start;sleep 1'
	sleep .4 && \
 sh ./switch_to.sh -m 50% 50% 50% 50% -n -t "Testing script switch_to.sh"

install:deps test
	sudo cp ./switch_to.sh /usr/local/bin/switch_to.sh
	sudo chmod 755 /usr/local/bin/switch_to.sh

uninstall:
	sudo rm -i /usr/local/bin/switch_to.sh

