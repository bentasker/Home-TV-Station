FROM tiangolo/nginx-rtmp:latest-2024-08-01

RUN apt update \
  && apt-get -y install ffmpeg
