# Self-Hosted Live TV Channel

This image runs both `ffmpeg` and `nginx-rtmp`.

The idea is that it should randomly select an episode from a media store and then use `ffmpeg` to push that media into `nginx-rtmp` in order to provide an always on channel

Project management can be found in my [Gitlab mirror](https://projects.bentasker.co.uk/gils_projects/project/project-management-only/home-tv-station.html).

----

### Media Directory Structure

The media is expected to appear at `/media` (this can be overridden by changing env var `MEDIA_DIR`).

That directory is then expected to contain the following structure

```text
- presentation name
  - Series number (optional)
    - episode 1
    - episode 2
```

The easiest example of a presentation name is a series name

---

### Running

The system is intended to be run as a container, whether within Docker or in a Kubernetes cluster

At it's simplest, that may look like this:

```sh
docker run \
 --name=tvstation \
 --restart=unless-stopped \
 -p 80:8082 \
 -p 1935:1935 \
 -v /path/to/media:/media \
 ghcr.io/bentasker/home-tv-station:0.1
```

You should then be able to play

* RTMP: `rtmp://127.0.0.1/benstv/one`
* HLS: `http://127.0.0.1:8082/benstv/one.m3u8`

For a more complex example, see the [example kubernetes manifest](example/tvstation.yml).

---

## Constraining Candidate Videos

It's possible to tell the channel that it should only stream certain presentations.

### Allow List

An allowlist can be written to `/app/allowlist.txt`.

This list should consist of a presentation name, per line, using the same format/case as is necessary to access that directory:

```text
Big_Buck_Bunny
Acme_The_Human_Carrot
```

### Block List

The blocklist should be provided at `/app/blocklist.txt`

The entries provided are collapsed into an OR regex (with each line being one possibility), so providing

```text
Big_Buck_Bunny
Acme_The_Human_Carrot
```

Will result in options being filtered with something like

```sh
egrep -v -e '(Big_Buck_Bunny|Acme_The_Human_Carrot)'
```

Filters are applied to both presentation and episode names: so the above would filter out both `Big_Buck_Bunny/episode1.mp4` and `documentaries/the_making_of_Big_Buck_Bunny`.

---

### Play History

The image is able to write playback history into InfluxDB whenever an episode starts (and ends).

This is off by default, but can be configured by setting the relevant environment variables, for example
```
-e INFLUXDB_URL="http://192.168.1.5:8086" \
-e INFLUXDB_BUCKET="mytv" \
-e INFLUXDB_TOKEN="aaaaffff=="
```

The writes use the v2 API by default. It will still work if you're rocking 1.x - to authenticate with [the compatability API](https://docs.influxdata.com/influxdb/v1/tools/api/) (assuming you've auth enabled) simply set the token using the format `username:password`.

The default measurement is `tv_station` however you can override this using env var `INFLUXDB_MEASUREMENT`.

---

### Broadcast Window

It's possible to tell the system that it should only broadcast media during a specific time window (at the end of the window it'll finish the current presentation before cutting off).

Outside of that time, it'll broadcast a test card:

![A BBC testcard](/app/images/test-card-bbc-two.png)

The broadcast window is set with the following env variables

```sh
SCHEDULE_START_TIME="0700"
SCHEDULE_END_TIME="2330"
```

Times should be specified using UTC.

---

### Media Tuning

It's possible to have the publishing process cap the bitrate which will be streamed in.

This is controlled by the following 3 environment variables
```
FFMPEG_BITRATE="1500k"
FFMPEG_MAXRATE="2M"
FFMPEG_BUFSIZE="700k"
```

More information on how to use these can be found in the [FFmpeg documentation](https://trac.ffmpeg.org/wiki/Limiting%20the%20output%20bitrate).


---



### HTTP API

The system exposes an extremely simple HTTP API:

#### `/api/next` 

Kill the current stream and proceed to the next. Expects a valid app and stream name in POST data
```sh
curl -d 'app=benstv&name=one' http://127.0.0.1:8080/api/next
```

---

### License

Released under [GNU GPL v3](LICENSE)
