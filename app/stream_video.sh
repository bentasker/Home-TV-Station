#!/bin/bash
RTMP_SERVER=${RTMP_SERVER:-"127.0.0.1"}
ALLOW_MODE=false

function list_allowed(){
    echo "${ALLOWED_MEDIA}"
}

function list_files(){
    ls -1 "$MEDIA_DIR"
}

function choose_series(){
    # Select a series 
    # TODO: allow set to be constrained by a config file
    $MEDIA_LIST | sort -R | head -n 1
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

function join_by(){ 
    # credit https://stackoverflow.com/a/17841619
    local IFS="$1"; 
    shift; 
    echo "$*"; 
}

# Set the default file listing mode
MEDIA_LIST="list_files" 

# Are we in allow mode
if [ -f /app/allowlist.txt ]
then
    # There's an allowlist, use that
    ALLOW_MODE=true
    
    # Build the allow list.
    ALLOWED_MEDIA=`cat /app/allowlist.txt`
    MEDIA_LIST="list_allowed"
fi


cat << EOM
Config:

ALLOW_MODE: $ALLOW_MODE
MEDIA_DIR: $MEDIA_DIR
RTMP_SERVER: $RTMP_SERVER
RTMP_APPLICATION: $RTMP_APPLICATION
RTMP_STREAMNAME: $RTMP_STREAMNAME

Starting Streams...
EOM

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