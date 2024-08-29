# ohw24_proj_sdm_us

## Maine Icons: a species distribution model and educational tool to highlight Gulf of Maine creatures

### Overview

This project was developed during OceanHackWeek 2024. The goal of this project was to develop an interactive educational tool using `R` to display a map showing the predicted distribution of basking sharks (Cetorhinus *maximus*) in the Gulf of Maine over time. 

### Roadmap

1. **Gathering basking shark occurrence data**
We first defined our spatio-temporal bounds:
Space: Gulf of Maine; latitude longitude boundaries: (42, -71, 45, -64)
Time: 2000-2024
Then, we gathered basking shark occurrence data from within these bounds and created a binary presence/absence column for analysis, using our 1000 background points as absences.

2. **Gathering observational environmental data**
We picked certain environmental variables we were interested in, which were sea surface temperature, bottom temperature, sea surface salinity, bottom salinity, dissolved oxygen, chlorophyll concentration, depth, and pH.
We then found these variables in our set bounds 

3. 
4. 

### Data

**Biological**

We obtained data for occurrence of basking sharks in our area of interest from the [Ocean Biodiversity Information System (OBIS)] (https://obis.org/) via the `robis` package. Since absences were not recorded in this data, we generated 1000 random background points (pseudo-absences). 

**Environmental**

We obtained environmental data from [Bio-ORACLE] (https://www.bio-oracle.org/) and used the `stars` package to 

We used predictions of future environmental conditions from the `maxnet` to create our final SDM.

## Collaborators

| Name                | Role                |
|---------------------|---------------------|
| Ben                 | Project Mentor      |
| Hallie              | Participant         |
| Jessie              | Participant         |
| Mugdha              | Participant         |

## Planning

* Initial idea: "short description"
* Ideation jam board: Add link
* Ideation Presentation: Add link
* Slack channel: ohw24_proj_name
* Project google drive: Add link
* Final presentation: Add link

## Background

## Goals

## Datasets

## Workflow/Roadmap

## Results/Findings

## Lessons Learned

## References

