### File joining 
### Status: under development


library(here)
library(dplyr)
library(stringr)

run_start_time <- Sys.time()

TOPIC <- measures$TOPIC[k]
PREFIXES <- measures$PREFIXES[k]
PREFIXES <- as.list(strsplit(PREFIXES, ',')[[1]])

USE_ENTS <- measures$USE_ENTS[k]
ENT_1_THRESHOLD <- measures$ENT_1_THRESHOLD[k]
ENT_2_THRESHOLD <- measures$ENT_2_THRESHOLD[k]
ENT_3_THRESHOLD <- measures$ENT_3_THRESHOLD[k]
COUNT_THRESHOLD <- measures$COUNT_THRESHOLD[k]
SUM_THRESHOLD <- measures$SUM_THRESHOLD[k]
SCHOOL_ADJUST <- measures$SCHOOL_ADJUST[k]
LOCATION <- measures$LOCATION[k]
RUNDATE <- paste0('(',measures$RUNDATE[k], ')')

ROUNDING_TYPE <- measures$ROUNDING_TYPE[k]
SUMMARISATION_TYPE <- measures$SUMMARISATION_TYPE[k]

if (SUMMARISATION_TYPE == 'COUNT'){
  THRESHOLD_USED <- COUNT_THRESHOLD
} else if (SUMMARISATION_TYPE == 'SUM'){
  THRESHOLD_USED <- SUM_THRESHOLD
}

# Process all files listed as the prefixes. 
# Need to manually check that the files loaded have conf rules that are compatible with each other
# Need to also check that these rules match the settings at the start of the script.

#### Establish location

dat<- tibble()

file_names <- list.files(path=paste0(here::here(),'/Results/Sub_grp_adjusted/'), pattern = RUNDATE)

for (ff in file_names){
  if (strsplit(ff, '_')[[1]][2] %in% PREFIXES){
    print(paste0("Reading and binding ",ff))
    new_dat <- read.csv(paste0(here::here(),'/Results/Sub_grp_adjusted/', ff))
    dat<- rbind(dat,new_dat)
    rm(new_dat)
  }
  
}

# Set everything to character. This is necessary as some columns will be read as factors (but need to be manipulated) and to prevent (for eg) scientific notation for certain SA2 numbers
dat <- dat %>% mutate(across(.cols=everything(),.fns = as.character))   


dat <- dat %>% filter(!(val01 %in% c('2020Q3','2020Q4')))

# Inspect


# Rename col/val 03 and 04 where ethnicity involved, so that ethnicity is column name and the group is the value 
dat <- dat %>% mutate(val03 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") ~ col03,
                                        TRUE ~ val03),
                      col03 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") ~ "ethnicity",
                                        TRUE ~ col03),
# Ethnicity shouldn't appear in col04 but in case configurations are changed
                      val04 = case_when(col04 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") ~ col04,
                                        TRUE ~ val04),
                      col04 = case_when(col04 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") ~ "ethnicity",
                                        TRUE ~ col04))


#Rename some  column values to save space
dat<- dat %>% mutate(col03 = case_when(col03 == "swa_urban_rural_ind" ~ "UR_ind",
                                       TRUE ~ col03),
                     col04 = case_when(col04 == "swa_urban_rural_ind" ~ "UR_ind",
                                       TRUE ~ col04),
                     col05 = case_when(col05 == "swa_urban_rural_ind" ~ "UR_ind",
                                       TRUE ~ col05),
                     col06 = case_when(col06 == "swa_urban_rural_ind" ~ "UR_ind",
                                       TRUE ~ col06),
                     col03 = case_when(col03 == "sex_no_gender" ~ "sex",
                                       TRUE ~ col03),
                     col04 = case_when(col04 == "sex_no_gender" ~ "sex",
                                       TRUE ~ col04),
                     col05 = case_when(col05 == "sex_no_gender" ~ "sex",
                                       TRUE ~ col05),
                      col03 = case_when(col03 == "AGE_RDP" ~ "AGE_LCY",
                                        TRUE ~ col03),
                      col04 = case_when(col04 == "AGE_RDP" ~ "AGE_LCY",
                                        TRUE ~ col04))


dat <- dat %>% mutate(col01 = "period") #might be possible to delete?
dat <- dat %>% mutate(summarised_var = gsub(x =summarised_var,pattern =  "Accomidation", replacement = "Accommodation")) # There is a typographical error in a benefit dataset - this fixes this error if it appears

#### Minimum sizes
# Entities
if("ent_1" %in% colnames(dat)){
      if(nrow(dat %>% filter(as.integer(ent_1) < ENT_1_THRESHOLD)) != 0){
        print("Ent_1 threshold failed")
        WRITE_OUTPUT <- FALSE 
      }
  }
if("ent_2" %in% colnames(dat)){
  if(nrow(dat %>% filter(as.integer(ent_2) < ENT_2_THRESHOLD)) != 0){
      print("Ent_2 threshold failed")
      WRITE_OUTPUT <- FALSE 
      }
}
if("ent_3" %in% colnames(dat)){
  if(nrow(dat %>% filter(as.integer(ent_3) < ENT_3_THRESHOLD)) != 0){
    print("Ent_3 threshold failed")
    WRITE_OUTPUT <- FALSE 
  }
}
# Individuals
if("raw_count" %in% colnames(dat)){
  if(nrow(dat %>% filter(as.integer(raw_count) < COUNT_THRESHOLD)) != 0){
      print("Count threshold failed")
      WRITE_OUTPUT <- FALSE 
      }
    }


if("raw_distinct" %in% colnames(dat)){
  if(nrow(dat %>% filter(as.integer(raw_distinct) < COUNT_THRESHOLD)) != 0){
    print("Distinct threshold failed")
    WRITE_OUTPUT <- FALSE 
  }
}


if("raw_sum" %in% colnames(dat)){
  if(nrow(dat %>% filter(as.integer(raw_sum) < SUM_THRESHOLD)) != 0){
    print("Sum threshold failed")
    WRITE_OUTPUT <- FALSE 
  }
}



#### Rounding correctly applied - will print message if it fails test
if(ROUNDING_TYPE == "GRR"){
          if("raw_count" %in% colnames(dat)){
            if(nrow(dat %>% 
                    mutate(raw_count = as.integer(raw_count), conf_count = as.integer(conf_count)) %>%
                    filter( (raw_count>=0 & raw_count<=18 & conf_count %% 3 !=0) |
                            (raw_count==19 & conf_count %% 2 !=0) |
                            (raw_count>=20 & raw_count<=99 & conf_count %% 5 !=0) |
                            (raw_count>=100 & raw_count<=999 & conf_count %% 10 !=0) |
                            (raw_count>=1000 & conf_count %% 100 !=0))
            )!= 0){
              print("GRR count failed")
              WRITE_OUTPUT <- FALSE}
          }

            if("raw_distinct" %in% colnames(dat)){
              if(nrow(dat %>% 
                      mutate(raw_distinct = as.integer(raw_distinct), conf_distinct = as.integer(conf_distinct)) %>%
                      filter( (raw_distinct>=0 & raw_distinct<=18 & conf_distinct %% 3 !=0) |
                                (raw_distinct==19 & conf_distinct %% 2 !=0) |
                                (raw_distinct>=20 & raw_distinct<=99 & conf_distinct %% 5 !=0) |
                                (raw_distinct>=100 & raw_distinct<=999 & conf_distinct %% 10 !=0) |
                                (raw_distinct>=1000 & conf_distinct %% 100 !=0))
              ) != 0) {
                print("GRR distinct failed")
                WRITE_OUTPUT <- FALSE}
            }
  
  
  if("raw_sum" %in% colnames(dat)){
    if(nrow(dat %>% 
            mutate(raw_sum = as.integer(raw_sum), conf_sum = as.integer(conf_sum)) %>%
            filter( (raw_sum>=0 & raw_sum<=18 & conf_sum %% 3 !=0) |
                    (raw_sum==19 & conf_sum %% 2 !=0) |
                    (raw_sum>=20 & raw_sum<=99 & conf_sum %% 5 !=0) |
                    (raw_sum>=100 & raw_sum<=999 & conf_sum %% 10 !=0) |
                    (raw_sum>=1000 & conf_sum %% 100 !=0))
    ) != 0) {
      print("GRR sum failed")
      WRITE_OUTPUT <- FALSE}
  }
          }
if(ROUNDING_TYPE == "RR3"){
              if("raw_distinct" %in% colnames(dat)){
                if(nrow(dat %>% 
                        mutate(raw_distinct = as.integer(raw_distinct), conf_distinct = as.integer(conf_distinct)) %>%
                        filter(conf_distinct %%3 !=0)
                ) != 0) {
                  print("RR3 distinct failed")
                  WRITE_OUTPUT <- FALSE}
              }
              if("raw_count" %in% colnames(dat)){
                if(nrow(dat %>% 
                        mutate(raw_count = as.integer(raw_count), conf_count = as.integer(conf_count)) %>%
                        filter(conf_count %%3 !=0)
                ) != 0) {
                  print("RR3 count failed")
                  WRITE_OUTPUT <- FALSE}
              }
              if("raw_sum" %in% colnames(dat)){
                if(nrow(dat %>% 
                        mutate(raw_sum = as.integer(raw_sum), conf_sum = as.integer(conf_sum)) %>%
                        filter(conf_sum %%3 !=0)
                ) != 0) {
                  print("RR3 sum failed")
                  WRITE_OUTPUT <- FALSE}
              }
             }

# We want to rename Population to Country when used to describe the geographic area.
dat<- dat %>% mutate(col02 = case_when(col02 == "POPULATION" ~ "COUNTRY",
                                 TRUE ~ col02))

if (SCHOOL_ADJUST){
  dat <- dat %>% mutate(col05 = case_when(col03 != 'AGE_prim_sec' ~ col04, TRUE ~ col05),
                        val05 = case_when(col03 != 'AGE_prim_sec' ~ val04, TRUE ~ val05),
                        col04 = case_when(col03 != 'AGE_prim_sec' ~ col03, TRUE ~ col04),
                        val04 = case_when(col03 != 'AGE_prim_sec' ~ val03, TRUE ~ val04),
                        col03 = case_when(col03 != 'AGE_prim_sec' | is.na(col03) ~ 'AGE_BESPOKE', TRUE ~ col03),
                        val03 = case_when(col03 != 'AGE_prim_sec' | is.na(col03) ~ as.character(10), TRUE ~ val03))
  
  dat <- dat %>% mutate(summarised_var = case_when(col03 == 'AGE_prim_sec' & val03 == 1 ~ paste0(summarised_var, '_', 'primary'),
                                                   col03 == 'AGE_prim_sec' & val03 == 2 ~ paste0(summarised_var, '_', 'secondary'),
                                                   TRUE ~ summarised_var),
                        val03 = case_when(col03 == 'AGE_prim_sec' ~ as.character(10),
                                          TRUE ~ val03),
                        col03 = case_when(col03 == 'AGE_prim_sec' ~ 'AGE_BESPOKE',
                                          TRUE ~ col03)
               
               )}


# Replace period with Q
dat<- dat %>% mutate(col01 = case_when(col01 == "period" ~ "Q",
                                         TRUE ~ col01))


    #### Write the file. If we need to append disclaimer and dictionary, do so here and change to write xlsx
write.csv(dat,
              paste0(here::here(),"/Outputs_for_submission/","RAW_SIA_IDI_RDP_",TOPIC,"_",gsub(Sys.Date(),pattern="-", replacement=""),".csv"),
              row.names=FALSE)

write.csv(dat %>% select(any_of(c("col01",	"val01",	"col02",	"val02",	"summarised_var",	"col03",	"val03",	"col04",	"val04", "col05", "val05",
                                  "col06","val06","conf_distinct","conf_count", "conf_sum"))),
              paste0(here::here(),"/Outputs_for_submission/","SIA_IDI_RDP_",TOPIC,"_",gsub(Sys.Date(),pattern="-", replacement=""),".csv"),
              row.names=FALSE)
