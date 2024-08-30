
library(yaml)
configList <- list(species = list("Doryteuthis pealeii", "Cetorhinus maximus",
                                  "Morone saxatilis", 
                                  "Homerus americanus", 
                                  "Salmo salar"),
                   latmin = 42,
                   latmax = 45,
                   lonmin = -71,
                   lonmax = -64,
                   version = "two",
                   start_year = 2000,
                   end_year = 2020,
                   years = list("2050", "2100"),
                   scenarios = list("RCP26", "RCP45", "RCP60", "RCP85"),
                   envVars = list("BO21_tempmean_bdmax", "BO21_tempmean_ss", "BO22_chlomean_ss", "BO22_salinitymean_bdmax", "BO22_salinitymean_ss")
)


config <- write_yaml(configList, "config2.yaml")



