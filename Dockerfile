FROM tiangolo/nginx-rtmp:latest-2024-08-01

RUN apt update \
  && apt-get -y install ffmpeg gettext-base python3-flask \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV MEDIA_DIR="/media"
ENV RTMP_SERVER="127.0.0.1"
ENV RTMP_APPLICATION="benstv"
ENV RTMP_STREAMNAME="one"
ENV HTTP_BASEURL="../"
ENV RTMP_BASEURL=""

ENV INFLUXDB_URL=""
ENV INFLUXDB_TOKEN=""
ENV INFLUXDB_BUCKET=""
ENV INFLUXDB_MEASUREMENT="tv_station"

ENV FFMPEG_BITRATE="1500k"
ENV FFMPEG_MAXRATE="2M"
ENV FFMPEG_BUFSIZE="700k"

ENV FFMPEG_SCALE_FLAG="scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1:color=black"

# HLS Settings
ENV HLS_FRAGLENGTH="2"
ENV HLS_PLAYLISTLENGTH="8"

ENV CONTROL_FILES_ENABLED="false"
ENV CONTROL_FILE_LOC="/tmp/control"

# These require HHMM
ENV SCHEDULE_START_TIME="0700"
ENV SCHEDULE_END_TIME="2300"


COPY entrypoint.sh /entrypoint.sh
COPY app/ /app
COPY nginx.conf.template /etc/nginx/nginx.conf.template

CMD ["/entrypoint.sh"]
