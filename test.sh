#!/bin/sh
sh ./switch_to.sh "Testing script switch_to.sh"  \
xterm -T %title -e "sleep 0.3; echo This Window shall disappear in 2 second;sleep 4 "
sleep 2
sh ./switch_to.sh  "Testing script switch_to.sh" echo "Test Fails"

exit 0
