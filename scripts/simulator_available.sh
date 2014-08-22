#!/bin/bash

# Test to see if we can communicate with a well known launchd
# entry.

QLREG=`launchctl list | grep com.apple.quicklook | cut -f3-3`
FOUND_GOOD=0
for REG in $QLREG
do
  launchctl list $REG > /dev/null 2> /dev/null
  if [ $? -eq 0 ]
  then
    FOUND_GOOD=1
    break
  fi
done

echo $FOUND_GOOD
