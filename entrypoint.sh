#!/bin/bash

# Build the config
envsubst '$RTMP_APPLICATION,$HLS_PLAYLISTLENGTH,$HLS_FRAGLENGTH,$HTTP_BASEURL' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Ensure that the HLS output dir exists
mkdir -p /mnt/hls/$RTMP_APPLICATION/

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

