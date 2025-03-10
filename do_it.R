# for (k in seq(1,nrow(measures))){
#     measure <- measures$name[k]
#     master_table <- create_access_point(db_con,OUTPUT_DATABASE,OUTPUT_SCHEMA,TABLE_NAME)
#     # execute the below instructions - via source("do_it.R")
# }

run_start_time <- Sys.time()
# We need regex in case we use Histogram summarisation during assembly, which changes the name of the column from XX to XX=YY
SUMMARISE_COUNT <- measures$summarise_count[k]
SUMMARISE_DISTINCT <- measures$summarise_distinct[k]
SUMMARISE_SUM <- measures$summarise_sum[k]
USE_ENTS <- measures$entity_join[k]
ROUNDING_TYPE <- measures$rounding[k]
ENT_1_THRESHOLD <- measures$ent_1_threshold[k]
ENT_2_THRESHOLD <- measures$ent_2_threshold[k]
ENT_3_THRESHOLD <- measures$ent_3_threshold[k]
USE_POPULATION_DEF <- measures$USE_POPULATION_DEF[k]
SERIES_NAME <- measures$series_name[k]
BESPOKE_AGE <- measures$bespoke_age[k]
AGE_COL <- measures$age_col[k] #1 or NULL values for the age
one_RDP_age_cat <- measures$one_RDP_age_cat[k]
MAX_QT <- measures$max_qt[k]

bespoke_age_dict <- c(
  "AGE_8MO"=1,
  "AGE_5YO"=2,
  "AGE_25YO"=3,
  "AGE_45YO"=4, 
  "AGE_65YO"=5,
  "AGE_0_2YO"= 6,
  "AGE_3_4YO" = 7,
  "AGE_2YO"=8, 
  "AGE_compulsory_school"=9,
  "AGE_school_aged"=10, 
  "AGE_GE15"=11,
  "AGE_18_24"=12,
  "AGE_25_39"=13,
  "AGE_40_54"=14,
  "AGE_55_64"=15
) #add when there are new bespoke ages

if(BESPOKE_AGE == TRUE){
  if (AGE_COL == 'AGE_prim_sec'){
    SUMMARY_TEMPLATE <- "Dimensions_school"}
  else{
    SUMMARY_TEMPLATE <- "Dimensions_bespoke_age" #"Dimensions_23_1_24" # "Dimensions_7_12_23" # age_specific, TALB_4_PHO, ECE_1_year_bands,  New_RDP, Default_dimensions     See columnn_combination_options.R
  }
} else {
  SUMMARY_TEMPLATE <- "Dimensions_default"
}

run_time_inform_user("creating cross products", context = "details", print_level = "all")
column_combinations <- make_column_combos(SUMMARY_TEMPLATE) 


DISTINCT_THRESHOLD <- COUNT_THRESHOLD

entity_table <- if(stringr::str_detect(measure,pattern = "(.+)(?=__)")){
  paste0("[",stringr::str_extract(measure,pattern = "(.+)(?=__)"),"_ENT]")
} else {
  paste0("[",measure,"_ENT]")
}

summaries <- c("count","distinct","sum")[c(SUMMARISE_COUNT,SUMMARISE_DISTINCT,SUMMARISE_SUM)]

run_time_inform_user("summarise", context = "details", print_level = "all")

# Alternative approach, just filter at the outset
# This works because of the way we have refactored to loop through all variables 
# and summarise one at a time. Not very elegant, but works and unlikely 
# to have problems scaling this.


working_table <- master_table %>%
  filter(!is.na(.data[[as.character(measure)]]))

if(USE_POPULATION_DEF){working_table <- working_table %>% filter(POPULATION == 1)}

if(BESPOKE_AGE == TRUE & AGE_COL != 'AGE_RDP' & AGE_COL != 'AGE_prim_sec'){
  working_table <- working_table %>% filter(.data[[as.character(AGE_COL)]] == 1)
}
if(BESPOKE_AGE == TRUE & AGE_COL == 'AGE_RDP'){
  working_table <- working_table %>% filter(.data[[as.character(AGE_COL)]] == one_RDP_age_cat)
}


# Reducing if there's a maximum quarter
if(!is.na(MAX_QT)){working_table <- working_table %>% filter(quarter <= MAX_QT)}

# Use existing summarise and confidentialise functions

# Confirm that, for sums, we can use COUNT of rows to correctly count distinct snz_uids (ie, data is one row per period and identity).
if(SUMMARISE_SUM){
  assert(
    nrow(
      working_table %>%
        group_by(quarter, snz_uid) %>% 
        summarise(n = n()) %>%
        filter( n> 1) %>% 
        collect()
    )==0,"Same identity included more than once in period. Cannot use COUNT to derive count of snz_uids."
  )
}

# Create summary table - summarise over snz_uid
summary <- summarise_and_label_over_lists(
  df = working_table,
  group_by_list = column_combinations,
  summarise_list = if(SUMMARISE_SUM){list(measure)}else{list("snz_uid")},
  make_distinct = SUMMARISE_DISTINCT,
  make_count = SUMMARISE_COUNT|SUMMARISE_SUM,
  make_sum = SUMMARISE_SUM,
  clean = "zero.as.na",
  remove.na.from.groups = TRUE)

summary <- summary %>%
  ungroup()


# # Join entity data

if(USE_ENTS){
  run_time_inform_user("Processing entity data",context = "heading",print_level = "all")
  
  ent <-create_access_point(db_con,SANDPIT,SCHEMA,entity_table)
  
  ent_table <-left_join(
    working_table,
    ent,
    by = c("snz_uid","quarter")
  )

  ent_summary <- summarise_and_label_over_lists(
    df = ent_table,
    group_by_list = column_combinations,
    summarise_list = list("entity_1"),
    make_distinct = TRUE,
    make_count = FALSE,
    make_sum = FALSE,
    clean = "zero.as.na",
    remove.na.from.groups = TRUE
  )
  
  ent_summary <- ent_summary %>%
    select(-summarised_var) %>%
    rename(ent_1 = distinct)
  
  summary <- summary %>% 
    left_join(
      ent_summary,
      by = setdiff(colnames(ent_summary),c("ent_1"))
    )
  
  
  
  #################################################################
  
  if("entity_2" %in% colnames(ent)){
    ent_summary2 <- summarise_and_label_over_lists(
      df = ent_table,
      group_by_list = column_combinations,
      summarise_list = list("entity_2"),
      make_distinct = TRUE,
      make_count = FALSE,
      make_sum = FALSE,
      clean = "zero.as.na",
      remove.na.from.groups = TRUE
    )
  
  ###
  # ent_summary <- ent_summary %>%
  #   left_join(ent_summary2 %>%
  #               select(-summarised_var) %>%
  #               rename(ent_2 = distinct),
  #             by = setdiff(colnames(ent_summary),c("ent_1","ent_2")))
  
  ent_summary2 <- ent_summary2 %>%
    select(-summarised_var) %>%
    rename(ent_2 = distinct)
  
  ####
  
  summary <- summary %>% 
    left_join(
      ent_summary2,
      by = setdiff(colnames(ent_summary),c("ent_1","ent_2"))
    )
  }
  
  
  #################################################################
  
  if("entity_3" %in% colnames(ent)){
    ent_summary3 <- summarise_and_label_over_lists(
      df = ent_table,
      group_by_list = column_combinations,
      summarise_list = list("entity_3"),
      make_distinct = TRUE,
      make_count = FALSE,
      make_sum = FALSE,
      clean = "zero.as.na",
      remove.na.from.groups = TRUE
    )

  ent_summary3 <- ent_summary3 %>%
    select(-summarised_var) %>%
    rename(ent_3 = distinct)
  
  ####
  
  summary <- summary %>% 
    left_join(
      ent_summary3,
      by = setdiff(colnames(ent_summary2),c("ent_2","ent_3"))
    ) #could be an error
  }
}

# Confidentialise ---------------------------------------------------------


summary_conf <- summary
for(ss in summaries){
  sup_col <- paste0("conf_",ss)
  
  
  SUMMARY_THRESHOLD <- get(paste0(toupper(ss),"_THRESHOLD"))
  
  run_time_inform_user(paste0("confidentialise - ",ss), context = "details", print_level = "all")
  
  
  summary_conf <- apply_small_count_suppression(df = summary_conf,
                                                suppress_cols = as.character(ss),
                                                threshold = SUMMARY_THRESHOLD)
  
  if("ent_1" %in% colnames(summary_conf)){
    summary_conf <- apply_small_count_suppression(df = summary_conf,
                                                  suppress_cols = as.character(ss),
                                                  threshold = ENT_1_THRESHOLD,
                                                  count_cols = c("ent_1"))
  }
  if("ent_2" %in% colnames(summary_conf)){
    summary_conf <- apply_small_count_suppression(df = summary_conf,
                                                  suppress_cols = as.character(ss),
                                                  threshold = ENT_2_THRESHOLD,
                                                  count_cols = c("ent_2"))
  }
  
  
  if("ent_3" %in% colnames(summary_conf)){
    summary_conf <- apply_small_count_suppression(df = summary_conf,
                                                  suppress_cols = as.character(ss),
                                                  threshold = ENT_3_THRESHOLD,
                                                  count_cols = c("ent_3"))
  }
  
  if(ss == "sum"){
    summary_conf <- apply_small_count_suppression(df = summary_conf,
                                                  suppress_cols = as.character(ss),
                                                  threshold = COUNT_THRESHOLD,
                                                  count_cols = c("count")) }
  if(ROUNDING_TYPE =="GRR"){
    all_cols = colnames(summary_conf)
    use_cols = all_cols[grepl("^col|^val|^summarised_var", all_cols)]
    summary_conf <- apply_graduated_random_rounding(summary_conf,
                                                    as.character(ss),
                                                    stable_across_cols = use_cols)
    
    
  }
  if(ROUNDING_TYPE == "RR3"){
    all_cols = colnames(summary_conf)
    use_cols = all_cols[grepl("^col|^val|^summarised_var", all_cols)]
    summary_conf <- apply_random_rounding(summary_conf,
                                          as.character(ss),
                                          stable_across_cols = use_cols)
    
  }
  
  summary_conf <- summary_conf %>%
    filter(!is.na(!!sym(paste0("conf_",ss))))
  
  # Test confidentialisation ------------------------------------------------
  results <- tibble(
    "Iteration" = k,
    "Measure" = measure,
    "Rounding" = ROUNDING_TYPE,
    "Rounding_check" = if(ROUNDING_TYPE=="RR3"){
      check_rounding_to_base_df(summary_conf,column = sup_col)
    } else {
      check_graduated_rounding_df(summary_conf,column = sup_col)
    },
    "Summarisation_produced" = ss,
    "Summarisation_threshold" = SUMMARY_THRESHOLD,
    "Small_count_ind_check" = check_small_count_suppression(
      summary_conf,
      suppressed_col = sup_col,
      count_col = paste0("raw_",ss),
      threshold = SUMMARY_THRESHOLD
    ),
    "ENT_1_THRESHOLD" = if(USE_ENTS){ENT_1_THRESHOLD}else{NA},
    "ENT_2_THRESHOLD" = if(USE_ENTS){ENT_2_THRESHOLD}else{NA},
    "ENT_3_THRESHOLD" = if(USE_ENTS){ENT_3_THRESHOLD}else{NA},
    "Small_count_ent_check1" = if("ent_1" %in% colnames(summary_conf)){
      check_small_count_suppression(summary_conf,suppressed_col = sup_col,count_col = "ent_1",threshold = ENT_1_THRESHOLD)
    }else{NA},
    "Small_count_ent_check2" = if("ent_2" %in% colnames(summary_conf)){
      check_small_count_suppression(summary_conf,suppressed_col = sup_col,count_col = "ent_2",threshold = ENT_2_THRESHOLD)
    }else{NA},
    "Small_count_ent_check3" = if("ent_3" %in% colnames(summary_conf)){
      check_small_count_suppression(summary_conf,suppressed_col = sup_col,count_col = "ent_3",threshold = ENT_3_THRESHOLD)
    }else{NA}
  )
  # Prepare the log
  fname <- file.path(here(), paste0("Check_conf_new.csv"))
  if(file.exists(fname)){confidentialise_log <- read.csv(fname)}else{confidentialise_log <- tibble()}
  
  confidentialise_log <- confidentialise_log  %>%
    rbind(results %>% mutate(Date = format(Sys.time(),"%D"), run_time = round(difftime(Sys.time(),run_start_time,units = 'mins'),0)))
  
  # Output confidentialisation results ----------------------------------------------
  
  run_time_inform_user("saving confidentialisation results", context = "details", print_level = "all")
  
  
  write.csv(confidentialise_log,file = fname,row.names = FALSE)
  rm(confidentialise_log, fname,results)
  
}


#edit column for output

summary_conf <- summary_conf %>%
  mutate(summarised_var = SERIES_NAME)

if(BESPOKE_AGE == TRUE & AGE_COL != 'AGE_RDP' & AGE_COL != 'AGE_prim_sec'){
  summary_conf <- summary_conf %>% mutate(
    col03 = case_when(
      col03 == AGE_COL ~ "AGE_BESPOKE",
      TRUE ~ col03),
    val03 = case_when(
      col03 == "AGE_BESPOKE" ~ as.character(bespoke_age_dict[AGE_COL]),
      TRUE ~ as.character(val03)),
    col04 = case_when(
      col04 == AGE_COL ~ "AGE_BESPOKE",
      TRUE ~ col04),
    val04 = case_when(
      col04 == "AGE_BESPOKE" ~ as.character(bespoke_age_dict[AGE_COL]),
      TRUE ~ as.character(val04))
  )
}

# Write for output --------------------------------------------------------

run_time_inform_user("writing excel output",
                     context = "heading",
                     print_level = "all")

SUMMARY_FILE <- paste(FILE_SUFFIX,as.character(k),"_",SERIES_NAME,"_",FILE_DATE,".csv",sep="")

write.csv(summary_conf %>%
            mutate(across(.cols = everything(),as.character)),
          file.path(here(),"Results", SUMMARY_FILE),row.names = FALSE)

# Output confidentialisation ----------------------------------------------

# run_time_inform_user("validating confidentialisation", context = "details", print_level = "all")
#
# fname <- file.path(PATH_TO_LOGS,
#                    "Mental Health",
#                    paste0("Check_conf_",as.character(k),"_",FILE_DATE,".txt"))
#
# sink(fname)
# print(check_confidentialised_results(summary_conf))
# sink()

## conclude ---------------------------------------------------------------------------------------
rm(summary)
rm(summary_conf)
