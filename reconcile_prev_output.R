# This code is intended to be used where a dataset has been previously released, and there is a rerun to correct a partial change.


# The logic behind it is that where all variables are the same (except for confidentialised counts) then the original rows are used. 
# Otherwise the new rows are used.
# This enables new data to overwrite the old in SID, rather than compare.


library(dplyr)

setwd(paste0(here::here()))
getwd()

file_loc1 <- './Results/Sub_grp_adjusted'
file_loc2 <- "./Results/Sub_grp_adjusted"

list.files(file_loc1, recursive = FALSE)

new_dat <- read.csv(file.path(file_loc1, "RDP_13_POPULATION_20240321.csv"))
old_dat <- read.csv(file.path(file_loc2, "RDP_13_POPULATION_20240126.csv"))

new_dat %>% filter(val01=='2021Q1',col02=='TALB', val02 == -99, col03 == 'AGE_RDP', val03==2, col04=='swa_urban_rural_ind', val04==-99)

new_dat %>% group_by(summarised_var) %>% summarise()
old_dat %>% group_by(summarised_var) %>% summarise()

#old_dat <- old_dat %>% filter(summarised_var == "POPULATION")

old_dat
new_dat

#AGE_RDP <- 2

names(old_dat)
old_dat <- old_dat %>% mutate(across(.cols=everything(),.fns = as.character)) %>% rename(old_conf = conf_distinct)  %>% select(-col01)


old_dat <- old_dat %>% mutate(val05 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col04 == "sex_no_gender" ~ val04, TRUE ~ val05),
                            col05 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col04 == "sex_no_gender"  ~ col04, TRUE ~ col05),
                            
                            val04 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col04 == "sex_no_gender" ~ val03, TRUE ~ val04),           
                            col04 = case_when(col03 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col04 == "sex_no_gender"  ~ col03, TRUE ~ col04),
                            
                            val03 = case_when(col04 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col05 == "sex_no_gender" ~ as.character(AGE_RDP), TRUE ~ val03),           
                            col03 = case_when(col04 %in% c("european", "maori", "pacific","asian","MELAA","other", "unknown_eth") & 
                                                col05 == "sex_no_gender" ~ "AGE_RDP", TRUE ~ col03))

# mutate 
#old_dat <- old_dat %>% filter(col03 == "AGE_RDP", val03 == "2")


new_dat <- new_dat %>% mutate(across(.cols=everything(),.fns = as.character)) %>% rename(new_conf = conf_distinct)   %>% select(-col01)

#new_dat<- new_dat %>% mutate(col03 = 'AGE_RDP', val03='2')


new_dat
old_dat

# dat : dataset with a value in the column 'old_conf' if nothing about the row changed, otherwise the column for that row is empty
# this one only joins where the raw_distinct is the same
vals <- new_dat %>% select(any_of(c("val01", "col02", "val02", "summarised_var", "raw_distinct", "col03", "val03", "col04","val04", "col05", "val05", "col06", "val06", "ent_1"))) %>% names

vals <- new_dat %>% select(any_of(c("val01", "col02", "val02", "summarised_var", "col03", "val03", "col04","val04", "col05", "val05", "col06", "val06", "ent_1"))) %>% names


#Testing greater than
#vals <- new_dat %>% select(any_of(c("val01", "col02", "val02", "col03", "val03", "col04","val04", "col05", "val05", "col06", "val06", "ent_1"))) %>% names

dat <- new_dat %>% left_join(old_dat, by = vals)

dat %>% filter(!is.na(old_conf)) %>% filter(old_conf != new_conf)

dat %>% filter(!is.na(old_conf)) %>% filter(as.integer(old_conf) < as.integer(new_conf))

dat
dat %>% filter(!is.na(old_conf)) %>% filter(old_conf != new_conf) %>% filter(abs(as.integer(old_conf) - as.integer(new_conf)) != 3) 

nrow(dat %>% filter(!is.na(old_conf)) %>% filter(old_conf < new_conf)) # leaves <0.1% of prior rows


# If we have a value for old_conf, we use it, otherwise we use the new value as something has changed.
dat <- dat %>% mutate(conf_distinct = case_when(is.na(old_conf) ~ new_conf, TRUE ~ old_conf)) %>% 
  select(-old_conf, -new_conf) %>% 
  mutate(col01 = "quarter") %>%
  relocate(col01, .before = val01)

# Turn to text and write
dat  <- dat %>% mutate(across(.cols = everything(),.fns= as.character))

write.csv(dat,file.path(file_loc1, "RDP_13_POPULATION_20240126_revised.csv"), row.names = FALSE)
