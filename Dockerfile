FROM tiangolo/nginx-rtmp:latest-2024-08-01

RUN apt update \
  && apt-get -y install ffmpeg

ENV MEDIA_DIR="/media"
ENV RTMP_SERVER="127.0.0.1"
ENV RTMP_APPLICATION="benstv"
ENV RTMP_STREAMNAME="one"

COPY entrypoint.sh /entrypoint.sh
COPY app/ /app
COPY nginx.conf /etc/nginx/nginx.conf

CMD ["/entrypoint.sh"]
