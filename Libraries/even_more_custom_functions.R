# This script includes a range of functions, currently unsorted, that are convenient to use with the assembly tool
# 


##### create_location_data - this is a modified version of the assemble_output_table function
#' Notes: 
#'	- Tidy script is largely based on the function for create_output_table.
#'	- The purpose is to read in the control file for geographies. Each row of this represents a grouped set of geographies.
#'  - Currently working on assumption that there will be one group of geographies. 
#'  - If more than one is required, we could create temp tables for each row of the control file, and a final based on the combination of levels
#'  - We could then loop over rows to produce the temp tables, and do joins to get them into the final.


create_location_data <- function(population_table, 
                                 location_table,
                                 output_database, 
                                 output_schema, 
                                 output_table,
                                 control_development_mode = DEVELOPMENT_MODE, 
                                 control_overwrite_output_table = TRUE,
                                 control_verbose = "all"){
  #### existence of output table ----
  # connect to db
  db_con <- create_database_connection(database = output_database)
  
  # delete
  if (control_overwrite_output_table) {
    delete_table(db_con, output_database, output_schema, output_table)
  }
  
  # want to validate here:
  # loc_measures is text contained within quotation marks that is separated by commas (can trim spaces)
  # loc_type refers to a valid SQL column type
  # loc_values refers to a table on the SQL server, so is contained within square brackets and separated by commas (can trim spaces)
  
  
  
  
  # Get names of columns that will be dynamically constructed 
  loc_measures <- strsplit(location_table$label_measures,",")[[1]]
  loc_measures <- gsub(loc_measures,pattern = "\"",replacement = "")
  loc_values <- strsplit(location_table$column_names,",")[[1]]
  loc_types <- trim(strsplit(location_table$type,",")[[1]])
  assert(length(loc_measures)==length(loc_values) &length(loc_values)== length(loc_types),"Not all columns have names or values")
  
  # required table
  output_columns <- list(
    identity_column = "[int] NOT NULL",
    #    label_identity = "[varchar](50) NOT NULL",
    label_summary_period = "[varchar](50) NOT NULL"
    # label_measure = "[varchar](70) NOT NULL",
    # value_measure = "[FLOAT](53) NULL"
  )
  for (geo_i in 1:length(loc_measures)){
    output_columns[[loc_measures[geo_i]]] <- gsub(pattern = "\"", replacement = "", x =  loc_types[geo_i])}
  
  # create if does not exist
  if (!table_or_view_exists_in_db(db_con, output_database, output_schema, output_table)) {
    run_time_inform_user("creating table", context = "all", print_level = control_verbose)
    create_table(db_con, output_database, output_schema, output_table, output_columns, OVERWRITE = FALSE)
  }
  # confirm table has required columns
  out_tbl <- create_access_point(db_con, output_database, output_schema, output_table)
  assert(table_contains_required_columns(out_tbl, names(output_columns), only = TRUE), "output table missing column")
  close_database_connection(db_con)
  run_time_inform_user("existence of output table verified", context = "details", print_level = control_verbose)
  
  #### access and append values ----
  # Have left this variable (hardcoded) to preserve the same format as the assemble_output_table function, as far as possible.
  row_m <- 1 
  
  # values
  geo_identity_column <- prep_for_sql(location_table[[row_m, "identity_column"]], alias = "a")
  geo_start <- prep_for_sql(location_table[[row_m, "measure_period_start_date"]], alias = "a")
  geo_end <- prep_for_sql(location_table[[row_m, "measure_period_end_date"]], alias = "a")
  
  
  
  # for each row in population table
  for (row_p in 1:nrow(population_table)) {
    # values
    p_identity_column <- prep_for_sql(population_table[[row_p, "identity_column"]], alias = "p")
    #    p_identity_label <- prep_for_sql(population_table[[row_p, "label_identity"]], alias = "p")
    p_start_date <- prep_for_sql(population_table[[row_p, "summary_period_start_date"]], alias = "p")
    p_end_date <- prep_for_sql(population_table[[row_p, "summary_period_end_date"]], alias = "p")
    p_period_label <- prep_for_sql(population_table[[row_p, "label_summary_period"]], alias = "p")
    
    # connect
    db_con <- create_database_connection(database = output_database)
    
    # components
    from_population <- sprintf(
      "%s.%s.%s",
      population_table[[row_p, "database_name"]],
      population_table[[row_p, "schema_name"]],
      population_table[[row_p, "table_name"]]
    )
    from_location <- sprintf(
      "%s.%s.%s",
      location_table[[row_m, "database_name"]],
      location_table[[row_m, "schema_name"]],
      location_table[[row_m, "table_name"]]
    )
    optional_top <- ifelse(control_development_mode, " TOP 1000 ", " ")
    
    
    # group_by_columns <- c(p_identity_column, p_identity_label, p_start_date, p_end_date, p_period_label, calculation$group)
    # group_by_columns <- group_by_columns[!is_delimited(group_by_columns, "'")]
    # GROUP_BY <- ifelse(length(group_by_columns) == 0, "", paste0("GROUP BY ", paste0(group_by_columns, collapse = ", ")))
    
    
    
    dynamic_column_generation_statement<- c()
    for (col_p in seq(1,length(loc_measures))){
      dynamic_column_generation_statement<- glue::glue(paste(dynamic_column_generation_statement,",a.{loc_values[col_p]} as {loc_measures[col_p]}"))
    }      
    
    # prepare query
    sql_query <- dbplyr::build_sql(
      con = db_con,
      sql(glue::glue(
        "SELECT DISTINCT {optional_top}\n",
        "       {p_identity_column} AS [identity_column]\n",
        #"      ,{p_identity_label}  AS [label_identity]\n",
        # "      ,{p_start_date} AS [summary_period_start_date]\n",
        # "      ,{p_end_date}   AS [summary_period_end_date]\n",
        "      ,{p_period_label}  AS [label_summary_period]\n",
        dynamic_column_generation_statement,
        "\nFROM {from_population} AS p\n",
        "LEFT JOIN {from_location} AS a\n",
        "ON {p_identity_column} = {geo_identity_column}\n",
        "AND {p_start_date} <= {geo_end}\n",
        "AND {geo_start} <= {p_end_date}\n",
        # "{GROUP_BY}"
      ))
    )
    table_to_append <- dplyr::tbl(db_con, dbplyr::sql(sql_query))
    
    # append & conclude
    append_database_table(db_con, output_database, output_schema, output_table,
                          list_of_columns = names(output_columns), table_to_append
    )
    close_database_connection(db_con)
    run_time_inform_user(sprintf(
      "completed population %3d of %3d, measure %4d of %4d",
      row_p, nrow(population_table), row_m, nrow(location_table)
    ),
    context = "details", print_level = control_verbose
    )
  }
  # Create index
  run_time_inform_user("indexing subnational location table", context = "heading", print_level = "all")
  db_con <- create_database_connection(database = output_database)
  create_nonclustered_index(db_con,
                            output_database,
                            output_schema,
                            output_table,
                            "identity_column")
  
  # Want to compress the table
  
  
}


##### Produce 










