deps:
	sh ./install/deps.sh

test:
	sh ./switch_to.sh -t "Testing script switch_to.sh"  \
	xterm -T %title -e 'sleep 0.3; echo The test is ok;sleep 1; echo Now the installation can start;sleep 2' 

install:deps test
	sudo cp ./switch_to.sh /usr/local/bin/switch_to.sh
	sudo chmod 755 /usr/local/bin/switch_to.sh

uninstall:
	sudo rm -i /usr/local/bin/switch_to.sh

