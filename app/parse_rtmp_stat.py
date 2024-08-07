#!/usr/bin/env python3
#
# Fetch RTMP stats from nginx
#
# Copyright (c) 2024 B Tasker
# Released under GNU GPL V3
# See LICENSE
#

import os
import requests
import sys
import time
import xml.etree.ElementTree as ET


def stats_to_LP(stat_buff):
    ''' Iterate through a stats buffer generate line protocol
    '''
    measurement=os.getenv("INFLUXDB_MEASUREMENT", "tv_station")
    lp_buf = []
    for stat in stat_buff:
        
        lp_p1 = [
            measurement,
            "event=statsrun"
            ]
        
        for m in stat['meta']:
            lp_p1.append(f"{m}={stat['meta'][m]}")
        
        fields = []
        for f in stat['fields']:
            fields.append(f"{f}={stat['fields'][f]}i")
        
        # Turn it into lp
        lp1 = ",".join(lp_p1)
        f = ",".join(fields)
        lp = ' '.join([lp1, f])
        lp_buf.append(lp)
    return lp_buf
        
        
def write(lp):
    ''' Write Line Protocol to an InfluxDB instance 
    '''
    token = os.getenv("INFLUXDB_TOKEN", False)
    url = os.getenv("INFLUXDB_URL", False)
    bucket = os.getenv("INFLUXDB_BUCKET", False)
    
    if not all([url, bucket]):
        # We don't have the details we need to proceed
        print("Influx details not set")
        return
    
    headers = {}
    if token:
        headers['Authorization'] = f"Token {token}"
   
    r = requests.post(f"{url}/api/v2/write?bucket={bucket}", data='\n'.join(lp))
    if r.status_code != 204:
        print("Unable to write stats")
   

def processStats(xml):
    ''' Parse rtmp_stat's xml response and generate a list of stats
    
    The list contains an entry per live stream
    '''
    root = ET.fromstring(xml)
    
    stat_buffer = []
    for server in root.findall('server'):
        for app in server.findall('application'):
            app_name  = app.find("name").text
            
            # Get any listed live streams
            for stream in app.findall("./live/stream"):
                # Count the number of publishing clients (usually 1, but could be 0)
                publishers = len(stream.findall("./client/publishing"))
                
                total_dropped = 0
                for dropped in stream.findall("./client/dropped"):
                    total_dropped += int(dropped.text)
                
                
                stat_buffer.append({
                    "meta" : {
                        "application" : app_name,
                        "stream" : stream.find("name").text,
                    },
                    "fields" : {
                        "nclients" : int(stream.find("nclients").text) - publishers, # subtract the publisher
                        "publishers": publishers,
                        "bytes_out" : stream.find("bytes_out").text,
                        "bytes_in" :  stream.find("bytes_in").text,
                        "dropped_frames": total_dropped                        
                    }
                    })
    
    return stat_buffer

if __name__ == '__main__':
    poll_interval = int(os.getenv("INFLUXDB_POLL_INTERVAL", 30))
    while True:
        try:
            server = sys.argv[1]
            response = requests.get(server)
            stat_buff = processStats(response.text)
            lp = stats_to_LP(stat_buff)
            write(lp)
            time.sleep(poll_interval)
        except Exception as e:
            print(e)
            time.sleep(poll_interval)
    
    
    
