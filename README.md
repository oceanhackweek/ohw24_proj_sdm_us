# ohw24_proj_sdm_us

## Maine Icons: A Species Distribution Model and Educational Tool to Highlight Gulf of Maine Creatures

### Overview

This project was developed during [OceanHackWeek 2024](https://oceanhackweek.org/ohw24/) with the goal of creating an interactive tool using `R` to show the predicted distribution of some iconic Gulf of Maine species. 

### Data

**Biological**

We obtained species occurrence data from the [Ocean Biodiversity Information System (OBIS)](https://obis.org/) via the `robis` package. Since absences were not recorded in this data, we generated 1000 random background points (pseudo-absences). 

**Environmental**

We obtained environmental data from [Bio-ORACLE](https://www.bio-oracle.org/) and used the `stars` package to wrangle the raster files.

We used predictions of future environmental conditions from the Atmosphere/Ocean General Circulation Model (AOGCM).

### Roadmap

1. **Gather species occurrence data**

We first defined our spatio-temporal bounds, using the latitude-longitude boundaries of (42, -71, 45, -64) to define our Gulf of Maine area of interest, and time boundaries of 2000-2020. Then, we cropped our occurrence data to fit these bounds and created a binary presence/absence column for analysis, using 1000 background points as absences. We also made a function to gather species data from OBIS using a section called "species" so that we could create models for more than one species.

2. **Gather observational environmental data**

We picked some environmental variables we were interested in, including surface temperature, bottom temperature, surface salinity, bottom salinity, and surface chlorophyll concentration. We then found these variables in our set bounds.

3. **Prep data for model**

We created a YAML file with the names of species, latitude-longitude boundaries, start and end years for data, and all the environmental covariate layers we wanted to include to make it easy for our function to pull the data it needed (rather than us having to input it every time). We then created functions to call data from the YAML file into the model.

5. **Make model**

Using the `maxnet` package and our occurrence and environmental dataframes, we created a logistic model to plot response curves.

6. **Predict and visualize**

We selected the AOGCM climate model and scenarios RCP26, RCP45, RCP60, and RCP85 to predict future environmental conditions for our area of interest, and concatenated the environmental data raster files into a raster stack. Then, we plotted the suitability of the environment for the species on a scale of 0-1 (1 being most suitable). We took the raster image for this plot and used the `leaflet` package to put it on a geographical map.

7. **Develop tool**

Lastly, we created an R Shiny app to make our model accessible and interactive. We added dropdown boxes for users to select from five different species, year (current, 2050, or 2100), and climate scenarios to visualize SDMs on a map for their selected inputs.

## Collaborators

| Name                | Role                |
|---------------------|---------------------|
| Ben                 | Project Mentor      |
| Hallie              | Participant         |
| Jessie              | Participant         |
| Mugdha              | Participant         |
