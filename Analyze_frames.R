library(tidyverse)
library(imager)
library(magick)
library(furrr)
furrr_options(packages = c("tidyverse", "magick", "imager"), seed = TRUE)
plan(multisession, workers = 16)

# This function is used to process the frames that were extract with ffmpeg in the
# extract_frames.sh script.
if(!dir.exists("pngout")) {
  dir.create("pngout")
}
if(!dir.exists("rdsdata")) {
  dir.create("rdsdata")
}

process_data = function(dset, g) {
  dset = dset %>% ungroup() %>% 
    mutate(data = map(fnames, function(x){
    x = load.image(x) %>% as.data.frame() %>% as_tibble()
  }))
  dset = dset %>% 
    mutate(date = str_extract(fnames, "20[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}")) %>% 
    mutate(experiment = str_extract(fnames, "_[A-z]*.*_")) %>% 
    mutate(frame = str_extract(fnames, "[0-9]{5}")) %>%
    mutate(frame = as.numeric(frame)) %>% 
    select(date, experiment, frame, data) %>% 
    unnest(data)
  
  oname = dset %>% slice(1) %>% pull(experiment) %>%
    basename() %>% 
    str_replace("_$", sprintf("_%03d_data.rds", g))
  
  oname = str_glue("rdsdata/{oname}")
  xoname = str_replace(oname, "_data.rds", "_xdata.rds")
  yoname = str_replace(oname, "_data.rds", "_ydata.rds")
  
  # dset %>% write_rds(oname)
  
  dset %>% 
    group_by(frame, x) %>% summarise(value = mean(value)) %>% 
    ungroup() %>% 
    mutate(value = as.integer(value * 10^6)) %>%
    write_rds(xoname)
  
  dset %>% 
    group_by(frame, y) %>% summarise(value = mean(value)) %>% 
    ungroup() %>% 
    mutate(value = as.integer(value * 10^6)) %>%
    write_rds(yoname)
  
  return(0)
}

args = commandArgs(trailingOnly = TRUE)

FOLDER="/home/Lab_Data/videofile/fish_videos/original"
TEMP=str_replace(FOLDER, "original", "original_frames")
OUT=str_replace(FOLDER, "original", "removed_background")


fnames = dir(OUT, pattern = args, full = TRUE)
dset = tibble(fnames)
dset_main = dset %>% mutate(g = seq_along(fnames) %/% 100)
dset_main %>%
  group_nest(g) %>%
  mutate(out = future_map2_dbl(data, g, process_data))
