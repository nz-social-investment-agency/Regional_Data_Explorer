
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
#' like SQL permits, the by_half join is implemented as a cross-join followed
#' by a filter. This can result in large intermediate tables. To minimise the
#' size of these tables (and reduce the risk of an out of memory error) we
#' recommend including all applicable columns in the by argument.
#' If a column could be placed in by or by_half, place it in by.
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
