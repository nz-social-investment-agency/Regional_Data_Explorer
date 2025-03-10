library(dplyr)
library(tidyverse)
library(rlang)
library(testdat)
library(compare)



create_structure <- function(df){
  # find all col__
  n <- c()
  cols <- grepl("col", colnames(df))
  
  cols <- colnames(df)[cols]
  
  for (i in cols)
  {
    n <- unique(c(n, (unique(df[[i]]))))
    n <- n[!is.na(n)]
  }
  
  #n <- append(n, c("summarised_var", "raw_distinct", "conf_distinct"), after = length(n))
  str_df <- setNames(data.frame(matrix(ncol = length(n), nrow = 0)), n) %>%
    mutate(across(everything(), as.character))
  
  distinct_names <- df %>% select(all_of(cols)) %>% distinct()
  
  # find all val__
  vals <- grepl("^val", colnames(df))
  vals <- colnames(df)[vals]
  
  
  # for each unique set of col__ values
  for (i in 1:nrow(distinct_names)){
    

  
    # filter to rows of df
    # rename val__ to contents of col__
    # append to output
    
    this_row <- distinct_names[i,]
    print(i)
    print(this_row)
    
    filter_expr <- lapply(names(this_row), function(col){
      if(is.na(this_row[[col]])){
        paste0("is.na(", col,')')
      } else {
        paste0(col, " == '", this_row[[col]], "'")
      }
    })
    
    filter_expr <- paste0(filter_expr, collapse = ' & ')
    t_df <- df %>%
      filter(eval(parse_expr(filter_expr)))
  
    #colnames(t_df)
    
    for (j in 1:length(vals)){
      #rename new_name = old_name 

      this_name <- this_row[,j]
      
      this_row
      print(this_name)
      if(is.na(this_name)){
        t_df <- t_df %>% select(-vals[j])
        next
      }
    
      t_df <- t_df %>%
        rename(!!sym(this_name) := !!sym(vals[j])) %>%
        select(-contains("col")) %>%
        mutate(across(everything(), as.character))
    }
    str(t_df)
    str_df <- bind_rows(str_df, t_df)
  }
  
  return(str_df)
  
}




# ex_val_col argument that excludes a column from half join, otherwise it will join on that column as well which results in returning identical LHS and RHS
# If left default, raw, conf and summarised_var will be excluded. and if df contains ent names, ent will also be excluded

half_join <- function(l_df, r_df, by = "ones", suffix = c("_L", "_R"), ex_col = NA){ 
  if(missing(suffix) | any(is.na(suffix))){
    suffix <- c("_L", "_R")
    print("suffix not provided, default suffix assigned")
    print(suffix)
  }
  if(missing(by) | all(is.na(by))){
    by <- "ones"
    print("by not provided, default assigned")
    print(by)
  } else { by <- c(by, "ones")}
  
  

    
  l_df <- l_df %>%
    mutate(ones = "1")
  r_df <- r_df %>%   
    mutate(ones = "1")

    
  s_time <- Sys.time()
  
  print("Joining..")
  
  b_df <- inner_join(l_df, r_df, by = by, suffix = suffix, relationship = "many-to-many")

  e_time <- Sys.time()
  
  t_time <- e_time - s_time
  
  print(paste("Join time:", t_time))
  
  cols <- grepl("^ent", colnames(l_df))
  cols <- colnames(l_df)[cols]
  
  if(any(is.na(ex_col)) & all(c("raw_distinct", "conf_distinct", "summarised_var") %in% colnames(l_df))){
    
    if(!any(grepl("ent", colnames(l_df)))){
      exclude_names <- c("raw_distinct", "conf_distinct", "summarised_var")  
    } else { 
      exclude_names <- c(cols, "raw_distinct", "conf_distinct", "summarised_var")
    }
    exclude_names <- c(by, exclude_names)
  }
  
  
  if(!exists("exclude_names")){
    filter_names <- setdiff(names(l_df), c("ones", ex_col))
  } else if(all(exclude_names  %in% names(l_df))){ #all or any
    filter_names <- setdiff(names(l_df), exclude_names)
  } 
  
  filter_expr <- lapply(filter_names, function(col){
    paste0("(",col, suffix[1], " == ", col, suffix[2], " | is.na(", col, suffix[2], "))")
  })
  

  s_time <- Sys.time()
  
  filter_expr <- paste0(filter_expr, collapse = ' & ')

  print(filter_names)
  
  f_df <- b_df %>%
    filter(eval(parse_expr(filter_expr)))
  # %>%
  #   mutate_at(c(paste0("conf_distinct", suffix[1]), paste0("conf_distinct", suffix[2])), as.numeric)
  # 
  
  e_time <- Sys.time()
  t_time <- e_time - s_time
  
  print(paste("Filtering time:", t_time))
  
  return(f_df)
}





  





