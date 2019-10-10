#!/bin/bash
awk '{ sub ("\\\\$", " "); printf " --build-arg %s", $0  } END { print ""  }' $@