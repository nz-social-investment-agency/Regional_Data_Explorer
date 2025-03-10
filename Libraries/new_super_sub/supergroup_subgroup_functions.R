####### components to build

# populate super-sub group values > DONE
# comparison > DONE
# convert long-thin to rectangular > Wian completed & INTEGRATED

# half-join > Wian completed & INTEGRATED

# conduct comparison function > written & testing

# structure locks > DONE
# load file > DONE
# verify control file > DONE

## fetch file name ------------------------------------------------------------- ----
#' Fetch full file name based on folder and pattern.
#' 
#' @param folder The folder to search within.
#' @param pattern The file name pattern to follow. Exact matching is used,
#' with * permitted to be a set of numbers for the date.
#' 
#' @return Full path of the specified file or NA if not found. Where more than
#' one file is found, returns the last one after sorting. This should always
#' give the latest date (assuming consistent date formatting).
#' 

fetch_file_name = function(folder, pattern){
  stopifnot(is.character(folder))
  stopifnot(is.character(pattern))
  stopifnot(dir.exists(folder))
  
  pattern = gsub("\\*", "[0-9]*", pattern)
  pattern = paste0("^",pattern,"$")
  
  possible_files = list.files(path = folder, pattern = pattern, full.names = TRUE)
  
  if(length(possible_files) == 0){
    return(NA)
  }
  
  possible_files = sort(possible_files, decreasing = TRUE)
  chosen_file = normalizePath(possible_files[1])
  return(chosen_file)
}

## populate supergroup values -------------------------------------------------- ----
#' Fills in supergroup values where these are empty. This enables half_na_join
#' to connect supergroups and subgroups that would otherwise not connect.
#' 
#' @param table A data frame to process. Table should not be in long-thin
#' format. It should be in rectangular format.
#' @param supergroup_subgroup_pairs A data frame containing four columns:
#' supergroup_col, supergroup_val, subgroup_col, and subgroup_val.
#' 
#' @return modified version of table: For every row in supergroup_subgroup_pairs
#' if table has a column called subgroup_col with value subgroup_val, then
#' add to column supergroup_col the value supergroup_val.
#' 
#' Worked example:
#' 
#' table:
#' 
#' age group | age | count
#' ----------+-----+-------
#'  10-20 yr |  15 | 123
#'   NA      |  18 | 234
#' 
#' Note that while age = 18 is a subgroup of age group = 10-20 yr, row 2 is
#' missing an age group. Half-na-joins work best when missing values indicate
#' that there is no further subgroup. So a half-na-join on this table to give
#' incomplete results.
#' 
#' supergroup_subgroup_pairs:
#' 
#' supergroup_col | supergroup_val | subgroup_col | subgroup_val
#' ---------------+----------------+--------------+--------------
#'  age group     |  10-20 yr      |   age        |    18
#' 
#' This table lists subgroups and supergroups. In this example it states that
#' age = 18 is a subgroup of age group = 10-20 yr.
#' 
#' output:
#' 
#' age group | age | count
#' ----------+-----+-------
#'  10-20 yr |  15 | 123
#'  10-20 yr |  18 | 234
#' 
#' The result is the table with supergroup information completed.
#' 

populate_supergroup_values = function(table, supergroup_subgroup_pairs){
  stopifnot(is.data.frame(table))
  stopifnot(is.data.frame(supergroup_subgroup_pairs))
  stopifnot("supergroup_col" %in% colnames(supergroup_subgroup_pairs))
  stopifnot("supergroup_val" %in% colnames(supergroup_subgroup_pairs))
  stopifnot("subgroup_col" %in% colnames(supergroup_subgroup_pairs))
  stopifnot("subgroup_val" %in% colnames(supergroup_subgroup_pairs))
  
  expected_rows = nrow(table)
  expected_cols = ncol(table)
  
  # distinct pairs of supergroup-cols and subgroup-cols
  distinct_cols = dplyr::select(supergroup_subgroup_pairs, supergroup_col, subgroup_col)
  distinct_cols = dplyr::distinct(distinct_cols)
  
  # return early if supergroup_subgroup_pairs is empty
  if(nrow(distinct_cols) == 0){
    return(tabl)
  }
  
  # iterate through distinct super-sub pairs
  for(ii in 1:nrow(distinct_cols)){
    this_supergroup_col = distinct_cols$supergroup_col[ii]
    this_subgroup_col = distinct_cols$subgroup_col[ii]
    
    # skip to next iteration if subgroup not in table
    if(! this_subgroup_col %in% colnames(table)){
      next
    }
    
    # ensure supergroup columns exist if required
    new_super_col = FALSE
    if(!this_supergroup_col %in% colnames(table)){
      table[[this_supergroup_col]] = NA
      table[[this_supergroup_col]] = as(table[[this_supergroup_col]], class(supergroup_subgroup_pairs$supergroup_val))
      expected_cols = expected_cols + 1
      new_super_col = TRUE
    }
    
    # assign values if missing (join more efficient that looping over all _val)
    tbl_to_join = dplyr::filter(supergroup_subgroup_pairs, supergroup_col == this_supergroup_col, subgroup_col == this_subgroup_col)
    tbl_to_join = dplyr::select(tbl_to_join, supergroup_val, subgroup_val)
    tbl_to_join = dplyr::mutate(tbl_to_join, subgroup_val = as(subgroup_val, class(table[[this_subgroup_col]])))
    tbl_to_join = dplyr::rename(tbl_to_join, "{this_subgroup_col}" := subgroup_val)
    if(!new_super_col){
      tbl_to_join = dplyr::mutate(tbl_to_join, supergroup_val = as(supergroup_val, class(table[[this_supergroup_col]])))
    }
    
    table = dplyr::left_join(table, tbl_to_join, by = this_subgroup_col, relationship = "many-to-many")
    table = dplyr::mutate(table, "{this_supergroup_col}" := dplyr::coalesce(.data[[this_supergroup_col]], supergroup_val))
    table = dplyr::select(table, -supergroup_val)
    
  }
  
  # error if number of columns has changed
  stopifnot(ncol(table) == expected_cols)
  
  return(table)
}

## comparison of super- and sub-group counts ----------------------------------- ----
#' Compares supergroup column against subgroup column and updates the subgroup
#' column to a value that is at most the value in the supergroup column.
#' 
#' Checks and warns if:
#' 1) subgroup values are not rounded.
#' 2) subgroup values are greater than supergroup values by more than random
#' rounding could cause.
#' 3) subgroup values are still greater than supergroup values after adjustment.
#' 
#' @param table A data frame to process. Table should not be in long-thin
#' format. It should be in rectangular format. 
#' @param supergroup_col The name of the column of table that contains supergroup counts.
#' @param subgroup_col The name of the column of table that contains subgroup counts.
#' @param type The type of rounding applied to the subgroup values.
#' Accepts RR3 and GRR only.
#' @param print_failures If TRUE top 3 rows that trigger warnings are printed.
#' 
#' @return modified version of table: if subgroup value > supergroup value then
#' subgroup value reduced by random rounding amount (this is the equivalent to
#' forcing the subgroup count to round down).
#' 
#' In a small number of cases may output values may differ from raw counts by
#' more than rounding. For example: Suppose the supergroup and subgroup both
#' have a raw count of 101. The supergroup is RR3 down to 99. The subgroup is
#' GRR down to 100. As the subgroup > supergroup, we decrease the subgroup by
#' the GRR margin, giving a final subgroup count of 95.
#' 
#' This is worth noting as random rounding of a raw value of 101 can not produce
#' a rounded value of 95. However the best choice for confidentiality in this
#' case is to output 95.
#' 

compare_super_and_sub_counts = function(table, supergroup_col, subgroup_col, type = "RR3", print_failures = FALSE){
  stopifnot(is.data.frame(table))
  stopifnot(is.character(supergroup_col))
  stopifnot(supergroup_col %in% colnames(table))
  stopifnot(is.character(subgroup_col))
  stopifnot(subgroup_col %in% colnames(table))
  stopifnot(type %in% c("RR3", "GRR"))
  stopifnot(is.logical(print_failures))
  
  # rounding value
  if(type == "RR3"){
    rounding_value = rep(3, nrow(table))
  }
  if(type == "GRR"){
    rounding_value = dplyr::case_when(
      abs(table[[subgroup_col]]) <= 18 ~ 3,
      abs(table[[subgroup_col]]) <= 20 ~ 2,
      abs(table[[subgroup_col]]) <= 100 ~ 5,
      abs(table[[subgroup_col]]) <= 1000 ~ 10,
      abs(table[[subgroup_col]]) > 1000 ~ 100
    )
  }
  
  # warn if input values are not rounded
  remainder = table[[subgroup_col]] %% rounding_value
  if(any(remainder != 0)){
    warning(
      sum(remainder != 0), " input values not rounded.",
    " Function output assumes rounded inputs."
    )
    if(print_failures){
      tmp_table = dplyr::filter(table, remainder != 0)
      print(head(tmp_table, 3))
    }
  }
  
  # warn if differences are too large
  tmp_table = table
  tmp_table$tmp_rounding_value = rounding_value
  tmp_table = dplyr::filter(
    tmp_table,
    .data[[subgroup_col]] > .data[[supergroup_col]],
    # The +1 is only necessary if one count is RR3 and the other is GRR
    # a small number of cases may fail to warn because of the +1 but we judge
    # this to be better than warnings that do not apply
    .data[[subgroup_col]] - .data[[supergroup_col]] >= .data$tmp_rounding_value + 1
  )
  if(nrow(tmp_table) > 0){
    warning(
      nrow(tmp_table), " cases where subgroup exceeds supergroup by more than",
      " random rounding. Incorrect setup likely."
    )
    if(print_failures){
      print(head(tmp_table, 3))
    }
  }
  
  # compare
  to_adjust = table[[subgroup_col]] > table[[supergroup_col]]
  counts_adjusting = table[[subgroup_col]]
  counts_adjusting[to_adjust] = counts_adjusting[to_adjust] - rounding_value[to_adjust]
  table[[subgroup_col]] = counts_adjusting
  
  # warn if adjustment failed
  still_to_adjust = table[[subgroup_col]] > table[[supergroup_col]]
  if(sum(still_to_adjust) > 0){
    warning(sum(still_to_adjust), " cases where subgroup exceeds supergroup after adjustment")
    if(print_failures){
      tmp_table = dplyr::filter(table, still_to_adjust)
      print(head(tmp_table, 3))
    }
  }
  
  return(table)
}

## convert long-thin to rectangular structure ---------------------------------- ----
#' Convert long-thin format (with pairs of col__ and val__ columns) to
#' rectangular format. Values in col__ columns become column names of values
#' in val__ columns.
#' 
#' This is more complex that a standard pivot & unpivot, because of labels can
#' be mixed arbitrarily across col__ columns.
#' 
#' @param df A data.frame in long-thin format. Partial validation of the format
#' of df is conducted.
#' 
#' @return modified version of table with col__ and val__ columns replaced by
#' rectangular columns descriptors. The values in these new columns will be
#' or type character. Values in the unchanged columns will be of unchanged type.
#' 

long_thin_to_rectangular = function(df){
  stopifnot(is.data.frame(df))
  stopifnot(any(grepl("^col", colnames(df))))
  stopifnot(any(grepl("^val", colnames(df))))
  
  # all col_
  cols = grepl("^col", colnames(df))
  cols = colnames(df)[cols]
  # all val_
  vals = grepl("^val", colnames(df))
  vals = colnames(df)[vals]
  stopifnot(length(cols) == length(vals))
  # all other columns
  oths = setdiff(colnames(df), c(cols, vals))
  
  # required output column names
  out_cols = c()
  for (cc in cols){
    out_cols = c(out_cols, unique(df[[cc]]))
  }
  out_cols = out_cols[!is.na(out_cols)]
  out_cols = unique(out_cols)
  out_cols = c(out_cols, oths)
  
  # empty dataframe
  out_df = data.frame(matrix(ncol = length(out_cols), nrow = 0))
  colnames(out_df) = out_cols
  out_df = dplyr::mutate(out_df, dplyr::across(dplyr::everything(), as.character))
  
  # all unique col_ rows
  distinct_names = dplyr::select(df, all_of(cols))
  distinct_names = dplyr::distinct(distinct_names)
  
  out_list = list(out_df)
  
  # for each unique set of col_ values
  for (ii in 1:nrow(distinct_names)){
    this_row = dplyr::slice(distinct_names, ii)
    
    # filter to rows of df
    filter_expr = sapply(
      names(this_row),
      function(col){
        ifelse(
          is.na(this_row[[col]]),
          glue::glue("is.na({col})"),
          glue::glue("{col} == '{this_row[[col]]}'")
        )
      }
    )
    filter_expr = paste0(filter_expr, collapse = ' & ')
    
    tmp_df = dplyr::filter(df, eval(rlang::parse_expr(filter_expr)))
    
    # rename val_ to contents of col_
    for (jj in 1:length(vals)){
      this_name = this_row[,jj]
      this_val = vals[jj]
      
      if(is.na(this_name)){
        tmp_df = dplyr::select(tmp_df, -dplyr::all_of(this_val))
        next
      }
      
      tmp_df = dplyr::rename(tmp_df, "{this_name}" := dplyr::all_of(this_val))
    }
    
    # append to output
    tmp_df = dplyr::select(tmp_df, -dplyr::any_of(cols))
    tmp_df = dplyr::mutate(tmp_df, dplyr::across(dplyr::everything(), as.character))

    out_list = c(out_list, list(tmp_df))
  }
  
  # combine output
  out_df = dplyr::bind_rows(out_list)
  # unchanged columns have input data type
  for(oo in oths){
    out_df = dplyr::mutate(out_df, "{oo}" := as(.data[[oo]], class(df[[oo]])))
  }
  return(out_df)
}

## half join with NAs ---------------------------------------------------------- ----
#' Half join conducts a join but accepts both matches or missing values for
#' the right-side table. So both left.x = right.x OR is.na(right.x) join.
#' 
#' @param l_df The left side data frame to join.
#' @param r_df The right side data frame to join. Missing values in this table
#' may join to non-missing values on the left.
#' @param by List of columns that must be joined upon. If by_half is left blank
#' results are equivalent to an inner join on these columns.
#' @param by_half List of columns to half-join upon. Columns in this list
#' will join if left.x = right.x or if right.x is missing.
#' @param suffix Consistent with dplyr joins, suffixes to add to original column
#' names if left and right share columns names. Defaults to c("_L","_R").
#' 
#' A note regarding performance: As R does not allow arbitrary join conditions
#' like SQL permits, the by_half join was first implemented as a cross-join
#' followed by a filter. However, this resulted in large intermediate tables.
#' (>2 billion rows and 48 GB in some tests).
#' 
#' To minimise the memory required during processing we redesigned the function.
#' During use we recommend including all applicable columns in `by` argument:
#' So if a column could be placed in `by` or `by_half`, place it in `by`.
#' 

half_na_join = function(l_df, r_df, by = character(0), by_half = character(0), suffix = c("_L","_R")){
  stopifnot(is.data.frame(l_df))
  stopifnot(is.data.frame(r_df))
  stopifnot(is.character(by))
  stopifnot(is.character(by_half))
  stopifnot(is.character(suffix))
  stopifnot(length(suffix) == 2)
  stopifnot(length(by) == 0 || all(by %in% colnames(l_df)))
  stopifnot(length(by) == 0 || all(by %in% colnames(r_df)))
  stopifnot(length(by_half) == 0 || all(by_half %in% colnames(l_df)))
  stopifnot(length(by_half) == 0 || all(by_half %in% colnames(r_df)))
  
  # setup df's
  l_df = dplyr::mutate(l_df, tmp_ones = 1)
  r_df = dplyr::mutate(r_df, tmp_ones = 1)
  
  by = c("tmp_ones", by)
  
  # powerset of by_half
  powerset = lapply(0:length(by_half), combn, x = by_half, simplify = FALSE)
  powerset = unlist(powerset, recursive = FALSE)
  
  # internal function
  filter_na_and_join = function(r_df, sub_by_half){
    
    sub_wout_na = sub_by_half
    sub_with_na = setdiff(by_half, sub_by_half)
    
    # filter conditions
    filter_expr = character(0)
    if(length(sub_wout_na) > 0){
      filter_expr = c(filter_expr, paste0("!is.na(", sub_wout_na, ")"))
    }
    if(length(sub_with_na) > 0){
      filter_expr = c(filter_expr, paste0("is.na(", sub_with_na, ")"))
    }
    
    # filter r_df
    if(length(filter_expr) > 0){
      filter_expr = paste0(filter_expr, collapse = ' & ')
      r_df = dplyr::filter(r_df, eval(rlang::parse_expr(filter_expr)))
    }
    
    # inner join
    dplyr::inner_join(
      l_df, 
      r_df, 
      by = c(by, sub_by_half),
      suffix = suffix, 
      relationship = "many-to-many",
      keep = TRUE
    )
  }
  
  # join and combine
  result_list = lapply(powerset, filter_na_and_join, r_df = r_df)
  result_df = dplyr::bind_rows(result_list)
  
  # resolve names in by
  for (bb in by){
    bb_l = paste0(bb, suffix[1])
    bb_r = paste0(bb, suffix[2])
    
    result_df = dplyr::rename(result_df, "{bb}" := dplyr::all_of(bb_l))
    result_df = dplyr::select(result_df, -all_of(bb_r))
  }
  
  # conclude
  return(dplyr::select(result_df, -"tmp_ones"))
}

## conduct comparison of super- and sub-group tables --------------------------- ----
#' Compare supergroup and subgroup and reduce the values in the subgroup to
#' ensure they are at most the value in the supergroup.
#' 
#' @param supergroup_table A data frame containing the supergroups. May be
#' identical to subgroup_table for self comparison. These are the values that
#' are used for comparison.
#' @param subgroup_table A data frame containing the subgroups. May be identical
#' to supergroup_table for self-comparison. These are the values that are
#' modified.
#' @param supergroup_subgroup_pairs A reference file containing combinations
#' of supergroup and subgroup values. Is passed to [populate_supergroup_values].
#' See documentation of this function for guidance.
#' @param column_name The number of the column to be compared. This column must
#' appear in both the supergroup and subgroup tables.
#' @param rounding The type of rounding used (RR3 or GRR).
#' 
#' @return A modified version of subgroup_table, where values in column_name may
#' have been reduced to ensure they were smaller than any corresponding values
#' from supergroup_table.
#' 

super_sub_comparision = function(supergroup_table, subgroup_table, supergroup_subgroup_pairs, column_name, rounding){
  stopifnot(is.data.frame(supergroup_table))
  stopifnot(is.data.frame(subgroup_table))
  stopifnot(column_name %in% colnames(supergroup_table))
  stopifnot(column_name %in% colnames(subgroup_table))
  stopifnot(rounding %in% c("RR3", "GRR"))
  
  # input dimensions
  input_colnames = colnames(subgroup_table)
  input_nrow = nrow(subgroup_table)
  
  # add row number
  supergroup_table = dplyr::mutate(supergroup_table, tmp_rn = dplyr::row_number())
  subgroup_table = dplyr::mutate(subgroup_table, tmp_rn = dplyr::row_number())
  
  # convert to rectangular format
  rect_supergroup_table = long_thin_to_rectangular(supergroup_table)
  rect_subgroup_table = long_thin_to_rectangular(subgroup_table)
  
  # populate supergroup values
  rect_supergroup_table = populate_supergroup_values(rect_supergroup_table, supergroup_subgroup_pairs)
  rect_subgroup_table = populate_supergroup_values(rect_subgroup_table, supergroup_subgroup_pairs)
  
  # create missing dummy columns
  col_diff = setdiff(colnames(rect_supergroup_table), colnames(rect_subgroup_table))
  for (cc in col_diff){
    rect_subgroup_table[[cc]] = NA
    rect_subgroup_table[[cc]] = as(rect_subgroup_table[[cc]], class(rect_supergroup_table[[cc]]))
  }
  col_diff = setdiff(colnames(rect_subgroup_table), colnames(rect_supergroup_table))
  for (cc in col_diff){
    rect_supergroup_table[[cc]] = NA
    rect_supergroup_table[[cc]] = as(rect_supergroup_table[[cc]], class(rect_subgroup_table[[cc]]))
  }
  
  # columns to join by
  by_cols = setdiff(colnames(rect_subgroup_table), input_colnames)
  by_cols = by_cols[by_cols != "tmp_rn"]
  by = character(0)
  by_half = character(0)
  for(cc in by_cols){
    if(any(is.na(rect_supergroup_table[[cc]]))){
      by_half = c(by_half, cc)
    } else {
      by = c(by, cc)
    }
  }
  
  # half join with NAs
  half_joined = half_na_join(
    rect_subgroup_table,
    rect_supergroup_table,
    by = by,
    by_half = by_half,
    suffix = c("_sub","_super")
  )
  half_joined = dplyr::select(half_joined, tmp_rn_sub, tmp_rn_super)
  
  # prep for comparison
  subgroup_col = column_name
  supergroup_col = paste0(column_name, "_super")
  supergroup_table = dplyr::select(supergroup_table, dplyr::all_of(c("tmp_rn", column_name)))
  
  working_table = dplyr::left_join(subgroup_table, half_joined, by = c("tmp_rn" = "tmp_rn_sub"))
  working_table = dplyr::left_join(working_table, supergroup_table, by = c("tmp_rn_super" = "tmp_rn"), suffix = c("","_super"))
  
  working_table = dplyr::select(working_table, -dplyr::starts_with("tmp_rn"))
  working_table = dplyr::group_by(working_table, dplyr::across(dplyr::all_of(input_colnames)))
  working_table = dplyr::summarise(working_table, min_supergroup = min(.data[[supergroup_col]], na.rm = TRUE), .groups = "drop")
  
  # comparison
  working_table = compare_super_and_sub_counts(
    table = working_table,
    supergroup_col = "min_supergroup",
    subgroup_col = subgroup_col,
    type = rounding,
    print_failures = PRINT_FAILURES
  )
  
  # verify output
  stopifnot(all(input_colnames %in% colnames(working_table)))
  stopifnot(nrow(working_table) == input_nrow)
  
  # return
  working_table = dplyr::select(working_table, dplyr::all_of(input_colnames))
  return(as.data.frame(working_table))
}

## ----
