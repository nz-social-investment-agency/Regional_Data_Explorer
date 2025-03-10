#### File to automate the subgroup supergroup rounding 
## The order of completion matters here, so ensure any superset indicators are run before the subsets
library(here)
library(dplyr)


measures <- read.csv(file.path(here(), 'sub_super_run_file.csv')) %>%
  mutate(series_name = as.character(series_name),
         other_superset_prefix = as.numeric(other_superset_prefix),
         age_rdp = as.numeric(age_rdp))

# Loop through indicators to summarise one at a time, because of computing 
# bottleneck to do this all at once

SECOND_RUN <- FALSE

for (k in seq(1,nrow(measures))){
  print(k)
  if(measures$run[k]){
    source(here("supergroup_subgroup.R"))
  }
}
