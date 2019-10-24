#!/bin/bash

echo "Checking pre-requisites:"

# Programs to be installed
programs=(jq docker git)
missing_programs=0

for i in ${programs[@]}
do
    res=$(which $i)
    if [ $? == 0 ]; then
        echo " - found $i"
    else
        >&2 echo -e " - missing $i"
        missing_programs=1
    fi
done
echo ""

if [ $missing_programs == 1 ]; then
    exit 1
fi