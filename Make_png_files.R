library(tidyverse)
library(magick)
library(ggpubr)
library(furrr)
furrr_options(packages = c("tidyverse", "magick", "imager"),
              seed = TRUE)
# We will use 16 cores to process the make_frame() function
# There are 16 cores available on the server.
# We can run 2 threads per core for a total of 32 threads.
# We should not use all 32 threads.
plan(multisession, workers = 16) 



make_frame = function(fnames, xdata, ydata) {
  img = image_read(fnames)
  img = img %>% image_normalize() %>% as.raster()
  dimensions = dim(img)  
  widths = 1
  heights = min(dimensions) / max(dimensions)
  tmp = expand.grid(x =c(1, dimensions[1]), y = c(1, dimensions[2]))
  
  frame_number = str_extract(fnames, "[0-9]{5}") %>% as.numeric()
  
  b1 = ggplot(tmp) +
    geom_point(aes(x =y , y=x)) +
    background_image(img)  +
    annotate("text", x = 10, y = 240, label = frame_number, color = "white", size = 5,
             vjust = 0, hjust = 0) +
    scale_y_reverse("y-coordinates") +
    scale_x_continuous("x-coordinates") 
  
  h1 = xdata %>% filter(near(frame, frame_number)) %>% 
    ggplot() + 
    geom_col(aes(x = x, y = value)) +
    theme(axis.title = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_blank())
  
  v1 = ydata %>% filter(near(frame, frame_number)) %>% 
    ggplot() + 
    geom_col(aes(x = y, y = value)) +
    coord_flip() +
    scale_x_reverse() +
    theme(axis.title = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_blank())
  
  pout = ggpubr::ggarrange(h1, NULL, b1, v1, 
                           ncol = 2, nrow = 2, align = "hv", 
                           widths = c(3, 1), heights = c(1, 1))
  fname = sprintf("pngout/pngout_%05d.png", frame_number)
  ggsave(pout, filename = fname, width = 80*4, height = 80*2, units = "mm", dpi = 300)
  return(0)
}


FOLDER="/home/Lab_Data/videofile/fish_videos/original"
TEMP=str_replace(FOLDER, "original", "original_frames")
OUT=str_replace(FOLDER, "original", "removed_background")
args = commandArgs(trailingOnly = TRUE)

# If you only want to run this script, args need to be given explicitly.
# args = "2020.08.18_Chp0.1mgL_1h_front"2020.08.18_Chp0.1mgL_1h_front.MP4

################################################################################
fnames = dir(OUT, pattern = args, full = TRUE)
dset = tibble(fnames)
# dset = dset %>% filter(str_detect(fnames, "mgL"))
dset_main = dset %>% mutate(g = seq_along(fnames) %/% 100)

PATX = str_glue("{args}*.*xdata")
PATY = str_glue("{args}*.*ydata")

dset_main = dset_main %>% 
  group_nest(g) %>% 
  mutate(xnames = dir("rdsdata/", pattern = PATX, full = TRUE)) %>% 
  mutate(ynames = dir("rdsdata/", pattern = PATY, full = TRUE))

tmp = dset_main %>% 
  mutate(xdata = map(xnames, read_rds),
         ydata = map(ynames, read_rds)) %>% 
  select(g, data, xdata, ydata) %>% unnest(data)
fname = tmp %>% slice(1) %>% pull(fnames)
tmp = tmp %>% mutate(out = future_pmap(list(fnames, xdata, ydata), make_frame))

