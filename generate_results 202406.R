### Script to run summarisations from the run_instructions file
# Please edit the following inputs if necessary

TABLE_NAME <- "[master_table_202406]"
REGION_LIST <- c("POPULATION","REGC","TALB")
FILE_SUFFIX = "RDP_"
FILE_DATE = format(Sys.Date(),"%Y%m%d")


RUN_UNIT_TESTS <- FALSE

# Libraries ---------------------------------------------------------------

library(DBI)
library(dbplyr)
library(dplyr)
library(digest)
library(explore)
library(glue)
library(readxl)
library(rlang)
library(testthat)
library(tibble)
library(tidyr)
library(tools)
library(here)

# PATHS -------------------------------------------------------------------

PATH_TO_LIBRARIES <- here("Libraries")
PATH_TO_TEST <- here("Test")
PATH_TO_LOGS <- here("Logs")
PATH_TO_FOR_CHECKING <- here("Checking")
PATH_TO_SUMMARISE <- here("Summarise_Confidentialise")

# User defined global variables -------------------------------------------

# Custom functions (e.g. 'run_files_in_dir') 

source(file.path(PATH_TO_LIBRARIES, "custom_utility_functions.R"))
source(file.path(PATH_TO_LIBRARIES, "column_combination_options.R"))

# DAT Modules (and gv_user_variables) -------------------------------------

run_files_in_dir(file.path(PATH_TO_LIBRARIES, "DAT"))
source(file.path(PATH_TO_LIBRARIES, "gv_user_variables.R"))
DEFAULT_DATABASE <- "IDI_CLEAN_202406" #default updated to June 2024

# Unit tests on DAT functions ---------------------------------------------

if (RUN_UNIT_TESTS){
  our_db <- SANDPIT
  our_usercode <- "[IDI_UserCode]"
  our_schema <- "[DL-MAA2023-55]" #just changed, need to replicate master_query in new env
  testthat::test_dir(here("tests"),
                     stop_on_failure = TRUE,
                     stop_on_warning = TRUE) 
  
  rm(our_db, our_usercode, our_schema)
}


# Begin

run_time_inform_user("GRAND START", context = "heading", print_level = "all")



# Access dataset ----------------------------------------------------------

db_con <- create_database_connection(database = OUTPUT_DATABASE)

measures <- read.csv(file.path(here(),"run_instructions.csv"), colClasses = "character", stringsAsFactors = FALSE)

# Loop through indicators to summarise one at a time, because of computing 
# bottleneck to do this all at once


for (k in seq(1,nrow(measures))){
  print(k)
  if(measures$run[k]){
        measure <- measures$name[k]
      master_table <- create_access_point(db_con,
                                          OUTPUT_DATABASE,
                                          OUTPUT_SCHEMA,
                                          TABLE_NAME)
      source(here("do_it.R"))
    }
}

# close )
close_database_connection(db_con)
run_time_inform_user("grand completion", context = "heading", print_level = "all")
