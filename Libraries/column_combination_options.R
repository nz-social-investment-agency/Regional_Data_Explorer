# This function produces column combinations for the summarisation
# It is intended to enable us to more flexibly  use the summarisation part of the tool.
# 
# The approach is to give each summarisation grouping a name. This is used to look up 
# the appropriate summarisation to use.
# 


make_column_combos <- function(x = ""){
  
  eth_cols = c("european","maori","pacific","asian","MELAA","other", "unknown_eth")
  REGION_LIST <- c("POPULATION","REGC","TALB")
  
  if (x == "Dimensions_school"){
    # New default dimensions (reducing splits)
    # Geography and quarter
    # Geography and 
    column_combinations <- c(
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(eth_cols, "AGE_prim_sec", "sex_no_gender", "NZDep2018", "swa_urban_rural_ind"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(eth_cols),
        always = c("quarter", "sex_no_gender")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("sex_no_gender", "swa_urban_rural_ind", "NZDep2018", eth_cols),
        always = c("quarter", "AGE_prim_sec")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(eth_cols),
        always = c("quarter", "AGE_prim_sec", "sex_no_gender")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("sex_no_gender", "swa_urban_rural_ind"), 
        always = c("quarter", "AGE_prim_sec", "NZDep2018")
      ),
      
      # Age by sex and U/R
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter", "AGE_prim_sec", "sex_no_gender", "swa_urban_rural_ind")
      ),
      
      # Age by sex and U/R
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("sex_no_gender", "swa_urban_rural_ind"),
        always = c("quarter", "NZDep2018")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter", "NZDep2018", "sex_no_gender", "swa_urban_rural_ind")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter", "sex_no_gender", "swa_urban_rural_ind")
      ),
      
      # Lowest level breakdowns
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter", "AGE_prim_sec", "NZDep2018", "sex_no_gender", "swa_urban_rural_ind")
      )
    )
    
  }
  if (x == "Dimensions_bespoke_age"){
    # Bespoke age col should be input
    column_combinations <- c(
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        grp3 = c("sex_no_gender", "swa_urban_rural_ind", "NZDep2018", eth_cols),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        grp3 = c(eth_cols),
        grp4 = c("sex_no_gender"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        grp3 = c("NZDep2018"),
        grp4 = c("sex_no_gender", "swa_urban_rural_ind"), 
        always = c("quarter")
      ),
      
      # Age by sex and U/R
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        grp3 = c("sex_no_gender"),
        grp4 = c("swa_urban_rural_ind"), 
        always = c("quarter")
      ),
      
      # Lowest level breakdowns
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(AGE_COL),
        grp3 = c("NZDep2018"),
        grp4 = c("sex_no_gender"),
        grp5 = c("swa_urban_rural_ind"),
        always = c("quarter")
      )
    )
    
  } 
  if (x == "Dimensions_default"){
    # New default dimensions (reducing splits)
    # Geography and quarter
    # Geography and 
    column_combinations <- c(
      cross_product_column_names(
        grp1 = REGION_LIST,
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(eth_cols, "AGE_RDP", "sex_no_gender", "NZDep2018", "swa_urban_rural_ind"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c(eth_cols),
        grp3 = c("sex_no_gender"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("AGE_RDP"),
        grp3 = c("sex_no_gender", "swa_urban_rural_ind", "NZDep2018", eth_cols),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("AGE_RDP"),
        grp3 = c(eth_cols),
        grp4 = c("sex_no_gender"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("AGE_RDP"),
        grp3 = c("NZDep2018"),
        grp4 = c("sex_no_gender", "swa_urban_rural_ind"), 
        always = c("quarter")
      ),
      
      # Age by sex and U/R
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("AGE_RDP"),
        grp3 = c("sex_no_gender"),
        grp4 = c("swa_urban_rural_ind"), 
        always = c("quarter")
      ),
      
      # Age by sex and U/R
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("NZDep2018"),
        grp3 = c("sex_no_gender", "swa_urban_rural_ind"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("NZDep2018"),
        grp3 = c("sex_no_gender"),
        grp4 = c("swa_urban_rural_ind"),
        always = c("quarter")
      ),
      
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("sex_no_gender"),
        grp3 = c("swa_urban_rural_ind"),
        always = c("quarter")
      ),
      
      # Lowest level breakdowns
      cross_product_column_names(
        grp1 = REGION_LIST,
        grp2 = c("AGE_RDP"),
        grp3 = c("NZDep2018"),
        grp4 = c("sex_no_gender"),
        grp5 = c("swa_urban_rural_ind"),
        always = c("quarter")
      )
    )
    
  }
  
  column_combinations <- unique(column_combinations)
  return(column_combinations)
}
