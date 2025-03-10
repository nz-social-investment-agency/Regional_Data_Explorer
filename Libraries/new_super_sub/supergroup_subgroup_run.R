################################################################################
# Run supergroup-subgroup comparison and correction
# 
# Requires:
#  - supergroup_subgroup_functions.R (component functions)
#  - supergroup_subgroup_pairs.csv (lists pairs of supergroups and subgroups)
#  - sub_super_run_file.csv (control file)
# 
# Motivation:
# Consider two groups: a supergroup and a subgroup. We know raw count of the
# supergroup >= raw count of the subgroup. If random rounding creates conf
# counts with the subgroup > supergroup, then the raw counts can be estimated
# with accuracy.
# 
# To avoid this, we compare supergroups and subgroups. If confidentialised count
# of the subgroup is larger than the supergroup, it is decreased. This is
# roughtly equivalent to forcing subgroup counts to round down if supergroup
# counts are rounded down and the two raw counts are almost identical.
# 
# Methodology:
# For our data, after converting to rectangular format, a row is a subset of
# another row if the labels of the two rows match or the superset has NA values.
# 
# Hence our method becomes (1) adjust data to rectangule format, (2) fill in any
# missing labels, (3) join in a way that accepts NAs in the join, (4) compare
# counts.
# 
# Example of superset and subset rows:
#  region | agecat |  count 
# --------+--------+--------
#   Auck  |  teen  |    111
#   Auck  |  NULL  |    222
#   NULL  |  teen  |    333
#   NULL  |  NULL  |    444
# 
# Hence row 1 is a subset of rows 2-4, and rows 2 & 3 are subsets of row 4.
# 
################################################################################

## parameters ------------------------------------------------------------------ ----

CONTROL_FILE = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Libraries/super_sub_new/sub_super_run_file_GEOG_TE_HIKU.csv"

SUPER_SUB_PAIRS = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Libraries/super_sub_new/supergroup_subgroup_pairs.csv"

UNADJUSTED_FOLDER = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results"
ADJUSTED_FOLDER = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Results/Sub_grp_adjusted"

COMPONENT_FUNCTIONS = "/nas/DataLab/MAA/MAA2023-55/RDP_iwi_Master/Libraries/super_sub_new/supergroup_subgroup_functions.R"

PRINT_FAILURES = TRUE


## setup ----------------------------------------------------------------------- ----

print_progress = function(msg) {
  stopifnot(is.character(msg))
  now = substr(as.character(Sys.time()), 1, 19)
  cat(now, "|", msg, "\n")
}

print_progress("Supergroup-subgroup process start")

source(COMPONENT_FUNCTIONS)

## read and verify control file ------------------------------------------------ ----

print_progress(" -- Validating control file")

# all values are character on read
control_file = read.csv(CONTROL_FILE, stringsAsFactors = FALSE, colClasses = "character")

required_columns = c(
  "run",
  "order",
  "file_name",
  "column_name",
  "rounding",
  "comparison_file_1",
  "comparison_file_2",
  "comparison_file_3",
  "comparison_file_4"
)
stopifnot(all(required_columns %in% colnames(control_file)))

# prepare control file
control_file$run = as.logical(control_file$run)
control_file$order = as.numeric(control_file$order)

control_file = dplyr::select(control_file, dplyr::all_of(required_columns))
control_file = dplyr::filter(control_file, .data$run)
control_file = dplyr::arrange(control_file, .data$order)

control_file = dplyr::mutate(control_file, file_name = trimws(.data$file_name))
control_file = dplyr::mutate(control_file, column_name = trimws(.data$column_name))
control_file = dplyr::mutate(control_file, rounding = trimws(.data$rounding))
control_file = dplyr::mutate(control_file, comparison_file_1 = trimws(.data$comparison_file_1))
control_file = dplyr::mutate(control_file, comparison_file_2 = trimws(.data$comparison_file_2))
control_file = dplyr::mutate(control_file, comparison_file_3 = trimws(.data$comparison_file_3))
control_file = dplyr::mutate(control_file, comparison_file_4 = trimws(.data$comparison_file_4))

# no missing values in compulsory columns
stopifnot(all(!is.na(control_file$file_name)))
stopifnot(all(!is.na(control_file$column_name)))
stopifnot(all(!is.na(control_file$rounding)))
stopifnot(all(control_file$rounding %in% c("RR3","GRR")))

# ensure required files exist
for(ff in control_file$file_name){
  full_path = fetch_file_name(UNADJUSTED_FOLDER, ff)
  if(is.na(full_path)){
    stop("File ",ff," not found in ",UNADJUSTED_FOLDER)
  }
}

comparison_files = unique(c(
  control_file$comparison_file_1,
  control_file$comparison_file_2,
  control_file$comparison_file_3,
  control_file$comparison_file_4
))
comparison_files = comparison_files[!is.na(comparison_files)]
comparison_files = comparison_files[comparison_files != ""]
comparison_files = setdiff(comparison_files, control_file$file_name)

for(cc in comparison_files){
  full_path = fetch_file_name(ADJUSTED_FOLDER, cc)
  if(is.na(full_path)){
    stop("File ",cc," not found in ",ADJUSTED_FOLDER)
  }
}

print_progress(" -- Control file validated")

## load supergroup subgroup pairs ---------------------------------------------- ----

print_progress(" -- Loading supergroup-subgroup pairs")

supergroup_subgroup_pairs = read.csv(SUPER_SUB_PAIRS, stringsAsFactors = FALSE, colClasses = "character")

## comparison ------------------------------------------------------------------ ----

for(ii in 1:nrow(control_file)){
  
  this = dplyr::slice(control_file, ii)
  
  msg = sprintf(" -- %3d of %d, file: %s", ii, nrow(control_file), this$file_name)
  print_progress(msg)
  
  # read unadjusted file
  working_file = fetch_file_name(UNADJUSTED_FOLDER, this$file_name)
  working_table = read.csv(working_file, stringsAsFactors = FALSE)
  
  # compare against self
  working_table = super_sub_comparision(working_table, working_table, supergroup_subgroup_pairs, this$column_name, this$rounding)
  
  # comparison file 1 if exists
  comparison_file = fetch_file_name(ADJUSTED_FOLDER, this$comparison_file_1)
  if(!is.na(comparison_file)){
    comparison_file = read.csv(comparison_file, stringsAsFactors = FALSE)
    working_table = super_sub_comparision(comparison_file, working_table, supergroup_subgroup_pairs, this$column_name, this$rounding)
  }
  
  # comparison file 2 if exists
  comparison_file = fetch_file_name(ADJUSTED_FOLDER, this$comparison_file_2)
  if(!is.na(comparison_file)){
    comparison_file = read.csv(comparison_file, stringsAsFactors = FALSE)
    working_table = super_sub_comparision(comparison_file, working_table, supergroup_subgroup_pairs, this$column_name, this$rounding)
  }
  
  # comparison file 3 if exists
  comparison_file = fetch_file_name(ADJUSTED_FOLDER, this$comparison_file_3)
  if(!is.na(comparison_file)){
    comparison_file = read.csv(comparison_file, stringsAsFactors = FALSE)
    working_table = super_sub_comparision(comparison_file, working_table, supergroup_subgroup_pairs, this$column_name, this$rounding)
  }
  
  # comparison file 4 if exists
  comparison_file = fetch_file_name(ADJUSTED_FOLDER, this$comparison_file_4)
  if(!is.na(comparison_file)){
    comparison_file = read.csv(comparison_file, stringsAsFactors = FALSE)
    working_table = super_sub_comparision(comparison_file, working_table, supergroup_subgroup_pairs, this$column_name, this$rounding)
  }
  
  # write out adjusted file
  adjusted_file = file.path(ADJUSTED_FOLDER, basename(working_file))
  write.csv(working_table, adjusted_file, row.names = FALSE)
}

## conclude -------------------------------------------------------------------- ----

print_progress("Supergroup-subgroup process end")

## ----
