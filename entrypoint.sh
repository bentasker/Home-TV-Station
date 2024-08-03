#!/bin/bash

# Launch Nginx
nginx -g "daemon off;" &

# Give Nginx a second to come up
sleep 1

# Start publishing video
/app/stream_video.sh &

# Wait for something to exit
wait -n

# Return the exit status
exit $?

