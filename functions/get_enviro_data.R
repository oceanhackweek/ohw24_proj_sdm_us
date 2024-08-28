get_enviro_data <- function(var) {
  #This is an example! Not the final!
  layercodes <- var
  env <- sdmpredictors::load_layers(layercodes, equalarea = FALSE)
  #Crop
  env <- st_as_stars(env)
  extent <- st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(env))
  rc <- st_crop(x = env, y = extent)
  return(rc)
}