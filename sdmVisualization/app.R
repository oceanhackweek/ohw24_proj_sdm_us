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

### Get initial SDM model on startup. predict programatically. 

#Get variables from config2.yaml. This contains layer names
layers <- c(vars$envVars)

#Call data from sdmpredictors package
envRasterStack <- get_enviro_data(layers)


absPoints <- getNegativePoints(envRasterStack) 
abs <- extractEnvData(envRasterStack, absPoints) |> mutate(pa=0)


#Now species points will be generated programatically -- jump to server

###########################################################################################################################

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Gulf of Maine Species in a Changing Climate"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            selectInput(inputId = "species", label = "Species:", choices = c("Doryteuthis pealeii", 
                                                                             "Cetorhinus maximus", 
                                                                             "Morone saxatilis", 
                                                                             "Homerus americanus", 
                                                                             "Salmo salar"),
                                                            selected = "Cetorhinus maximus"), #sets default selection
            
            selectInput(inputId = "year", label = "Year:", choices = c("current", 
                                                                             "2050", 
                                                                             "2100"),
                                                                    selected = "current"), #sets default selection
            selectInput(inputId = "scenario", label = "RCP Scenario:", choices = c("current", 
                                                                                   "RCP26", 
                                                                                   "RCP45", 
                                                                                   "RCP60", 
                                                                                   "RCP85"),
                                                                   selected = "current") #sets default selection
        ),

        # Show a plot of the generated distribution
        mainPanel(
           plotOutput("distPlot")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
    
  
  
    output$distPlot <- renderPlot({
      speciesPoints <- get_species_data(input$species)
      pres <- extractEnvData(envRasterStack, speciesPoints) |> mutate(pa=1)
      allData <- rbind(pres, abs)
      qplot(allData[2], allData[3])
      
      presence_absence_df <- allData %>%
        dplyr::select(pa)
      
      environmental_df <- allData %>%
        dplyr::select(-c(pa))
      
      # Ensure that 'Presence' column is extracted as a numeric vector
      presence_absence_vector <- presence_absence_df$pa
      
      # Fit the MaxEnt model
      sdm.model <- maxnet::maxnet(p = presence_absence_vector, data = environmental_df)
      
      future_layers <- sdmpredictors::list_layers_future(marine = TRUE) %>% 
        filter(current_layer_code %in% c(vars$envVars)) %>% 
        filter(year == input$year) %>% 
        filter(scenario == input$scenario) %>% 
        filter(model == "AOGCM")
      future_layers_list <- future_layers$layer_code
      
      obj1 <- get_enviro_data(future_layers_list[1])
      obj2 <- get_enviro_data(future_layers_list[2])
      obj3 <- get_enviro_data(future_layers_list[3])
      obj4 <- get_enviro_data(future_layers_list[4])
      obj5 <- get_enviro_data(future_layers_list[5])
      concat <- c(obj1, obj2, obj3, obj4, obj5)
      names(concat) <- future_layers$current_layer_code
      
      clamp <- TRUE      
      type <- "logistic"
      
      # Predict species distribution within the cropped area
      predicted <- predict(sdm.model, concat, clamp = clamp, type = type)
      
      plot(predicted)
      
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
