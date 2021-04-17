#!/bin/bash
# This BASH script will read split the video into individual frames, 
# then it will crop the frames to size. For every 100 frames, an average frame
# will be calculated and these averaged frames will be averaged to obtain a 
# global average. This is done to determine the background of the video so that
# it can be subtracted from each individual frame. The goal is to only leave 
# information about the fish. The processed frames are then sent to two R 
# scripts (Analyze_frames.R and Make_png_files.R) for more processing.
################################################################################

FOLDER=${1}
TEMP=${FOLDER/original/original_frames}
OUT=${FOLDER/original/removed_background}
FOLDER2=${FOLDER/original/30FPS}

# Make folders if they do not exist.
mkdir -p "${TEMP}"
mkdir -p "${OUT}"

################################################################################
# Choose the mp4 file
# f=${FOLDER}/2020.08.18_Chp0.1mgL_1h_front.MP4
# f=${FOLDER}/2020.08.18_Cont._1h_front.MP4
f=${FOLDER}/${2}
ffprobe -i ${f}

FRAME_RATE=$(ffprobe -v error -i "${f}" -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate)
echo "The frame rate of the mp4 is ${FRAME_RATE}"

################################################################################

z=$(basename ${f%.MP4})
echo "Work on the ${z} file."
ffmpeg -r ${FRAME_RATE} -i "${f}" -vframes 1 "${z}.png" -y # Get one frame to determine the video crop dimensions

# Video crop size
# Crop the video to decrease the file sizes.
# These might/should be specific to each video.
# Note that the coordinates for the top-left corner is 0,0.
X=90       # x-coordinate origin 
Y=465      # y-coordinate origin
W=1770     # crop width
H=240      # crop height

# Since a background image without fish was not provided, we need to make one from the video.
# We can do this by averaging over all the frames.
# Crop video and save as png files

# Run only the first 30 seconds  (-t 30)
# ffmpeg -r ${FRAME_RATE} -i ${f} -t 30 -filter:v "crop=${W}:${H}:${X}:${Y}" -start_number 0 "$TEMP/${z}_%05d.png" -y

# Do entire mp4 file
ffmpeg -r ${FRAME_RATE} -i ${f} -filter:v "crop=${W}:${H}:${X}:${Y}" -start_number 0 "$TEMP/${z}_%05d.png" -y
################################################################################
# This BASH function cuts up the files in to 100 file chunks due to memory limitations.
# Then it will calculate the average image
# Don't run this convert in parallel, otherwise we wil run out of memory.
calculate_group_average() {
  N=$(ls ${TEMP}/${z}_[0-9]*.png|wc -l) # Determine the number of files
  M=$(($N / 100))                       # Group by 100 files
  i=0                                   # Counter for averaged frames

  echo "Process $N number of frames. In $((M+1)) groups."
  until [ $i -gt ${M} ]; do
    echo "This is pass number $((i+1))."
    FNAME=$(printf "${z}_%03d[0-9][0-9].png" "$i")
    ONAME=$(printf "${z}_%03d_average.png" "$i")
    convert ${TEMP}/${FNAME} -colorspace Gray -evaluate-sequence Mean ${TEMP}/${ONAME} &
    # sleep 0.5s
    ((i++))
  done
  wait
  return 0
}

calculate_group_average && \
  convert ${TEMP}/${z%}_[0-9]*_average.png -evaluate-sequence Mean ${TEMP}/${z}_average.png

# Remove the background. This is system intensive but is set up to run in parallel.
remove_background() {
    DFILE=$(printf "${z}_%05d_difference.png" "$1")
    ONAME="${OUT}/${DFILE}"
    convert ${g} -colorspace Gray -compose Minus_Dst ${TEMP}/${z}_average.png -composite ${ONAME}
    sleep 0.1s
} 

echo "Next remove the background from each png file."
k=0
THREADS=10
for g in ${TEMP}/${z}_[0-9]*[0-9].png; do
  if (( k % THREADS == 0 )); then
    wait
  fi
  remove_background "${k}" &
  ((k++))
done

echo "Take a 1 sec break then run the R scripts."
sleep 1s # Take a break to make sure that file writing is complete.

Rscript ./Analyze_frames.R ${z} # Run R script to analyze the frames
Rscript ./Make_png_files.R ${z} # Run R script to build the histogram frames
./create_histogram_mp4.sh ${z} ${FRAME_RATE}  # Run R script to concatenate the histogram frames into an mp4
