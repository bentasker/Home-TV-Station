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
