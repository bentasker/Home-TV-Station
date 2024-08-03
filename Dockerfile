FROM tiangolo/nginx-rtmp:latest-2024-08-01

RUN apt update \
  && apt-get -y install ffmpeg gettext-base

ENV MEDIA_DIR="/media"
ENV RTMP_SERVER="127.0.0.1"
ENV RTMP_APPLICATION="benstv"
ENV RTMP_STREAMNAME="one"

ENV INFLUXDB_URL=""
ENV INFLUXDB_TOKEN=""
ENV INFLUXDB_BUCKET=""
ENV INFLUXDB_MEASUREMENT="tv_station"

COPY entrypoint.sh /entrypoint.sh
COPY app/ /app
COPY nginx.conf.template /etc/nginx/nginx.conf.template

CMD ["/entrypoint.sh"]
