#!/bin/bash

# Launch Nginx
nginx -g "daemon off;" &

# TODO: launch publishing script

# Wait for something to exit
wait -n

# Return the exit status
exit $?

