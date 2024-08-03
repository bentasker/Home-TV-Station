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

function update_now_playing(){
    series=$1
    ep=$2
    
    tmpfile=`mktemp`
    echo "$series" > "$tmpfile"
    echo "$ep" >> "$tmpfile"
    
    # move into position
    chown nobody:nogroup "$tmpfile"
    mv "$tmpfile" "/mnt/hls/${RTMP_APPLICATION}/${RTMP_STREAMNAME}-now_playing.txt";
    
}

while true
do
    # Work out what to play next
    SERIES=`choose_series`
    EPISODE=`choose_episode "$SERIES"`
    EPISODE_NAME=`echo "$EPISODE" | awk -F'/' '{print $NF}' | awk -F'.' '{$NF=""; print $0}'`
    
    echo "Playing: $SERIES, $EPISODE_NAME"
    update_now_playing "$SERIES", "$EPISODE_NAME"
    
    # Stream it
    play_presentation "$EPISODE"
done
