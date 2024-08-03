# Self-Hosted Live TV Channel

This image runs both `ffmpeg` and `nginx-rtmp`.

The idea is that it should randomly select an episode from a media store and then use `ffmpeg` to push that media into `nginx-rtmp` in order to provide an always on channel


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
