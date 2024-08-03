#!/bin/bash
RTMP_SERVER=${RTMP_SERVER:-"127.0.0.1"}

function choose_series(){
    # Select a series 
    # TODO: allow set to be constrained by a config file
    ls -1 "$MEDIA_DIR" | sort -R | head -n 1
}

function choose_episode(){
    series=$1
    find "$MEDIA_DIR/$series" -regextype posix-extended -regex '.*\.(mp4|mkv|avi)' | sort -R | head -n 1
}


function play_presentation(){
    # Use ffmpeg to stream into nginx-rtmp
    # From https://snippets.bentasker.co.uk/page-1706300952-Publish-file-to-RTMP-Server-(FFMPEG)-BASH.html
    f=$1
    ffmpeg -re -i "$f" -c:v libx264 -f flv "rtmp://$RTMP_SERVER/$RTMP_APPLICATION/$RTMP_STREAMNAME"
}


while true
do
    # Work out what to play next
    SERIES=`choose_series`
    EPISODE=`choose_episode "$SERIES"`

    echo "$SERIES"
    echo "$EPISODE"

    # Stream it
    play_presentation "$EPISODE"
done
