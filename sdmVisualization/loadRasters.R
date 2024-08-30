
#########################SETUP###############################

library(tidyverse)
library(yaml)
library(sdmpredictors)
library(raster)
library(robis)
library(stars)
library(dismo)
library(terra)
library(maxnet)

vars <- read_yaml("config2.yaml")


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
  
  obs_sf <- bounded_data %>% 
    sf::st_as_sf(
      coords = c("decimalLongitude", "decimalLatitude"),
      crs = st_crs(4326))
  return(obs_sf)
  
}

#Input: variables, output:raster stack
get_enviro_data <- function(envvars) {
  #layercodes <- var
  #dir = "ohw24_proj_sdm_us"
  env <- sdmpredictors::load_layers(envvars, equalarea = FALSE, rasterstack = TRUE)
  #Crop
  env <- st_as_stars(env)
  extent <- st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(env))
  rc <- st_crop(x = env, y = extent)
  write_stars(rc, paste0("rasterImgs/", envvars, "cropped.tif"))
  return(rc)
}

extractEnvData <- function(rasterStack, points) {
  env.stars <- terra::split(rasterStack)
  spec.env <- stars::st_extract(env.stars, sf::st_coordinates(points))
  na.omit(spec.env)
  return(spec.env)
  
}

getNegativePoints <- function(croppedRaster, nsamp = 1000) {
  bbox_sf <- st_as_sfc(st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(croppedRaster)))
  set.seed(42)  # For reproducibility
  random_points <- st_sample(bbox_sf, size = nsamp)
  
  # Convert points to a data frame and then to an sf object
  random_points_sf <- st_as_sf(as.data.frame(st_coordinates(random_points)), coords = c("X", "Y"), crs = st_crs(croppedRaster))
  
  # Crop the points to the extent of the environmental layer
  cropped_points <- st_intersection(random_points_sf, st_as_sf(croppedRaster, as_points = FALSE, merge = TRUE))
  return(cropped_points)
}

### Get layers and put in folder

#Get variables from config2.yaml. This contains layer names

for (spec in vars$species) {
  currentLayers <- vars$envVars
  envRasterStack <- get_enviro_data(currentLayers)
  
  speciesPoints <- get_species_data(spec)
  
  write.csv(paste0("SpeciesData/", spec, ".csv"))
  #absPoints <- getNegativePoints(envRasterStack) 
  
  pres <- extractEnvData(envRasterStack, speciesPoints) |> mutate(pa=1)
  abs <- extractEnvData(envRasterStack, absPoints) |> mutate(pa=0)
  

  write.csv(pres, paste0("SpeciesData/", spec, "_currentPres.csv"))
  write.csv(abs, paste0("SpeciesData/", spec, "_currentAbs.csv"))
  
  allData <- rbind(pres, abs)
  write.csv(allData, paste0("SpeciesData/", spec, "_currentPresAbs.csv"))
}


##Future


for (scen in vars$scenarios) { 
  for (yr in vars$years) {
  future_layers <- sdmpredictors::list_layers_future(marine = TRUE) %>% 
    filter(current_layer_code %in% c(vars$envVars)) %>% 
     filter(year == yr) %>% 
      filter(scenario == scen) %>% 
    filter(model == "AOGCM")
  future_layers_list <- future_layers$layer_code
  for (lay in future_layers_list) {
    env <- sdmpredictors::load_layers(envvars, equalarea = FALSE, rasterstack = TRUE)
    #Crop
    env <- st_as_stars(env)
    extent <- st_bbox(c(xmin = vars$lonmin, xmax = vars$lonmax, ymin = vars$latmin, ymax = vars$latmax), crs = st_crs(env))
    rc <- st_crop(x = env, y = extent)
    write_stars(rc, paste0("rasterImgs/", envvars, "cropped.tif"))
  }
  # obj1 <- get_enviro_data(future_layers_list[1])
  # obj2 <- get_enviro_data(future_layers_list[2])
  # obj3 <- get_enviro_data(future_layers_list[3])
  # obj4 <- get_enviro_data(future_layers_list[4])
  # obj5 <- get_enviro_data(future_layers_list[5])
  # concat <- c(obj1, obj2, obj3, obj4, obj5)
  # names(concat) <- future_layers$current_layer_code
 # write_stars(concat, paste0("rasterImgs/", yr, "_", scen, ".tif"))
  
 # absPoints <- getNegativePoints(concat)
#  abs <- extractEnvData(concat, absPoints)# |> mutate(pa=0)
 # write.csv(abs, paste0("SpeciesData/", scen, "_", yr, ".abs.csv"))
  }
  
}


#allLayers <- c(future_layers_list, currentLayers)

#Call data from sdmpredictors package
envRasterStack <- get_enviro_data(currentLayers)


#absPoints <- getNegativePoints(envRasterStack)
#abs <- extractEnvData(envRasterStack, absPoints) |> mutate(pa=0)

# for (i in 1:length(vars$species)) {
#   speciesPoints <- get_species_data(vars$species[i])
#   write.csv(speciesPoints, paste0("SpeciesData/", vars$species[i],".csv"))
# }


 

pres <- extractEnvData(envRasterStack, speciesPoints) |> mutate(pa=1)
allData <- rbind(pres, abs)

presence_absence_df <- allData %>%
  dplyr::select(pa)

environmental_df <- allData %>%
  dplyr::select(-c(pa))

# Ensure that 'Presence' column is extracted as a numeric vector
presence_absence_vector <- presence_absence_df$pa

# Fit the MaxEnt model
sdm.model <- maxnet::maxnet(p = presence_absence_vector, data = environmental_df)



#Now species points will be generated programatically -- jump to server

###########################################################################################################################
