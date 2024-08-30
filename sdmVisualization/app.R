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


###########################################################################################################################

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Gulf of Maine Species in a Changing Climate"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            selectInput(inputId = "species", label = "Species:", choices = c("Doryteuthis_pealeii", 
                                                                             "Cetorhinus_maximus"),
                                                            selected = "Cetorhinus_maximus"), #sets default selection
            
            selectInput(inputId = "year", label = "Year:", choices = c("current", 
                                                                             "2050", 
                                                                             "2100"),
                                                                    selected = "current"), #sets default selection
            
            #only allow scenarios to appear when present is not selected.
            conditionalPanel(
              condition = "input.year != 'current'",
              selectInput(inputId = "scenario", label = "RCP Scenario:", choices = c("RCP26", 
                                                                                     "RCP45", 
                                                                                     "RCP60", 
                                                                                     "RCP85"),selected = "RCP26"))
        ),

        # display leaflet map and fun facts in main panel.
        mainPanel(
          tabsetPanel(
            tabPanel("Species Distribution Maps",
            leafletOutput("sdmMap"),
            "*",
            span(textOutput("speciesFact"), style="color:navy; font-size:20px")
            ), tabPanel("Refrences and Information",
                        "Data:

    OBIS (2023) Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org. Accessed: 2024-08-27

    Assis, J., Fernández Bejarano, S.J., Salazar, V.W., Schepers, L., Gouvêa, L., Fragkopoulou, E., Leclercq, F., Vanhoorne, B., Tyberghein, L., Serrão, E.A., Verbruggen, H., De Clerck, O. (2024) Bio-ORACLE v3.0. Pushing marine data layers to the CMIP6 Earth system models of climate change research. Global Ecology and Biogeography. DOI: 10.1111/geb.13813. Accessed: 2024-08-27

Packages:

    Provoost P, Bosch S (2022). robis: Ocean Biodiversity Information System (OBIS) Client. R package version 2.11.3, https://CRAN.R-project.org/package=robis.

    Bosch S, Fernandez S (2023). sdmpredictors: Species Distribution Modelling Predictor Datasets. R package version 0.2.15, https://CRAN.R-project.org/package=sdmpredictors.

    Phillips S (2021). maxnet: Fitting 'Maxent' Species Distribution Models with 'glmnet'. R package version 0.1.4, https://CRAN.R-project.org/package=maxnet.

    Pebesma E (2021). stars: Spatiotemporal Arrays, Raster and Vector Data Cubes. R package version 0.5-5, https://CRAN.R-project.org/package=stars.

    Cheng J, Karambelkar B, Xie Y (2022). leaflet: Create Interactive Web Maps with the JavaScript 'Leaflet' Library. R package version 2.1.1, https://CRAN.R-project.org/package=leaflet.

Other:

    Wikipedia contributors. Representative Concentration Pathway. Wikipedia, The Free Encyclopedia. Wikipedia, The Free Encyclopedia, 15 Aug. 2024. Web. Accessed: 2024-08-30

    “Cetorhinus Maximus.” Discover Fishes, www.floridamuseum.ufl.edu/discover-fish/species-profiles/cetorhinus-maximus/. Accessed 30 Aug. 2024.

    Fisheries, NOAA. “Longfin Squid.” NOAA, 22 Aug. 2024, www.fisheries.noaa.gov/species/longfin-squid."
                        )
            )
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
    
  
    output$sdmMap <- renderLeaflet({
      #data created from loadRasters.R. NOTE: needed to be renamed manually to remove spaces. 
      allData <- read.csv(paste0("SpeciesData/", input$species, "_currentPresAbs.csv")) %>% 
        dplyr::select(-c(X)) #important!
      
      #select prescence and absence
      presence_absence_df <- allData %>%
        dplyr::select(pa)
      
      #get df of just environmental variables
      environmental_df <- allData %>%
        dplyr::select(-c(pa))
      
      # Ensure that 'Presence' column is extracted as a numeric vector
      presence_absence_vector <- presence_absence_df$pa
      
      # Fit the MaxEnt model
      sdm.model <- maxnet::maxnet(p = presence_absence_vector, data = environmental_df)
      
      #for current, just read current layers and project
      if (input$year == "current") {
        
        BO22_salinitymean_bdmax <- read_stars("rasterImgs/BO22_salinitymean_bdmax.Pres.cropped.tif")
        BO21_tempmean_bdmax <- read_stars("rasterImgs/BO21_tempmean_bdmax.Pres.cropped.tif")
        BO22_chlomean_ss <- read_stars("rasterImgs/BO22_chlomean_ss.Pres.cropped.tif")
        BO22_salinitymean_ss <- read_stars("rasterImgs/BO22_salinitymean_ss.Pres.cropped.tif")
        BO21_tempmean_ss <- read_stars("rasterImgs/BO21_tempmean_ss.Pres.cropped.tif")
        #need to concat (previously referred to as a rasterStack in the raster package)
        concatPres <- c(BO21_tempmean_bdmax, BO21_tempmean_ss, BO22_chlomean_ss, BO22_salinitymean_bdmax, BO22_salinitymean_ss)
        #Important to rename to the names in the model
        names(concatPres) <- c("BO21_tempmean_bdmax", "BO21_tempmean_ss", "BO22_chlomean_ss", "BO22_salinitymean_bdmax", "BO22_salinitymean_ss")
        
        #predict model for current
        predicted <- predict(sdm.model, concatPres) #, clamp = clamp, type = type) #, clamp = clamp, type = type)
        #Make map
        leaflet() %>% 
          addTiles() %>% 
          leafem::addStarsImage(predicted, 
                                colors = viridis::viridis(256), 
                                opacity = 0.8)
        
      } else {
        #list raster files from directory and get names after filtering for desired RCP and year projection
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
        
        #get rasters
        BO22_salinitymean_bdmax <- read_stars(paste0("rasterImgs/",names[1]))
        BO21_tempmean_bdmax <- read_stars(paste0("rasterImgs/",names[2]))
        BO22_chlomean_ss <- read_stars(paste0("rasterImgs/",names[3]))
        BO22_salinitymean_ss <- read_stars(paste0("rasterImgs/",names[4]))
        BO21_tempmean_ss <- read_stars(paste0("rasterImgs/",names[5]))
        #concatenate and rename to match model inputs
        concat2 <- c(BO21_tempmean_bdmax, BO21_tempmean_ss, BO22_chlomean_ss, BO22_salinitymean_bdmax, BO22_salinitymean_ss)
        names(concat2) <- c("BO21_tempmean_bdmax", "BO21_tempmean_ss", "BO22_chlomean_ss", "BO22_salinitymean_bdmax", "BO22_salinitymean_ss")
        
        clamp <- TRUE      
        type <- "logistic"
        
        # Predict species distribution within the cropped area
        
        predicted <- predict(sdm.model, concat2) #, clamp = clamp, type = type) #, clamp = clamp, type = type)
        #plot
    
        leaflet() %>% 
          addTiles() %>% 
          leafem::addStarsImage(predicted, 
                                colors = viridis::viridis(256), 
                                opacity = 0.8) 
      
      }
      
    })
    
    output$speciesFact <- renderText(
      if (input$species == "Cetorhinus_maximus") {
        "Fun Fact: Basking sharks are filter feeders and filter 2000 tons of seawater every hour for plankton."
        
      } else if (input$species == "Doryteuthis_pealeii") {
        "Fun Fact: Longfin squids sometimes eat animals bigger than themselves, including others of their own species."
      }
      
    )
}

# Run the application 
shinyApp(ui = ui, server = server)
