run_files_in_dir <- function(dir, filter_str = c()){
  file_list <- list.files(dir, full.names = TRUE)
  if (length(filter_str) > 0){
    filtered_files <- grepl(filter_str, file_list)
    file_list <- file_list[filtered_files]
  }
  lapply(file_list, source)
}
