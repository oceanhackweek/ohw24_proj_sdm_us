#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
#########################SETUP###############################
library(shiny)
library(tidyverse)
library(yaml)
library(sdmpredictors)
library(raster)
library(robis)
library(stars)
library(dismo)
library(terra)
library(maxnet)
library(leaflet)
library(leafem)

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


###########################################################################################################################

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Gulf of Maine Species in a Changing Climate"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            selectInput(inputId = "species", label = "Species:", choices = c("Doryteuthis_pealeii", 
                                                                             "Cetorhinus_maximus", 
                                                                             "Morone_saxatilis", 
                                                                             "Homerus_americanus", 
                                                                             "Salmo_salar"),
                                                            selected = "Cetorhinus_maximus"), #sets default selection
            
            selectInput(inputId = "year", label = "Year:", choices = c("current", 
                                                                             "2050", 
                                                                             "2100"),
                                                                    selected = "2050"), #sets default selection
            selectInput(inputId = "scenario", label = "RCP Scenario:", choices = c("current", 
                                                                                   "RCP26", 
                                                                                   "RCP45", 
                                                                                   "RCP60", 
                                                                                   "RCP85"),
                                                                   selected = "RCP26") #sets default selection
        ),

        # Show a plot of the generated distribution
        mainPanel(
          leafletOutput("distPlot")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
    
  
    output$distPlot <- renderLeaflet({
      allData <- read.csv(paste0("SpeciesData/", input$species, "_currentPresAbs.csv")) %>% 
        dplyr::select(-c(X))
      
      presence_absence_df <- allData %>%
        dplyr::select(pa)
      
      environmental_df <- allData %>%
        dplyr::select(-c(pa))
      
      # Ensure that 'Presence' column is extracted as a numeric vector
      presence_absence_vector <- presence_absence_df$pa
      
      # Fit the MaxEnt model
      sdm.model <- maxnet::maxnet(p = presence_absence_vector, data = environmental_df)
      
      files <- data.frame(filename = list.files("rasterImgs/")) %>% 
        mutate(type = str_sub(filename,-3,-1)) %>% 
        filter(type == "tif") %>% 
        mutate(cropped = str_sub(filename, -11, -5)) %>% 
        filter(cropped == "cropped") %>% 
        mutate(rcp = substr(filename, start = 6, stop = 10)) %>% 
        mutate(year = substr(filename, start = 12, stop = 15))
      
      
      filteredFiles <- files %>% 
        filter(year == input$year) %>% 
        filter(rcp == input$scenario)
      names <- filteredFiles$filename
      
      
      BO22_salinitymean_bdmax <- read_stars(paste0("rasterImgs/",names[1]))
      BO21_tempmean_bdmax <- read_stars(paste0("rasterImgs/",names[2]))
      BO22_chlomean_ss <- read_stars(paste0("rasterImgs/",names[3]))
      BO22_salinitymean_ss <- read_stars(paste0("rasterImgs/",names[4]))
      BO21_tempmean_ss <- read_stars(paste0("rasterImgs/",names[5]))
      
      concat2 <- c(BO21_tempmean_bdmax, BO21_tempmean_ss, BO22_chlomean_ss, BO22_salinitymean_bdmax, BO22_salinitymean_ss)
      names(concat2) <- c("BO21_tempmean_bdmax", "BO21_tempmean_ss", "BO22_chlomean_ss", "BO22_salinitymean_bdmax", "BO22_salinitymean_ss")
      
      clamp <- TRUE      
      type <- "logistic"
      
      # Predict species distribution within the cropped area
      predicted <- predict(sdm.model, concat2) #, clamp = clamp, type = type) #, clamp = clamp, type = type)
 
      leaflet() %>% 
        addTiles() %>% 
        leafem::addStarsImage(predicted, 
                              colors = viridis::viridis(256), 
                              opacity = 0.8)
      
      
      
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
