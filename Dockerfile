FROM tiangolo/nginx-rtmp:latest-2024-08-01

RUN apt update \
  && apt-get -y install ffmpeg gettext-base python3-flask python3-requests \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

  
ENV CONTAINER_MODE="combined"  
  
ENV MEDIA_DIR="/media"
ENV RTMP_SERVER="127.0.0.1"
ENV RTMP_APPLICATION="benstv"
ENV RTMP_STREAMNAME="one"
ENV HTTP_BASEURL="../"
ENV RTMP_BASEURL=""

#  By default, we use a single nginx-rtmp worker for a number of reasons:
#
# - to ensure that rtmp_stat reports full stats
# - Because multi-worker live streaming replication is wasted energy in a system that'll only see a few clients at once
#
ENV RTMP_NUM_WORKERS="1"

ENV RTMP_BUFLEN="5s"
ENV RTMP_FORCE_REDIRECT="false"

ENV INFLUXDB_URL=""
ENV INFLUXDB_TOKEN=""
ENV INFLUXDB_BUCKET=""
ENV INFLUXDB_MEASUREMENT="tv_station"

# How often should we poll for playback stats
ENV INFLUXDB_POLL_INTERVAL="30"

ENV FFMPEG_BITRATE="1500k"
ENV FFMPEG_MAXRATE="2M"
ENV FFMPEG_BUFSIZE="700k"

ENV FFMPEG_SCALE_FLAG="scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1:color=black"
ENV FFMPEG_THREADS=0

# HLS Settings
ENV HLS_FRAGLENGTH="2"
ENV HLS_PLAYLISTLENGTH="8"

ENV CONTROL_FILES_ENABLED="false"
ENV CONTROL_FILE_LOC="/tmp/control"

# These require HHMM
ENV SCHEDULE_START_TIME=""
ENV SCHEDULE_END_TIME=""


COPY entrypoint.sh /entrypoint.sh
COPY app/ /app
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY LICENSE /LICENSE

CMD ["/entrypoint.sh"]
