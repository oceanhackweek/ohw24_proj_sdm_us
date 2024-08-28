
library(yaml)
configList <- list(species = list("Doryteuthis pealeii", "Cetorhinus maximus"),
               latmin = 42,
               latmax = 45,
               lonmin = -71,
               lonmax = -64,
               version = "one",
               start_year = 2000,
               end_year = "2020",
               envVars = list("pH", 
                              "Surface Temperature", 
                              "Bottom Temperature", 
                              "Dissolved Oxygen",
                              "Surface salinity",
                              "Bottom salinity",
                              "Chlorophyll",
                              "Depth")
                 )


config <- write_yaml(configList, "ohw24_proj_sdm_us/config.yaml")


