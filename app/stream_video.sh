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

function in_scheduled_time(){
    # Check whether there's a schedule set 
    #
    # Returns 0 if we should play media 
    # or 1 if we're in a blackout
    if [ "$SCHEDULE_START_TIME" == "" ] || [ "$SCHEDULE_END_TIME" == "" ]
    then
        echo 0
        return
    fi

    now=$(date -u +'%H%M')
    if [ $now -ge $SCHEDULE_START_TIME ] && [ $now -le $SCHEDULE_END_TIME ]
    then 
        # In bounds
        echo 0
        return
    fi
    
    # If we got this far, we're out of bounds
    echo 1
    return
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
    
    ffmpeg \
    -hide_banner \
    -loglevel error \
    -re \
    -i "$f" \
    -c:a aac \
    -c:v libx264 \
    -b:v $FFMPEG_BITRATE \
    -maxrate $FFMPEG_MAXRATE \
    -bufsize $FFMPEG_BUFSIZE \
    -pix_fmt yuv420p \
    -filter:v fps=24 \
    -threads $FFMPEG_THREADS \
    -f flv \
    -vf "$FFMPEG_SCALE_FLAG" \
    "rtmp://$RTMP_SERVER/$RTMP_APPLICATION/$RTMP_STREAMNAME"
    
    # Note that it finished
    write_play_to_influx "end" &
}

function play_testcard(){
   # Publish the testcard
    
   # Note the start time in Influx
   write_play_to_influx "start" &

   # Stream the card
   ffmpeg \
    -hide_banner \
    -loglevel error \
    -re \
    -f lavfi \
    -i anullsrc=channel_layout=stereo:sample_rate=44100 \
    -f image2 \
    -loop 1 \
    -i /app/images/test-card-bbc-two.png \
    -c:a aac \
    -c:v libx264 \
    -b:v $FFMPEG_BITRATE \
    -maxrate $FFMPEG_MAXRATE \
    -bufsize $FFMPEG_BUFSIZE \
    -pix_fmt yuv420p \
    -threads $FFMPEG_THREADS \
    -f flv \
    -vf "$FFMPEG_SCALE_FLAG" \
    "rtmp://$RTMP_SERVER/$RTMP_APPLICATION/$RTMP_STREAMNAME" &
    
    ffmpeg_pid=$!
    
    while true
    do
        if [ "`in_scheduled_time`" == "0" ]
        then
            kill -9 "$ffmpeg_pid"
            write_play_to_influx "end" &
            break
        fi
        sleep 1
    done    
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
#EXTINF:-1,${RTMP_APPLICATION}/$RTMP_STREAMNAME
$RTMP_BASEURL/${RTMP_APPLICATION}/$RTMP_STREAMNAME
#EXTINF:-1,${RTMP_APPLICATION}/${RTMP_STREAMNAME}-hls
$HTTP_BASEURL/${RTMP_APPLICATION}/$RTMP_STREAMNAME.m3u8

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
    
    if [ "$CONTROL_FILES_ENABLED" == "true" ]
    then
        echo "Checking for play control state"
        # Check whether we're authorised to play
        while true
        do
            if [ -f "$CONTROL_FILE_LOC/play_stream" ]
            then
                grep -q play "$CONTROL_FILE_LOC/play_stream"
                if [ "$?" == "0" ]
                then
                    # Go ahead and play
                    break
                fi
            fi

            # Otherwise, recheck periodically
            sleep 1
        done
    
    fi
    
    # Check time bounds, if we're outside them trigger the testcard
    if [ "`in_scheduled_time`" == "1" ]
    then
        SERIES="station_offline"
        EPISODE="test_card"
        play_testcard
        continue
    fi
    
    # If there are any clients on the temporary stream, move them back
    if [ "$RTMP_FORCE_REDIRECT" == "true" ]
    then    
        curl -v "http://127.0.0.1:8080/control/redirect/subscriber?app=${RTMP_APPLICATION}&name=${RTMP_STREAMNAME}.tmp&newname=${RTMP_STREAMNAME}"    
    fi
    
    echo "Playing: $SERIES, $EPISODE_NAME"
    update_now_playing "$SERIES", "$EPISODE_NAME"
    
    # Stream it
    play_presentation "$EPISODE"
    
    # Should we force clients to disconnect and reconnect?
    if [ "$RTMP_FORCE_REDIRECT" == "true" ]
    then
        echo "Forcing redirect"
        curl -v "http://127.0.0.1:8080/control/redirect/subscriber?app=${RTMP_APPLICATION}&name=${RTMP_STREAMNAME}&newname=${RTMP_STREAMNAME}.tmp"
    fi    
done
