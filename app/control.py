#!/usr/bin/env python3
#
# Simple HTTP control server
#
# Copyright (c) 2024 B Tasker
# Released under GNU GPL V3
# See LICENSE
#

import os

from flask import Flask, request
app = Flask(__name__)

@app.route('/play',methods = ['POST'])
def play():
    app = request.form['app']
    stream = request.form['name']
    
    if len(app) < 1:
        # It's a relay request from the other workers
        # just approve it
        return '', 200;
    
    print(f"Received play request for {app}/{stream}")
    
    if app != RTMP_APPLICATION or stream != RTMP_STREAM:
        # Not our responsibility, approve playback and move on
        print(f"{app} != {RTMP_APPLICATION} or {stream} != {RTMP_STREAM}")
        return '', 200;
    
    # Otherwise, ensure that the play state file exists
    fh = open(os.path.join(CONTROL_FILES, "play_stream"), 'w')
    fh.write('play')
    fh.close()
    
    # Load the counter
    player_count = 0
    cnt_file = os.path.join(CONTROL_FILES, "streamer_count")
    if os.path.exists(cnt_file):
        with open(cnt_file, 'r') as f:
            for line in f.readlines():
                player_count = int(line)
                break
            
    # Increment and store the counter
    player_count += 1
    with open(cnt_file, 'w') as f:
        f.write(str(player_count))

    # Authorise playback
    return '', 200;
    
@app.route('/play_done',methods = ['POST'])
def playdone():
    app = request.form['app']
    stream = request.form['name']
    
    print(f"Received play stop for {app}/{stream}")
    
    if app != RTMP_APPLICATION or stream != RTMP_STREAM:
        # Not our responsibility, approve playback and move on
        print(f"{RTMP_APPLICATION} or stream != {RTMP_STREAM}")
        return '', 200;

    # Load the counter
    player_count = 1
    cnt_file = os.path.join(CONTROL_FILES, "streamer_count")
    if os.path.exists(cnt_file):
        with open(cnt_file, 'r') as f:
            for line in f.readlines():
                player_count = int(line)
                break

    # Decrement and store the counter
    player_count -= 1
    with open(cnt_file, 'w') as f:
        f.write(str(player_count))

    # If the counter is less than 1 there are no active players
    # So switch the playstate file to be `stop`
    # Otherwise, ensure that the play state file exists
    fh = open(os.path.join(CONTROL_FILES, "play_stream"), 'w')
    fh.write('stop')
    fh.close()
    
    return '', 200;

@app.route('/api/next',methods = ['POST'])
def next():
    # Kill the current playback to skip onto the next
    app = request.form['app']
    stream = request.form['name']
    
    print(f"Received next for {app}/{stream}")
    
    if app != RTMP_APPLICATION or stream != RTMP_STREAM:
        # Not our responsibility, approve playback and move on
        print(f"{RTMP_APPLICATION} or stream != {RTMP_STREAM}")
        return '', 200;

    # Kill ffmpeg
    os.system('pkill ffmpeg')
    return '', 200;


if __name__ == '__main__':
    
   CONTROL_FILES = os.getenv("CONTROL_FILE_LOC", "/tmp/control")
   RTMP_APPLICATION = os.getenv("RTMP_APPLICATION")
   RTMP_STREAM = os.getenv("RTMP_STREAMNAME")
   
   
   app.run(debug = True, port = 3000)
