# Load the libraries
#-------------------------------------------------------------
library(here)
library(dplyr)

# Load the parameters for the indicator
#-------------------------------------------------------------
PREFIX <- measures$prefix[k]
SERIES_NAME <- measures$series_name[k]
RUNDATE <- measures$rundate[k]
SUMMARISATION_TYPE <- measures$summarisation_type[k]
RES_POP <- measures$res_pop[k]
OTHER_SUPERSET_PREFIX <- measures$other_superset_prefix[k]
AGE_RDP <- measures$age_rdp[k]
SECOND_RUN <- measures$second_run[k]
BESPOKE_AGE <- measures$bespoke_age[k]
ROUNDING_TYPE <- measures$rounding[k]


# Get the necessary file locations
#-------------------------------------------------------------
  
file <- paste0('RDP_',  PREFIX, '_', SERIES_NAME, '_', RUNDATE, '.csv')

if (SECOND_RUN == FALSE){
  file_loc <- file.path(here(),'Results', file)
} else if (SECOND_RUN == TRUE){
  file_loc <- file.path(here(),'Results', 'Sub_grp_adjusted', file)
}

sub_grp_adj_files <- list.files(path=paste0(here::here(),'/Results/Sub_grp_adjusted/'), pattern = paste0('(',RUNDATE, ')'))

# Where the superset is not the resident population, get the filename of the other superset
if (!is.na(OTHER_SUPERSET_PREFIX)){
  for (filename in sub_grp_adj_files){
    
    if (strsplit(filename, '_')[[1]][2] == OTHER_SUPERSET_PREFIX){
      OTHER_SUPERSET <- filename
    }
  }
}else {
  OTHER_SUPERSET <- NA
}

df_to_adapt <- read.csv(file_loc)

# Compare to other super group indicator files - resident population or other
#----------------------------------------------------------------------------------------------
  
  if (SUMMARISATION_TYPE == 'counts' & RES_POP == TRUE ){
    
    # Getting the filename for the resident population as the first file that is generated
    
    for (filename in list.files(path='./Results/Sub_grp_adjusted/')){
      if (strsplit(filename, '_')[[1]][2] == 1){
        res_pop_filename <- filename
      }}
    
    pop_df <- read.csv(file.path(here(),'Results', 'Sub_grp_adjusted', res_pop_filename))
    
    # Where there is a bespoke age group, mutate the res pop file to have the same age bands so that the files can be matched
    if (BESPOKE_AGE){
      
      if (!is.na(AGE_RDP)){
        
        # Filter the population df for the relevant age band
        pop_df <-pop_df %>% filter(col03 == "AGE_RDP", val03 == AGE_RDP)
      }
      
      # When it's a bespoke age band that spans a number of RDP age bands then match to the highest level
      else{
        pop_df <-pop_df %>% filter(is.na(col03), is.na(val03))
      }
      
      AGE_COLNAME <- unique(df_to_adapt$col03)
      AGE_VAL <- unique(df_to_adapt$val03)
      
      pop_df <- pop_df %>% mutate(col03 = case_when(AGE_COLNAME != "AGE_RDP" ~ AGE_COLNAME,
                                                    TRUE ~ col03),
                                  val03 = case_when(AGE_COLNAME != "AGE_RDP" ~ AGE_VAL,
                                                    TRUE ~ val03))
    }
    
    vals <- df_to_adapt %>% select(any_of(c("non_existent","col01", "val01", "col02", "val02", "col03", "val03", "col04","val04", "col05","val05", "col06","val06"))) %>% names
    
    # left join with population on vals and if any of the conf_distinct values
    if (ROUNDING_TYPE == 'RR3'){
      df_to_adapt <- df_to_adapt %>% 
        left_join(pop_df, by = vals) %>% 
        mutate(conf_distinct.x = case_when(conf_distinct.x > conf_distinct.y ~ conf_distinct.y, TRUE ~ conf_distinct.x)) %>%
        rename(summarised_var = summarised_var.x, raw_distinct = raw_distinct.x, conf_distinct = conf_distinct.x) %>%
        select(any_of(colnames(df_to_adapt)))
      
    }
    
    # since the population is RR3 rounded there are some extra rules needed when comparing to a GRR rounded sub group
    else if (ROUNDING_TYPE == 'GRR'){
      print('Num cases when GRR is 18 and rounded differently')
      print(nrow(df_to_adapt %>% 
                   left_join(pop_df, by = vals) %>% filter(conf_distinct.x > conf_distinct.y & conf_distinct.x == 20)))
      
      print('Num cases where sub group bigger than super group')
      print(nrow(df_to_adapt %>% 
                   left_join(pop_df, by = vals) %>% filter(conf_distinct.x > conf_distinct.y & conf_distinct.x == 20 |
                                                             conf_distinct.x > conf_distinct.y & conf_distinct.x > 20 & conf_distinct.x <= 95 |
                                                             conf_distinct.x > conf_distinct.y & conf_distinct.x >= 100 & conf_distinct.x <= 990 |
                                                             conf_distinct.x > conf_distinct.y & conf_distinct.x >= 1000)))
      
      
      df_to_adapt <- df_to_adapt %>% 
        left_join(pop_df, by = vals) %>% 
        mutate(conf_distinct.x = case_when(conf_distinct.x > conf_distinct.y & conf_distinct.x == 20 ~ 18,
                                           conf_distinct.x > conf_distinct.y & conf_distinct.x > 20 & conf_distinct.x <= 95 ~ conf_distinct.x - 5, 
                                           conf_distinct.x > conf_distinct.y & conf_distinct.x >= 100 & conf_distinct.x <= 990 ~ conf_distinct.x - 10,
                                           conf_distinct.x > conf_distinct.y & conf_distinct.x >= 1000 ~ conf_distinct.x - 100,
                                           TRUE ~ conf_distinct.x)) %>%
        rename(summarised_var = summarised_var.x, raw_distinct = raw_distinct.x, conf_distinct = conf_distinct.x) %>%
        select(any_of(colnames(df_to_adapt)))
      
      df_to_adapt %>% 
        left_join(pop_df, by = vals) %>% filter(conf_distinct.x > conf_distinct.y & conf_distinct.x == 20)
    }
  }





if (SUMMARISATION_TYPE == 'counts' & !is.na(OTHER_SUPERSET)){
  super_df <- read.csv(file.path(here(),'Results', 'Sub_grp_adjusted', OTHER_SUPERSET))
  
  vals <- df_to_adapt %>% select(any_of(c("non_existent","col01", "val01", "col02", "val02", "col03", "val03", "col04","val04", "col05","val05", "col06","val06"))) %>% names
  
  # left join with population on vals and if any of the conf_distinct values
  df_to_adapt <- df_to_adapt %>% left_join(super_df, by = vals) %>% mutate(conf_distinct.x = case_when(conf_distinct.x > conf_distinct.y ~ conf_distinct.y, TRUE ~ conf_distinct.x)) %>%
    rename(any_of(c(summarised_var = "summarised_var.x", raw_distinct = "raw_distinct.x", ent_1="ent_1.x", ent_2="ent_2.x", ent_3="ent_3.x", conf_distinct = "conf_distinct.x"))) %>%
    select(any_of(colnames(df_to_adapt)))}


# Get the reg & talb codes
#---------------------------------------------------------------------------------------------------------
  reg_talbs <- read.csv(file.path('/nas/DataLab/MAA/MAA2023-55/RDP_Master/REGC_TALB.csv'))

# Firstly check for each quarter, that none of the Region counts for each breakdown exceed the Population counts (this is pretty unlikely / doesn't seem to happen)
# Then check for each quarter, for each Region, for all of the TALB's in that region, if they don't belong to another Region,
# check that the counts don't exceed the Regional counts.

# This loop directly updates the dataframe to reduce the count of places where the sub group has exceeded the super
# During this looping, also check that if there is only one TALB in a region, and that TALB only belongs to that region, then there should be consistent rounding

vals <- df_to_adapt %>% select(any_of(c("non_existent","col01", "val01", "summarised_var", "col03", "val03", "col04","val04", "col05","val05", "col06","val06"))) %>% names

# If we are dealing with sums, temporarily change the title
if (SUMMARISATION_TYPE == 'sum'){
  df_to_adapt <- df_to_adapt %>% rename(conf_distinct = conf_sum)
}


# Loop through the quarters and check each geographic level is smaller than the higher level
#-----------------------------------------------------------------------------------------------
  
  for (quarter in unique(df_to_adapt$val01)){
    pop <- df_to_adapt %>% filter(val01 == quarter, col02 == 'POPULATION')
    # Firstly check none of the regions have greater values than the populations
    
    for (reg in unique(reg_talbs[, 'REGC'])){
      reg_df <- df_to_adapt %>% filter(val01 == quarter, col02 == 'REGC', val02 == reg) %>% rename(reg_conf_distinct = conf_distinct)
      new_reg_df <- reg_df %>% left_join(pop, by=vals)
      new_reg_df <- new_reg_df %>% filter(reg_conf_distinct > conf_distinct) %>%
        select(any_of(c("col01", "val01", "col02.x", "val02.x", "summarised_var", "col03", "val03", "col04","val04", 
                        "col05","val05", "col06","val06", "raw_distinct.x", "ent_1.x","ent_2.x", "ent_3.x","conf_distinct"))) %>% 
        rename(any_of(c(col02 = "col02.x", val02 = "val02.x", raw_distinct = "raw_distinct.x", ent_1="ent_1.x", ent_2="ent_2.x", ent_3="ent_3.x")))
      
      if (nrow(new_reg_df) > 0){
        df_to_adapt <- rows_update(df_to_adapt, new_reg_df, by=c(colnames(df_to_adapt[,-ncol(df_to_adapt)])))}
      
      
      # Then check TALB's within the regions 
      talbs <- reg_talbs %>% filter(REGC == reg) %>% select('TALB')
      
      for (talb in talbs[,'TALB']){
        # Filter the TALB REGC dataframe for when a TALB is only designated to one REGC
        if (nrow(reg_talbs %>% filter(TALB == talb)) == 1){
          talb_df <- df_to_adapt %>% filter(val01 == quarter, col02 == 'TALB', val02 == talb) %>% rename(talb_conf_distinct = conf_distinct)
          
          new_talb_df <- talb_df %>% left_join(reg_df, by=vals)
          
          # In the case that that TALB is the only TALB in the region, then we need to ensure the rounding is consistent for all cases, not just when sub is greater than super
          # Firstly check whether the area outside
          if (nrow(talbs) == 1){
            new_talb_df <- new_talb_df %>% filter(raw_distinct.x == raw_distinct.y) %>% 
              select(any_of(c("col01", "val01", "col02.x", "val02.x", "summarised_var", "col03", "val03", "col04","val04", 
                              "col05","val05", "col06","val06", "raw_distinct.x", "ent_1.x","ent_2.x", "ent_3.x","reg_conf_distinct"))) %>%
              rename(any_of(c(col02 = "col02.x", val02 = "val02.x", raw_distinct = "raw_distinct.x", ent_1="ent_1.x", ent_2="ent_2.x", ent_3="ent_3.x", conf_distinct = "reg_conf_distinct")))
            
          }
          else{
            
            new_talb_df <- new_talb_df %>% filter(talb_conf_distinct > reg_conf_distinct) %>% 
              select(any_of(c("col01", "val01", "col02.x", "val02.x", "summarised_var", "col03", "val03", "col04","val04", 
                              "col05","val05", "col06","val06", "raw_distinct.x", "ent_1.x","ent_2.x","ent_3.x", "reg_conf_distinct"))) %>%
              rename(any_of(c(col02 = "col02.x", val02 = "val02.x", raw_distinct = "raw_distinct.x", ent_1="ent_1.x",ent_2="ent_2.x",ent_3="ent_3.x", conf_distinct = "reg_conf_distinct"))) 
            
          }
          
          if (nrow(new_talb_df) > 0){
            df_to_adapt <- rows_update(df_to_adapt, new_talb_df, by=c(colnames(df_to_adapt[,-ncol(df_to_adapt)])))}
        }
        
      }}}


# Function to check rows within the dataframe
#---------------------------------------------------------------------------------------------------------
  
  check_super_sub <- function(super, sub, level){
    #just take the minimum because if it's greater than either then bad
    if (nrow(super) == 0){print(paste0('No superset at', level))}
    if (sub$conf_distinct > min(super$conf_distinct)){
      print('fixing')
      new_sub <- sub %>% mutate(conf_distinct = min(super$conf_distinct)) #change to super group rounded value
      df_to_adapt <<- rows_update(df_to_adapt, new_sub, by=c(colnames(df_to_adapt[,-ncol(df_to_adapt)]))) #update the existing file in place
    }
  }


# Define function to filter for the sub and super groups at each grouping level of the data
super_sub_comp <- function(qt, geog, geog_val, level){
  
  all <- df_to_adapt %>% filter(val01 == qt, col02 == geog, val02 == geog_val)
  
  if (level == 1){
    super <- all %>% filter(is.na(col03))
    subs <- all %>% filter(!is.na(col03), is.na(col04))
    
    if (nrow(subs) != 0) {
      
      for (sub_row in seq(1,nrow(subs))){
        # check all the cases where col03 and val03 = col03
        sub <- subs[sub_row,]
        check_super_sub(super, sub, level)
      }
      
    }
  }
  
  else if (level == 2){
    l2_all <- all %>% filter(!is.na(col04), is.na(col05))
    
    if (nrow(l2_all) != 0){
      for (sub_row in seq(1,nrow(l2_all))){
        # check all the cases where col03 and val03 = col03
        col03dim <- l2_all[sub_row,'col03']
        val03dim <- l2_all[sub_row,'val03']
        col04dim <- l2_all[sub_row,'col04']
        val04dim <- l2_all[sub_row,'val04']
        
        super <- rbind(all %>% filter(is.na(col04), col03==col03dim, val03==val03dim)  , #subsets from col03 and val03 values
                       all %>% filter(is.na(col04), col03==col04dim, val03==val04dim)) # subsets from col04 and val04 values
        
        sub <- l2_all[sub_row,]
        check_super_sub(super, sub, level)
      }
    }}
  
  else if (level == 3){
    l3_all <- all %>% filter(!is.na(col05))
    
    if (nrow(l3_all) != 0){
      for (sub_row in seq(1,nrow(l3_all))){
        # check all the cases where col03 and val03 = col03
        col03dim <- l3_all[sub_row,'col03']
        val03dim <- l3_all[sub_row,'val03']
        col04dim <- l3_all[sub_row,'col04']
        val04dim <- l3_all[sub_row,'val04']
        col05dim <- l3_all[sub_row,'col05']
        val05dim <- l3_all[sub_row,'val05']
        
        # at level 3, nothing at level 2 should be greater than anything at level 1, so can just check against all level 2 perms & combs
        super <- rbind(all %>% filter(is.na(col05), col03==col03dim, val03==val03dim, col04 == col04dim, val04 == val04dim)  , #subsets from col03 and val03 values
                       all %>% filter(is.na(col05), col03==col03dim, val03==val03dim, col04 == col05dim, val04 == val05dim) ,
                       all %>% filter(is.na(col05), col03==col04dim, val03==val04dim, col04 == col05dim, val04 == val05dim)) # subsets from col04 and val04 values
        
        sub <- l3_all[sub_row,]
        check_super_sub(super, sub, level)
      }
    }
  }
  
  else if (level == 4){
    l4_all <- all %>% filter(!is.na(col06))
    if (nrow(l4_all) != 0){
      
      for (sub_row in seq(1,nrow(l4_all))){
        # check all the cases where col03 and val03 = col03
        col03dim <- l4_all[sub_row,'col03']
        val03dim <- l4_all[sub_row,'val03']
        col04dim <- l4_all[sub_row,'col04']
        val04dim <- l4_all[sub_row,'val04']
        col05dim <- l4_all[sub_row,'col05']
        val05dim <- l4_all[sub_row,'val05']
        col06dim <- l4_all[sub_row,'col06']
        val06dim <- l4_all[sub_row,'val06']
        
        # at level 4, nothing at level 3 should be greater than anything at level 2, so can just check against all level 3 perms & combs
        
        
        super <- rbind(all %>% filter(is.na(col06), col03==col03dim, val03==val03dim, col04 == col04dim, val04 == val04dim, col05 == col05dim, val05 == val05dim)  , #subsets from col03 and val03 values
                       all %>% filter(is.na(col06), col03==col03dim, val03==val03dim, col04 == col04dim, val04 == val04dim, col05 == col06dim, val05 == val06dim) ,
                       all %>% filter(is.na(col06), col03==col03dim, val03==val03dim, col04 == col05dim, val04 == val05dim, col05 == col06dim, val05 == val06dim) ,
                       all %>% filter(is.na(col06), col03==col04dim, val03==val04dim, col04 == col05dim, val04 == val05dim, col05 == col06dim, val05== val06dim)) # subsets from col04 and val04 values
        
        
        sub <- l4_all[sub_row,]
        
        check_super_sub(super, sub, level)
        
      }
    }
    
  }}


# Execute sub group checking within the file for each level of column value breakdown
#---------------------------------------------------------------------------------------------------------
 
  # Unique list of quarters & geographies
  qt_geog <- unique(df_to_adapt[,c('val01', 'col02', 'val02')])

if(!BESPOKE_AGE){
  for (row in 1:nrow(qt_geog)){
    qt <- qt_geog[row, 'val01']
    geog <- qt_geog[row, 'col02']
    geog_val <- qt_geog[row, 'val02']
    super_sub_comp(qt, geog, geog_val, 1)}}

for (row in 1:nrow(qt_geog)){
  qt <- qt_geog[row, 'val01']
  geog <- qt_geog[row, 'col02']
  geog_val <- qt_geog[row, 'val02']
  super_sub_comp(qt, geog, geog_val, 2)}

for (row in 1:nrow(qt_geog)){
  qt <- qt_geog[row, 'val01']
  geog <- qt_geog[row, 'col02']
  geog_val <- qt_geog[row, 'val02']
  super_sub_comp(qt, geog, geog_val, 3)}

for (row in 1:nrow(qt_geog)){
  qt <- qt_geog[row, 'val01']
  geog <- qt_geog[row, 'col02']
  geog_val <- qt_geog[row, 'val02']
  super_sub_comp(qt, geog, geog_val, 4)}


# If summarisation type was sum then change the name back
if (SUMMARISATION_TYPE == 'sum'){
  df_to_adapt <- df_to_adapt %>% rename(conf_sum = conf_distinct)
}


# Save file
#---------------------------------------------------------------------------------------------------------------------
write.csv(df_to_adapt, file.path(here(),'Results', 'Sub_grp_adjusted', file) , row.names = FALSE)

