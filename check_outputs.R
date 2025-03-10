getwd()

library(dplyr)

list.dirs("../_For Checking/Dan",recursive = FALSE)


#################################### We see MHA_use_users is missing categories

list.files("../_For Checking/Dan/RR3 COUNT submission", recursive = FALSE)
chk<- read.csv("../_For Checking/Dan/RR3 COUNT submission/CONF_SWA_D4C_RR3_COUNT6_ENT_2_2023_06_12.csv")

chk %>% group_by(summarised_var, col03, col04) %>% summarise

chk<- read.csv("../_For Checking/Dan/RR3 COUNT submission/RAW_SWA_D4C_RR3_COUNT6_ENT_2_2023_06_12.csv")






#################################### We see MHA_use_events is missing categories

list.files("../_For Checking/Dan/GRR SUM submission")
chk<- read.csv("../_For Checking/Dan/GRR SUM submission/CONF_SWA_D4C_GRR_SUM20_ENT_2_2023_06_12.csv")

chk %>% group_by(summarised_var, col03, col04) %>% summarise


list.files("../_For Checking/Dan/GRR SUM submission")
chk<- read.csv("../_For Checking/Dan/GRR SUM submission/RAW_SWA_D4C_GRR_SUM20_ENT_2_2023_06_12.csv")

chk %>% group_by(summarised_var, col02, col03, col04) %>% summarise


chk<- chk %>% mutate(val03 = case_when(
  col03 == 'ethnicity' & val03 == '1' ~ 'european',
    col03 == 'ethnicity' & val03 == '2' ~ 'maori',
    col03 == 'ethnicity' & val03 == '3' ~ 'pacific',
    col03 == 'ethnicity' & val03 == '4' ~ 'asian',
    col03 == 'ethnicity' & val03 == '5' ~ 'MELAA',
    col03 == 'ethnicity' & val03 == '6' ~ 'other',
    TRUE ~ val03))


###################################


list.files("../_For Checking/Dan/")
chk<- read.csv("../_For Checking/Dan/CONF_SWA_D4C_GRR_COUNT6_ENT_3_2023_06_09.csv")
chk %>% group_by(col03, col04) %>% summarise


chk<- read.csv("../_For Checking/Dan/RAW_SWA_D4C_GRR_COUNT6_ENT_3_2023_06_09.csv")
chk %>% group_by(col03, col04) %>% summarise






# compare original to updated

chk_dat <- dat %>% filter(!is.na(col03),!is.na(col04))
all(chk==chk_dat)






