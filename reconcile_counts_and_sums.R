#### Run this script when there is a count and a sum based on the same population, and manual rounding is needed to avoid a miscount

library(dplyr)

count_file <- "D4C_NEW_SA2_21_mha_service_use_individuals_20230710.csv"
sum_file <- "D4C_NEW_SA2_22_mha_service_use_events_20230711.csv"
data_loc <- "Results"

setwd(file.path(here::here(),"New approach"))
count_dat<- read.csv(paste0(data_loc,"/",count_file))
sum_dat <- read.csv(paste0(data_loc,"/",sum_file))


str(count_dat)
str(sum_dat)


# The count data is the one that gets changed, and we should never have sums where we can't get counts. So we can take count data left join sum data.
dat <- count_dat %>% left_join(
                          sum_dat %>%
                            select(-summarised_var, -count),
                          by = c('col01','val01','col02','val02','col03','val03','col04','val04', 'ent_1'))
str(dat)

# follows advice from Stephen to Luke re output _20220519, on 8 June.

# Suppose raw count = 19, conf count = 21, sum = ??, conf sum = suppressed can only occur if the sum is less than 20. 
# Since: (1) the sum must be as high as the count; and (2) the count could be 19-23; we see the only possible value for the raw count and the sum is 19.

dat<- dat %>% mutate(conf_distinct = case_when(as.numeric(raw_distinct) == 19 & as.numeric(conf_distinct) == 21 & is.na(conf_sum) ~ as.integer(18),
                                         TRUE ~ as.integer(conf_distinct)))

# Second situation raised by Stephen: 
# raw_count = 20, count = 18 and sum = S

# It's not clear what this would tell us/how to handle this (and in any case the sum should be >=20 so should not be suppressed).
# We can check to make sure there are none of these cases in any case:

dat %>% filter(raw_distinct == 20 & conf_distinct == 18 & is.na(conf_sum))

# Theoretically, more generally we could have issues with conf_sum exceeding conf_distinct, which would reveal a more narrow range of values.
# We can look manually and see this does not arise:
dat %>% filter(!is.na(conf_sum) & conf_distinct >conf_sum)


 
dat<- dat %>% select(names(count_dat))

dat <- dat %>% mutate(across(.cols=everything(),.fns = as.character))   

unique(dat$val01)




write.csv(file = paste0(data_loc,"/",count_file), dat %>% select(names(count_dat)) %>% mutate(across(.cols=everything(),.fns = as.character)),row.names = FALSE)
write.csv(file = paste0(data_loc,"/",sum_file), sum_dat %>% mutate(across(.cols=everything(),.fns = as.character)),row.names = FALSE)

write.csv(file = paste0(data_loc,"/",count_file), dat %>% select(names(count_dat)) %>% select(-ent_1,-raw_distinct) %>% mutate(across(.cols=everything(),.fns = as.character)),row.names = FALSE)
write.csv(file = paste0(data_loc,"/",sum_file), sum_dat%>% select(-ent_1,-count,-raw_sum) %>% mutate(across(.cols=everything(),.fns = as.character)),row.names = FALSE)






