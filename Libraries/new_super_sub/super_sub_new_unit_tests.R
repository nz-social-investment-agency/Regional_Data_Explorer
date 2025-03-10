library(dplyr)
library(compare)
library(data.table)

unadjusted = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results"
adjusted = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/Sub_grp_adjusted"

unadj_files = list.files(unadjusted, pattern = "GEOG")
adj_files = list.files(adjusted, pattern = "GEOG")

for(file in unadj_files){
  name <- paste0(unadjusted, "/", file)
  unadj_file <- read.csv(name)
  
  name <- paste0(adjusted, "/", file)
  adj_file <- read.csv(name)
  
  ee <- c("raw_distinct", "conf_distinct")
  nn <- setdiff(colnames(adj_file), ee)
  
  jj <- inner_join(adj_file, unadj_file, by = nn, suffix = c("_ADJ", "_UNADJ"))
  ff <- dplyr::filter(jj, conf_distinct_ADJ != conf_distinct_UNADJ)
}



old_unadj <- read.csv(paste0(unadjusted, "/", "RDP_1_POPULATION_20240610.csv"))
old_adj <- read.csv(paste0(adjusted, "/", "RDP_1_POPULATION_20240619.csv"))



old_unadj


jj <- inner_join(old_adj, old_unadj, by = nn, suffix = c("_adj", "_unadj"))
View(jj)

old_results <- dplyr::filter(jj, conf_distinct_adj != conf_distinct_unadj)
View(old_results)

##################################################################################

unadjusted = "/nas/DataLab/MAA/MAA2023-55/RDP_Master/Results"
unadjusted2 = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results"
adjusted = "/nas/DataLab/MAA/MAA2023-55/RDP_Master/Results/Sub_grp_adjusted"

files <- list.files(unadjusted, pattern = "WSincome25YO")
files <- list.files(unadjusted, pattern = "POPULATION_20240711")

for (file in files){
  print(file)
  unadj <- read.csv(paste0(unadjusted, "/", file))
  unadj <- unadj %>% filter(val01 == "2023Q1",
                            col02 != "TALB")
  file <- gsub("20240716", "20240902", file)
  
  write.csv(unadj, paste0(unadjusted2, "/", file))
}
##################################################################################

old <- read.csv("/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/RDP_12_POPULATION_20240902.csv")
new <- read.csv("/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/Sub_grp_adjusted/RDP_12_POPULATION_20240902.csv")

View(old)

old <- old %>% filter(val01 == "2023Q1",
                      col02 != "TALB")

ee <- c("raw_distinct", "conf_distinct")
nn <- setdiff(colnames(ff), ee)

join_old <- inner_join(old, new, by = nn, suffix = c("_old", "_new"))
join_old
join_old_diff <- join_old %>% filter(conf_distinct_old != conf_distinct_new)
View(join_old_diff)
##################################################################################
# OLD/NEW method results comparison

old_adj <- "/nas/DataLab/MAA/MAA2023-55/RDP_Master/Results/Sub_grp_adjusted/"
new_adj <- "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/Sub_grp_adjusted/"

files_old <- list.files(old_adj, pattern = "POPULATION_20240711")
files_new <- list.files(new_adj, pattern = "POPULATION_20240902")

files_new

for(file in 1:length(files_old)){
  ff <- read.csv(paste0(old_adj, files_old[file]))
  ff <- ff %>% filter(val01 == "2023Q1",
                      col02 != "TALB")
  ffn <- read.csv(paste0(new_adj, files_new[file]))
  
  print(files_old[file])
  print("compare to: ")
  print(files_new[file])
  
  ee <- c("raw_distinct", "conf_distinct")
  nn <- setdiff(colnames(ff), ee)
  
  jj <- inner_join(ffn, ff, by =nn, suffix = c("_NEW", "_OLD"))
  fjj <- jj %>% filter(conf_distinct_NEW != conf_distinct_OLD)
  
  is_id <- identical(nrow(ff), nrow(ffn))
  is_id_conf <- identical(ff$conf_distinct, ffn$conf_distinct)
  all_eq <- all.equal(ff, ffn)
  
  
  if(nrow(fjj) > 0){
    print(nrow(fjj))
    print(fjj)
    
  }
  
  
  print("Identical row count: ")
  print(is_id)
  print("Identical conf_distinct: ")
  print(is_id_conf)
  print("comparison")
  print(compare(ff, ffn, allowAll = TRUE))
  print("-----------------------------------------------")
 

}

new_results <- read.csv(paste0("/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/Sub_grp_adjusted/RDP_4_POPULATION_20240902.csv"))
old_results <- read.csv(paste0("/nas/DataLab/MAA/MAA2023-55/RDP_Master/Results/Sub_grp_adjusted/RDP_4_POPULATION_20240711.csv"))

old_results <- old_results %>% filter(val01 == "2023Q3", col02 != "TALB")





jj <- inner_join(new_results, old_results, by =nn, suffix = c("_NEW", "_OLD"))

jj <- jj %>% filter(conf_distinct_NEW != conf_distinct_OLD)

View(jj)

identical(old_results$conf_distinct, new_results$conf_distinct)

aj <- anti_join(old_results, new_results, by = nn)


compare(old_results, new_results, allowAll = TRUE)

all.equal(old_results, new_results)


old
nrow(new)
nrow(old)

