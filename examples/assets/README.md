# Demo fixtures

`demo.png` and `demo.webm` are generated FFmpeg test patterns (160×90, two seconds,
8 source frames/sec). The WebM also contains a generated 440 Hz test tone. No GTK
media artwork was copied. Tests mute playback while exercising audio ownership.

`path-world.txt` is the SVG path data used by GTK 4.20.2's path_walk/path_sweep
examples. Its source is Skimel's CC0 world map:
https://commons.wikimedia.org/wiki/File:Simplified_blank_world_map_without_Antartica_(no_borders).svg
The original map is dedicated to the public domain under CC0. GTK's source
identifies this source; the path data was copied without GTK implementation code.
