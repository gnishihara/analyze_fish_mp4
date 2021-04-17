#!/bin/bash
# This is the main script to run the sub-scripts.
# Make sure that there are no spaces in the filenames or the folder names!
 
FOLDER="/home/Lab_Data/videofile/fish_videos/original"
f1="2020.08.18_Chp0.1mgL_1h_front.MP4"
f2="2020.08.18_Cont._1h_front.MP4"

./remove_background.sh ${FOLDER} ${f1}
./remove_background.sh ${FOLDER} ${f2}
