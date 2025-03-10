# DATABASE LOCATIONS ------------------------------------------------------

SANDPIT = "[IDI_Sandpit]"
USERCODE = "[IDI_UserCode]"
SCHEMA = "[DL-MAA2023-55]"
REFRESH = "IDI_Clean_202310"

## USER CONTROLS ----------------------------------------------------------------------------

COUNT_THRESHOLD = 6
SUM_THRESHOLD = 20

# OUTPUTS
OUTPUT_DATABASE <- SANDPIT
OUTPUT_SCHEMA <- SCHEMA

## OTHER VARIABLES ----------------------------------------------------------------------------
OVERWRITE_EXISTING_TABLES <- TRUE
INDEX_COLUMNS = c("label_summary_period","POPULATION")

# BUILD LOG FILE ----------------------------------------------------------

BUILD_LOG_FILE <- paste0("build_log_", format(Sys.Date(), "%Y%m%d"), ".csv")
