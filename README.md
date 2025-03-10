# Regional_Data_Explorer
Contains code and tools to create the IDI indicators contained in SIA's Regional Data Explorer

# Regional Data Explorer - IDI Indicators

IDI analysis conducted by the Social Investment Agency to create indicators for publication in our Regional Data Explorer.

## Overview

This code contributed to the creation of SIA's PowerBI dashboard ['Regional Data Explorer'](https://www.sia.govt.nz/what-we-do/regional-data-explorer), published on the Agency's website. 

This explorer aimed to bring a number of social sector indicators into one place and utilise the IDI to provide deeper dives into communities by enabling demographic filtering.

Note: some of the indicators published in the Regional Data Explorer were sourced directly from agencies. See the data dictionary on the dashboard for individual indicator source details.

## Dependencies

It is necessary to have an IDI project if you wish to run the code. Visit the Stats NZ website for more information about this.

This code has been developed for the IDI_Clean_202410 refresh of the IDI. As changes in database structure and table names can occur between refreshes, the initial preparation of the input information may require updating to run the code in other refreshes. This code also reads and writes to a project-specific sandpit tables. It will be necessary for others to change these project references when running the code.

The R code makes use of several publicly available R packages. Stats NZ who maintain the IDI have already installed in the IDI the all the key packages that this analysis depends on. 

## Instructions to run the project

This project uses a master table containing a base population, then adds flags for each indicator.

To prepare the necessary base tables (date reference table '[quarters]' and base population '[master_table_202410]' run the following code:

- RDE Input - 1_Population_master_202410

The following indicator codes can then be run sequentially (in numerical order);

- RDE Input -  2_bespoke_ages_202410
- RDE Input -  3_PHO_enrolment_202410
- RDE Input -  4_immunisation_202410
- RDE Input -  5_school_enrolled_202410
- RDE Input -  6_school_moves_202410
- RDE Input -  7_AS_unjab_202410
- RDE Input -  8_attending_school_employed_202410
- RDE Input -  9_B4SC_202410
- RDE Input -  10_ECE_attendance_202410
- RDE Input -  11_OTInvestigationPlus_202410
- RDE Input -  12_child_incarcerated_parent_202410
- RDE Input -  13_driving_licence_202410
- RDE Input -  14_tertiary_enrolment_202410
- RDE Input -  15_Highest_qual_202410
- RDE Input -  16_NEET_25YO_202410
- RDE Input -  17_NEET_202410
- RDE Input -  18_industry_of_employment_202410
- RDE Input -  19_industry_of_employment_25YO_202410
- RDE Input -  20_employed_202410
- RDE Input -  21_PAH_202410
- RDE Input -  22_Total_income_last_12mo_202410
- RDE Input -  23_GCH_ind_202410


Then the summarisation tools can be run in R in the following order;

- generate_results
- super_sub_group
- combine_output

## Citation

Social Investment Agency (2024). *Regional Data Explorer* Source. https://www.sia.govt.nz/what-we-do/regional-data-explorer

## Getting Help

If you have any questions email info@sia.govt.nz

