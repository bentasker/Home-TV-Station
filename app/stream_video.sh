#!/bin/bash
RTMP_SERVER=${RTMP_SERVER:-"127.0.0.1"}
ALLOW_MODE=false
BLOCK_MODE=false
BLOCK_REGEX=""

function list_allowed(){
    echo "${ALLOWED_MEDIA}"
}

function list_files(){
    ls -1 "$MEDIA_DIR"
}

function filter_list(){
    # The list of presentations is piped into this function, filter them
    if [ "$BLOCK_REGEX" == "" ]
    then
        # Pipe stdin straight back out
        cat -
        return
    fi

    # Otherwise, we need to filter out the provided option
    egrep --line-buffered -v -e "$BLOCK_REGEX" 
}

function read_blocklist(){
    # We need to turn it into a regular expression
    blockedMedia=()
    local IFS=$'\n'
    for line in `cat /app/blocklist.txt`
    do
        if [ "$line" == "" ]
        then
            continue
        fi
        blockedMedia+="$line"
    done
    
    R=`join_by "|" "${blockedMedia[@]}"`
    
    echo "($R)"
}

function choose_series(){
    # Select a series 
    # TODO: allow set to be constrained by a config file
    $MEDIA_LIST | filter_list | sort -R | head -n 1
}

function choose_episode(){
    series=$1
    find "$MEDIA_DIR/$series" -regextype posix-extended -regex '.*\.(mp4|mkv|avi)' | filter_list | sort -R | head -n 1
}


function play_presentation(){
    # Use ffmpeg to stream into nginx-rtmp
    # From https://snippets.bentasker.co.uk/page-1706300952-Publish-file-to-RTMP-Server-(FFMPEG)-BASH.html
    f=$1
    
    # Update the record of what's playing
    # We shouldn't wait for it to complete
    write_play_to_influx "start" &
    
    ffmpeg -hide_banner -loglevel error -re -i "$f" -c:v libx264 -f flv "rtmp://$RTMP_SERVER/$RTMP_APPLICATION/$RTMP_STREAMNAME"
    
    # Note that it finished
    write_play_to_influx "end" &
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

function write_play_to_influx(){
    # Write details of what's being played to InfluxDB

    event="$1"
    
    # Check the functionality is enabled
    if [ "$INFLUXDB_URL" == "" ] || [ "$INFLUXDB_BUCKET" == "" ]
    then
        echo "No InfluxDB Config"
        return
    fi
    
    TOK=""
    if [ ! "$INFLUXDB_TOKEN" == "" ]
    then
        TOK="-H 'Authorization: Token $INFLUXDB_TOKEN'"
    fi
    
    # Generate and write the point
    curl -s -o/dev/null $TOK \
    -d "${INFLUXDB_MEASUREMENT},application=${RTMP_APPLICATION},stream=${RTMP_STREAMNAME},event=${event} series=\"$SERIES\",episode=\"$EPISODE_NAME\",publishcount=1" \
    "$INFLUXDB_URL/api/v2/write?bucket=$INFLUXDB_BUCKET"
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
if [ -f /app/allowlist.txt ] && [ `wc -l /app/allowlist.txt | awk '{print $1}'` -gt 0 ]
then
    # There's an allowlist, use that
    ALLOW_MODE=true
    
    # Build the allow list.
    ALLOWED_MEDIA=`cat /app/allowlist.txt`
    MEDIA_LIST="list_allowed"
fi

# Are we in allow mode
if [ -f /app/blocklist.txt ] && [ `wc -l /app/blocklist.txt | awk '{print $1}'` -gt 0 ]
then
    # There's an blocklist, use that
    BLOCK_MODE=true
    BLOCK_REGEX=`read_blocklist`
fi


# Create the channel M3U
cat << EOM > /mnt/hls/${RTMP_APPLICATION}/${RTMP_STREAMNAME}.m3u
#EXTM3U
#EXTINF:-1,$RTMP_STREAMNAME
$RTMP_STREAMNAME.m3u8
EOM

cat << EOM
Config:

ALLOW_MODE: $ALLOW_MODE
MEDIA_DIR: $MEDIA_DIR

Compiled Block list: $BLOCK_REGEX

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
