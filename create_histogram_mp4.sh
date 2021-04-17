#!/bin/bash

FOLDER="/home/Lab_Data/videofile/fish_videos/histogram"

ffmpeg -start_number 0 -r ${2} -i pngout/pngout_%05d.png \
  -c:v libx264 -an \
  -vf "crop='iw-mod(iw,2)':'ih-mod(ih,2)',format=yuv420p" \
  ${FOLDER}/${1}_histogram.mp4 -y && \
rm pngout/*.png
