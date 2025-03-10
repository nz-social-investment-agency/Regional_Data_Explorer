library(here)
library(dplyr)


measures <- read.csv(file.path(here(),'combine_results_run_file.csv')) 
# %>%
#   mutate(other_superset_prefix = as.numeric(other_superset_prefix),
#          age_rdp = as.numeric(age_rdp))

# Loop through indicators to summarise one at a time, because of computing 
# bottleneck to do this all at once



for (k in seq(1,nrow(measures))){
  print(k)
  if(measures$RUN[k]){
    source(here("combine_results_for_output.R"))
  }
}
