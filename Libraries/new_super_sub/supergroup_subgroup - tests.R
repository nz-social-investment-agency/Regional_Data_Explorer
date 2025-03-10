#' Functions tested
#' populate_supergroup_values(table, supergroup_subgroup_pairs)
#' compare_super_and_sub_counts(table, supergroup_col, subgroup_col, type = "RR3")
#' long_thin_to_rectangular(df)
#' half_na_join(l_df, r_df, by = character(0), by_half = character(0), suffix = c("_L","_R"))
#' super_sub_comparision(supergroup_table, subgroup_table, supergroup_subgroup_pairs, column_name, rounding)

library(testthat)

PRINT_FAILURES = FALSE

## populate_supergroup_values -------------------------------------------------- ----

test_that("Single replacement works", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A"),
    supergroup_val = c(99),
    subgroup_col = c("B"),
    subgroup_val = c(50),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,99,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("Multi replacement works", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A", "A", "A"),
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("B", "B", "B"),
    subgroup_val = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,99,98,99,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("no column match produces no change", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A", "A", "A"),
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("C", "C", "C"),
    subgroup_val = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expected_df = input_df
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("extra table columns have no effect", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A", "A", "A"),
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("B", "B", "B"),
    subgroup_val = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    C = 1:15,
    D = rep("test", 15),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,99,98,99,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    C = 1:15,
    D = rep("test", 15),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("extra super-sub pair columns have no effect", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A", "A", "A"),
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("B", "B", "B"),
    subgroup_val = c(50, 60, 70),
    extra_col = 1:3,
    col_extra = c('a','b','c'),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,99,98,99,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("_val converted to numeric when required", {
  # columns are type character
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A"),
    supergroup_val = c("99"),
    subgroup_col = c("B"),
    subgroup_val = c("50"),
    stringsAsFactors = FALSE
  )
  
  # columns are type numeric
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,99,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("_val converted to character when required", {
  # columns are type numeric
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A"),
    supergroup_val = c(99),
    subgroup_col = c("B"),
    subgroup_val = c(50),
    stringsAsFactors = FALSE
  )
  
  # columns are type character
  input_df = data.frame(
    A = c( "1",  NA),
    B = c("50","50"),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c( "1", "99"),
    B = c("50", "50"),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("Complex multi replacement works", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c( "A", "A", "A", "B", "B", "B", "D", "D"),
    supergroup_val = c(  99,  98,  99,   5,   6,   7, "y", "x"),
    subgroup_col   = c( "B", "B", "B", "A", "A", "A", "C", "B"),
    subgroup_val   = c(  50,  60,  70,   1,   2,   3, "a",  70),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c(  1,  2,  3, NA, NA, NA,  1,  2,  3),
    B = c( 50, 60, 70, 50, 60, 70, NA, NA, NA),
    C = c('a','b', NA,'a','b', NA,'a','b', NA),
    D = c( NA, NA, NA, NA, NA, NA,'z','z','z'),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c(  1,  2,  3, 99, 98, 99,  1,  2,  3),
    B = c( 50, 60, 70, 50, 60, 70,  5,  6,  7),
    C = c('a','b', NA,'a','b', NA,'a','b', NA),
    D = c('y', NA,'x','y', NA,'x','z','z','z'),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("missing subergroup column added in", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A"),
    supergroup_val = c(99),
    subgroup_col = c("B"),
    subgroup_val = c(50),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    B = c(50,60,70),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    B = c(50,60,70),
    A = c(99,NA,NA),
    stringsAsFactors = FALSE
  )
  
  actual_df = populate_supergroup_values(input_df, supergroup_subgroup_pairs)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})



test_that("invalid input fails", {
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("A", "A", "A"),
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("B", "B", "B"),
    subgroup_val = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  
  input_df = data.frame(
    A = c( 1, 2, 3, 4, 5, 1, 2, 3, 4, 5,NA,NA,NA,NA,NA),
    B = c(50,60,70,80,90,50,60,70,80,90,50,60,70,80,90),
    stringsAsFactors = FALSE
  )
  
  expect_error(populate_supergroup_values("input_df", supergroup_subgroup_pairs), "data.frame")
  expect_error(populate_supergroup_values(input_df, "supergroup_subgroup_pairs"), "data.frame")
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_val = c(99, 98, 99),
    subgroup_col = c("B", "B", "B"),
    subgroup_val = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  
  expect_error(populate_supergroup_values(input_df, supergroup_subgroup_pairs), "supergroup_col")
})

## compare_super_and_sub_counts ------------------------------------------------ ----

test_that("larger supergroups give no changes", {
  
  input_df = data.frame(
    A = c(21,30,42),
    B = c(12,21,33),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )
  
  expected_df = input_df
  
  actual_df = compare_super_and_sub_counts(input_df, "A", "B", type = "RR3")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("RR3 changes occur as expected", {
  
  input_df = data.frame(
    A = c(21,30,42),
    B = c(24,30,45),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c(21,30,42),
    B = c(21,30,42),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )
  
  actual_df = compare_super_and_sub_counts(input_df, "A", "B", type = "RR3")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("GRR changes occur as expected", {
  input_df = data.frame(
    A = c(15,18,20, 95,100, 990,1000,1100),
    B = c(18,20,25,100,110,1000,1100,1200),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c(15,18,20, 95,100, 990,1000,1100),
    B = c(15,18,20, 95,100, 990,1000,1100),
    stringsAsFactors = FALSE
  )
  
  actual_df = compare_super_and_sub_counts(input_df, "A", "B", type = "GRR")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("RR3-super vs GRR-sub changes occur as expected", {
  input_df = data.frame(
    A = c(15,18,24, 99,106, 993,1002,1188),
    B = c(18,20,25,100,110,1000,1100,1200),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A = c(15,18,24, 99,106, 993,1002,1188),
    B = c(15,18,20, 95,100, 990,1000,1100),
    stringsAsFactors = FALSE
  )
  
  actual_df = compare_super_and_sub_counts(input_df, "A", "B", type = "GRR")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("unrounded inputs warn", {
  
  input_df = data.frame(
    A = c(20,30,40),
    B = c(10,20,30),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )

  expect_warning(compare_super_and_sub_counts(input_df, "A", "B", type = "RR3"), "values not rounded")
})

test_that("too large subgroups warn (twice)", {
  
  input_df = data.frame(
    A = c(20,30,40),
    B = c(80,20,30),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )
  
  expect_warning(
    compare_super_and_sub_counts(input_df, "A", "B", type = "RR3"),
    "subgroup exceeds supergroup by more than random rounding"
  )
  
  expect_warning(
    compare_super_and_sub_counts(input_df, "A", "B", type = "RR3"),
    "subgroup exceeds supergroup after adjustment"
  )
})

test_that("invalid input fails", {
  
  input_df = data.frame(
    A = c(21,30,42),
    B = c(12,21,33),
    C = c('x','y','z'),
    stringsAsFactors = FALSE
  )
  
  expect_error(compare_super_and_sub_counts("input_df", "A", "B", type = "RR3"), "data.frame")
  expect_error(compare_super_and_sub_counts(input_df, "a", "B", type = "RR3"), "colnames")
  expect_error(compare_super_and_sub_counts(input_df, "A", "b", type = "RR3"), "colnames")
  expect_error(compare_super_and_sub_counts(input_df, 4, "B", type = "RR3"), "is.character")
  expect_error(compare_super_and_sub_counts(input_df, "A", 123, type = "RR3"), "is.character")
  expect_error(compare_super_and_sub_counts(input_df, "A", "B", type = "RR2"), "\"RR3\", \"GRR\"")
  expect_error(compare_super_and_sub_counts(input_df, "A", "B", type = "RR3", 'true'), "is.logical")
})

## long_thin_to_rectangular ---------------------------------------------------- ----

test_that("single value run", {
  
  input_df = data.frame(
    col01 = c("a","a","a"),
    val01 = c(  1,  2,  3),
    summarised_var = 10,
    count = 100,
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    a = c("1","2","3"),
    summarised_var = 10,
    count = 100,
    stringsAsFactors = FALSE
  )
  
  actual_df = long_thin_to_rectangular(input_df)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("simple test case runs", {
  
  input_df = data.frame(
    col01 = c("a","b", NA),
    val01 = c(  1,  2, NA),
    col02 = c("c","d","d"),
    val02 = c(  3,  4,  5),
    summarised_var = 10,
    count = 100,
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    a = c("1", NA,NA),
    b = c(NA, "2",NA),
    c = c("3", NA,NA),
    d = c(NA, "4", "5"),
    summarised_var = 10,
    count = 100,
    stringsAsFactors = FALSE
  )
  
  actual_df = long_thin_to_rectangular(input_df)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("complex test case runs", {
  
  input_df = data.frame(
    col01 = c("a","a","a","a","a","a","a","a"),
    val01 = c(  1,  1,  1,  1,  1,  1,  1,  1),
    col02 = c("b","b","b","b","c","c","c","c"),
    val02 = c(  1,  2,  1,  2,  1,  2,  1,  2),
    col03 = c("d","d", NA, NA,"d","d", NA, NA),
    val03 = c("x","y", NA, NA,"x","y", NA, NA),
    summarised_var = c(10,20,30,40,50,60,70,80),
    count = c(NA,NA,100,200,NA,NA,150,250),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    a = c("1","1","1","1","1","1","1","1"),
    b = c("1","2","1","2", NA, NA, NA, NA),
    c = c( NA, NA, NA, NA,"1","2","1","2"),
    d = c("x","y", NA, NA,"x","y", NA, NA),
    summarised_var = c(10,20,30,40,50,60,70,80),
    count = c(NA,NA,100,200,NA,NA,150,250),
    stringsAsFactors = FALSE
  )
  
  actual_df = long_thin_to_rectangular(input_df)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  expect_true(all.equal(actual_df, expected_df))
})

test_that("invalid input fails", {
  
  input_df = data.frame(
    col01 = c("a","b", NA),
    val01 = c(  1,  2, NA),
    col02 = c("c","d","d"),
    val02 = c(  3,  4,  5),
    summarised_var = 10,
    count = 100,
    stringsAsFactors = FALSE
  )
  
  expect_error(long_thin_to_rectangular("input_df"), "data.frame")
  
  tmp_df = dplyr::rename(input_df, xcol01 = col01, xcol02 = col02)
  expect_error(long_thin_to_rectangular(tmp_df), "\\^col")
  
  tmp_df = dplyr::rename(input_df, xval01 = val01, xval02 = val02)
  expect_error(long_thin_to_rectangular(tmp_df), "\\^val")
  
  tmp_df = dplyr::select(input_df, -val02)
  expect_error(long_thin_to_rectangular(tmp_df), "== length")
})

## half_na_join ---------------------------------------------------------------- ----

test_that("inner join works", {
  
  input_df = data.frame(
    Aaa = c(  1,  2,  1, NA),
    Bbb = c("A","A","B", NA),
    val = c( 21,  9, 12, 63),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    Aaa   = c(  1,  1,  1,  1,  2, NA),
    Bbb_L = c("A","A","B","B","A", NA),
    val_L = c( 21, 21, 12, 12,  9, 63),
    Bbb_R = c("A","B","A","B","A", NA),
    val_R = c( 21, 12, 21, 12,  9, 63),
    stringsAsFactors = FALSE
  )

  actual_df = half_na_join(input_df, input_df, by = "Aaa")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("cross join works", {
  
  input_df = data.frame(
    Aaa = c(  1,  2, NA),
    Bbb = c("A","B", NA),
    val = c( 21,  9, 63),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    Aaa_L = c(  1,  1,  1,  2,  2,  2, NA, NA, NA),
    Bbb_L = c("A","A","A","B","B","B", NA, NA, NA),
    val_L = c( 21, 21, 21,  9,  9,  9, 63, 63, 63),
    Aaa_R = c(  1,  2, NA,  1,  2, NA,  1,  2, NA),
    Bbb_R = c("A","B", NA,"A","B", NA,"A","B", NA),
    val_R = c( 21,  9, 63, 21,  9, 63, 21,  9, 63),
    stringsAsFactors = FALSE
  )
  
  actual_df = half_na_join(input_df, input_df)
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("simple half joins works", {
  
  input_df = data.frame(
    A   = c(  1,  2,  1,  2),
    B   = c("A","A", NA, NA),
    val = c( 21,  9, 51, 54),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A     = c(  1,  2,  1,  2,  1,  2),
    B_L   = c("A","A", NA, NA,"A","A"),
    val_L = c( 21,  9, 51, 54, 21,  9),
    B_R   = c("A","A", NA, NA, NA, NA),
    val_R = c( 21,  9, 51, 54, 51, 54),
    stringsAsFactors = FALSE
  )
  
  actual_df = half_na_join(input_df, input_df, by = "A", by_half = "B")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("complex half join works", {
  
  input_df = data.frame(
    A   = c(  1,  2,  1,  2,  1,  2, NA, NA, NA),
    B   = c("A","A","B","B", NA, NA,"A","B", NA),
    val = c( 21,  9, 12, 48, 51, 54, 57, 60, 63),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A_L   = c(  1,  2,  1,  2,  1,  2, NA, NA, NA,  1,  2,  1,  2,  1,  2,  1,  2,  1,  2, NA, NA,  1,  2,  1,  2),
    B_L   = c("A","A","B","B", NA, NA,"A","B", NA,"A","A","B","B","A","A","B","B", NA, NA,"A","B","A","A","B","B"),
    val_L = c( 21,  9, 12, 48, 51, 54, 57, 60, 63, 21,  9, 12, 48, 21,  9, 12, 48, 51, 54, 57, 60, 21, 9, 12,  48),
    A_R   = c(  1,  2,  1,  2,  1,  2, NA, NA, NA,  1,  2,  1,  2, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA),
    B_R   = c("A","A","B","B", NA, NA,"A","B", NA, NA, NA, NA, NA,"A","A","B","B", NA, NA, NA, NA, NA, NA, NA, NA),
    val_R = c( 21,  9, 12, 48, 51, 54, 57, 60, 63, 51, 54, 51, 54, 57, 57, 60, 60, 63, 63, 63, 63, 63, 63, 63, 63),
    stringsAsFactors = FALSE
  )
  
  actual_df = half_na_join(input_df, input_df, by_half = c("A","B"))
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("different Left and Right tables works", {
  
  left_input_df = data.frame(
    A   = c(  1,  2),
    B   = c("A","A"),
    val = c( 21,  9),
    stringsAsFactors = FALSE
  )
  
  right_input_df = data.frame(
    A   = c(  1,  2,  1),
    B   = c( NA, NA,"z"),
    val = c( 51, 54, NA),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A     = c(  1,  2),
    B_L   = c("A","A"),
    val_L = c( 21,  9),
    B_R   = c( NA_character_, NA_character_),
    val_R = c( 51, 54),
    stringsAsFactors = FALSE
  )
  
  actual_df = half_na_join(left_input_df, right_input_df, by = "A", by_half = "B")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("suffix change works", {
  
  input_df = data.frame(
    A   = c(  1,  2,  1,  2),
    B   = c("A","A", NA, NA),
    val = c( 21,  9, 51, 54),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    A     = c(  1,  2,  1,  2,  1,  2),
    B.x   = c("A","A", NA, NA,"A","A"),
    val.x = c( 21,  9, 51, 54, 21,  9),
    B.y   = c("A","A", NA, NA, NA, NA),
    val.y = c( 21,  9, 51, 54, 51, 54),
    stringsAsFactors = FALSE
  )
  
  actual_df = half_na_join(input_df, input_df, by = "A", by_half = "B", suffix = c(".x",".y"))
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("invalid input fails", {
  
  input_df = data.frame(
    A   = c(  1,  2,  1,  2),
    B   = c("A","A", NA, NA),
    val = c( 21,  9, 51, 54),
    stringsAsFactors = FALSE
  )
  
  expect_error(half_na_join("input_df", input_df, by = "A", by_half = "B"), "data.frame")
  expect_error(half_na_join(input_df, "input_df", by = "A", by_half = "B"), "data.frame")
  expect_error(half_na_join(input_df, input_df, by = "zzz", by_half = "B"), "colnames")
  expect_error(half_na_join(input_df, input_df, by = "A", by_half = "zzz"), "colnames")
  expect_error(half_na_join(input_df, input_df, by = NA, by_half = "B"), "character")
  expect_error(half_na_join(input_df, input_df, by = "A", by_half = 4), "character")
  expect_error(half_na_join(input_df, input_df, by = "A", by_half = "B", suffix = c(1,2)), "character")
  expect_error(half_na_join(input_df, input_df, by = "A", by_half = "B", suffix = "q"), "length")
})

## super_sub_comparision ------------------------------------------------------- ----

test_that("basic test case", {
  
  input_df = data.frame(
    col01 = c("a","a", NA),
    val01 = c(  1,  2, NA),
    count = c( 99,105,102),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    col01 = c("a","a", NA),
    val01 = c(  1,  2, NA),
    count = c( 99,102,102),
    stringsAsFactors = FALSE
  )
  
  # placeholder
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("x"),
    supergroup_val = c(1),
    subgroup_col = c("y"),
    subgroup_val = c(2),
    stringsAsFactors = FALSE
  )
  
  actual_df = super_sub_comparision(input_df, input_df, supergroup_subgroup_pairs, "count", "RR3")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("expanded test case", {
  
  input_df = data.frame(
    col01 = c("A","A","A","A","A","A","A","A"),
    val01 = c("1","1","1","2","2","2","1","2"),
    col02 = c("B","B","C","B","B","C", NA, NA),
    val02 = c("1","2","1","1","2","2", NA, NA),
    count = c(120, 95,120, 75, 90, 90,110, 85),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    col01 = c("A","A","A","A","A","A","A","A"),
    val01 = c("1","1","1","2","2","2","1","2"),
    col02 = c("B","B","C","B","B","C", NA, NA),
    val02 = c("1","2","1","1","2","2", NA, NA),
    count = c(110, 95,110, 75, 85, 85,110, 85),
    stringsAsFactors = FALSE
  )
  
  # placeholder
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("x"),
    supergroup_val = c(1),
    subgroup_col = c("y"),
    subgroup_val = c(2),
    stringsAsFactors = FALSE
  )
  
  actual_df = super_sub_comparision(input_df, input_df, supergroup_subgroup_pairs, "count", "GRR")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("test case with different super and subgroup tables", {
  
  input_super_df = data.frame(
    col01 = c("a", NA),
    val01 = c(  1, NA),
    count = c( 96,102),
    stringsAsFactors = FALSE
  )
  
  input_sub_df = data.frame(
    col01 = c("a","a"),
    val01 = c(  1,  2),
    count = c( 99,105),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    col01 = c("a","a"),
    val01 = c(  1,  2),
    count = c( 96,102),
    stringsAsFactors = FALSE
  )
  
  # placeholder
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("x"),
    supergroup_val = c(1),
    subgroup_col = c("y"),
    subgroup_val = c(2),
    stringsAsFactors = FALSE
  )
  
  actual_df = super_sub_comparision(input_super_df, input_sub_df, supergroup_subgroup_pairs, "count", "RR3")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("test case with supergroup-subgroup pairs", {
  
  input_df = data.frame(
    col01 = c("big","small"),
    val01 = c(  1,  1),
    count = c(15,18),
    stringsAsFactors = FALSE
  )
  
  expected_df = data.frame(
    col01 = c("big","small"),
    val01 = c(  1,  1),
    count = c(15,15),
    stringsAsFactors = FALSE
  )
  
  # essential
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("big"),
    supergroup_val = c(1),
    subgroup_col = c("small"),
    subgroup_val = c(1),
    stringsAsFactors = FALSE
  )
  
  actual_df = super_sub_comparision(input_df, input_df, supergroup_subgroup_pairs, "count", "RR3")
  
  # consistent dimensions
  expect_equal(nrow(actual_df), nrow(expected_df))
  expect_equal(ncol(actual_df), ncol(expected_df))
  
  # consistent column names
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  expect_true(all(colnames(actual_df) %in% colnames(expected_df)))
  
  # values match
  actual_df = dplyr::select(actual_df, all_of(colnames(actual_df)))
  expected_df = dplyr::select(expected_df, all_of(colnames(actual_df)))
  actual_df = dplyr::arrange(actual_df, !!!rlang::parse_exprs(colnames(actual_df)))
  expected_df = dplyr::arrange(expected_df, !!!rlang::parse_exprs(colnames(actual_df)))
  
  expect_true(all.equal(actual_df, expected_df))
})

test_that("invalid input fails", {
  
  input_df = data.frame(
    col01 = c("a","a", NA),
    val01 = c(  1,  2, NA),
    count = c( 99,105,102),
    stringsAsFactors = FALSE
  )
  
  supergroup_subgroup_pairs = data.frame(
    supergroup_col = c("x"),
    supergroup_val = c(1),
    subgroup_col = c("y"),
    subgroup_val = c(2),
    stringsAsFactors = FALSE
  )
  
  expect_error(super_sub_comparision("input_df", input_df, supergroup_subgroup_pairs, "count", "RR3"), "data.frame")
  expect_error(super_sub_comparision(input_df, "input_df", supergroup_subgroup_pairs, "count", "RR3"), "data.frame")
  expect_error(super_sub_comparision(input_df, input_df, "supergroup_subgroup_pairs", "count", "RR3"), "data.frame")
  expect_error(super_sub_comparision(input_df, input_df, supergroup_subgroup_pairs, "zzz", "RR3"), "colnames")
  expect_error(super_sub_comparision(input_df, input_df, supergroup_subgroup_pairs, "count", "zzz"), "RR3")
})

## ----
