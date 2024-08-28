
library(tidyverse)
library(yaml)
library(sdmpredictors)
library(raster)
library(robis)

vars <- read_yaml("ohw24_proj_sdm_us/config.yaml")

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




#####################################################
for (spec in vars$species[1]) {
  get_species_data(spec)
}
