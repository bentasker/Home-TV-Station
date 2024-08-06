#!/bin/bash

# Servers should only run in combined or server mode
#
# Technically the control server can't do much in server mode, but it's
# needed to ensure Nginx hooks don't break
#
if [ "$CONTAINER_MODE" == "combined" ] || [ "$CONTAINER_MODE" == "server" ]
then
    # Build the config
    envsubst '$RTMP_APPLICATION,$HLS_PLAYLISTLENGTH,$HLS_FRAGLENGTH,$HTTP_BASEURL,$RTMP_BUFLEN,$RTMP_NUM_WORKERS' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

    # Ensure that the HLS output dir exists
    mkdir -p /mnt/hls/$RTMP_APPLICATION/

    # Stand up the control server
    mkdir -p "$CONTROL_FILE_LOC"
    python3 /app/control.py &

    # Launch Nginx
    nginx -g "daemon off;" &

    # Give Nginx a second to come up
    sleep 1
    
    # Launch the stats collector
    /app/parse_rtmp_stat.py http://127.0.0.1/stats
fi

# Publisher process should only run in combined or publisher mode
if [ "$CONTAINER_MODE" == "combined" ] || [ "$CONTAINER_MODE" == "publisher" ]
then
    # Start publishing video
    /app/stream_video.sh &
fi

# Wait for something to exit
wait -n

# Return the exit status
exit $?

