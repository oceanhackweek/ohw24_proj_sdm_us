
library(tidyverse)
library(yaml)
library(sdmpredictors)
library(raster)
library(robis)
library(stars)
library(dismo)
library(terra)


vars <- read_yaml("ohw24_proj_sdm_us/config.yaml")


#Get species data from Obis.
#Input: latin name of a marine species
#Output: data frame with occurence points.
get_species_data <- function(spec) {
  
    species_data <- robis::occurrence(spec)
    withDates <- species_data %>%
      separate(eventDate, into = c("Year", "Month"), sep = "-") %>%
      filter(!is.na(Year)) %>%
      filter(grepl("^\\d{4}$", as.character(Year)))
    
    filtered_data <- subset(withDates, date_year >= vars$start_year & date_year <= vars$end_year)
    
    bounded_data <- filtered_data %>%
      filter(decimalLatitude >= vars$latmin & decimalLatitude <= vars$latmax &
               decimalLongitude >= vars$lonmin & decimalLongitude <= vars$lonmax) %>% 
      dplyr::select(datasetName, decimalLatitude, decimalLongitude, Year, Month, individualCount, vernacularName)
    return(bounded_data)
  
}

#Input: variables, output:raster stack
get_enviro_data <- function(envVars) {
  layercodes <- envVars
  env <- sdmpredictors::load_layers(layercodes, equalarea = FALSE, rasterstack = TRUE)
  #Crop
  env <- st_as_stars(env)
  extent <- st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(env))
  rc <- st_crop(x = env, y = extent)
  return(rc)
}


extractEnvData <- function(rasterStack, points) {
  env.stars <- terra::split(rasterStack)
  spec.env <- stars::st_extract(env.stars, sf::st_coordinates(points)) %>%
    dplyr::as_tibble()
  na.omit(spec.env)
  
}



getNegativePoints <- function(croppedRaster) {
  bbox_sf <- st_as_sfc(st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(env)))
  set.seed(42)  # For reproducibility
  random_points <- st_sample(bbox_sf, size = nsamp)
  
  # Convert points to a data frame and then to an sf object
  random_points_sf <- st_as_sf(as.data.frame(st_coordinates(random_points)), coords = c("X", "Y"), crs = st_crs(env_stars))
  
  # Crop the points to the extent of the environmental layer
  cropped_points <- st_intersection(random_points_sf, st_as_sf(ph, as_points = FALSE, merge = TRUE))
  return(cropped_points)
}



#####################################################
for (spec in vars$species[1]) {
  get_species_data(spec)
}

vars <- c("BO_ph","BO_bathymean","BO_chlomean","BO_dissox","BO_nitrate","BO_salinity","BO_sstmean")

