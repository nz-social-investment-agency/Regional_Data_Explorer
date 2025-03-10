/**************************************************************************************************
Title: Spell enrolled in tertiary education
Author: Simon Anastasiadis
Modified by Dan Young for data for communities project, Verity Warn for Regional Data Project
Peer Review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202410].[moe_clean].[enrolment]
- [IDI_Clean_202410].[moe_clean].[course]
- [IDI_Clean_202410].[moe_clean].[tec_it_learner]
- [IDI_Sandpit].[DL-MAA2023-55].[mt_quarters]
- [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]

Outputs/additions:
- [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]

Description:
Tertiary study includes the participation in one of universities, Te Pūkenga, wānanga, government-funded private training establishments and industry training.
This code creates an indication of whether a person has participated in tertiary study in a given time period, split by industry vs. non-industry training, 
as well as into part time or full time study for the 

A spell with any enrollment in tertiary education, regardless of source (tertiary education or industry training).
Seperate spells for part time, full time and both for non industry training (IT).

Intended purpose:
Creating indicators of whether a person is studying at a tertiary institution in a given quarter,
and whether this is part or full time.

Notes:
1) Writing a staging table (rather than a staging view) is faster as we can add an index.
2) [moe_clean].[enrolment] does not include cancellations/withdrawls. Hence it may overcount.
   Some withdrawl dates from courses can be retrieved from [moe_clean].[course] where this   
   is important. Withdrawls from industry training are not available.
3) When aggregating by region this will likely coincide with tertiary education providers (e.g. Universities Auckland, Wellington, Christchurch, Dunedin)
4) Full time is prioritised over part time. If someone has both full- and part-time study they are recorded as full-time for that
   quarter (as they're essentialy doing more-than full-time).
5) Using 202310 refresh wouldn't recommend using data after 2020Q4 as coverage drops dramatically (lose about 80%)
6) Where nulls exist in the end_dates for industry trainin, the end date for the last year reported on for the individual and training provider are imputed.

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

To improve speed by filtering out dates before/after our periods of interest:
  Earliest start date = first RDP quarter	
  Latest end date = last RDP quarter

Issues:
1) Industry training duration of enrollment can differ widely from expected duration of
   course. We are yet to determine how best to reconcile this difference. At present we consider
   only enrollment.
2) Lag in both Tert and TEC datasets - 202410 Refresh latest date 202312

History (reverse order):
2024-05-09 AA Imputation for industry training end dates, removal of targeted training
2024-04-26 VW Updated to RDP refresh (202410), remove secondary enrolment, alter filters to add additional flags 
		      (part time, full time, any), filter dates to overlap with RDP quarters, remove spell overlap
			  condensing as only interested in if enrolled in the quarter (not duration) and want to preserve different 
			  spell types (part/full time) - replace with select distinct to remove some of these duplicate cases. 
2023-06-16 DY updated for latest refresh and incorporated join to master dataset for MT
2022-05-19 JG updated with provider code for entity count
2022-04-05 JG updated project and refresh for Data for Communities
2020-05-26 SA corrected to include secondary school enroll
2020-03-02 SA v1
**************************************************************************************************/
--Check max dates

 -- SELECT TOP 40 enr.moe_enr_prog_start_date
	--,COUNT(*)
 -- FROM [IDI_Clean_202410].[moe_clean].[enrolment] enr
 -- GROUP BY enr.moe_enr_prog_start_date
 -- Order by enr.moe_enr_prog_start_date desc


/**************************************************************************************
Step 1: Create table of all spells, specifying source and type (part-time/full-time)
**************************************************************************************/
/* Clear staging table */
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging]

/* Create staging table */

/* Enrolment in tertiary education - [moe_enr_prog_start_date] and [moe_enr_prog_end_date] don't have NULLs*/
SELECT DISTINCT enr.snz_uid
    , CAST([moe_enr_provider_code] AS int) AS provider_code
    , 'tertiary' AS [source]
    , [moe_enr_prog_start_date] AS [start_date] -- [moe_enr_prog_start_date] has no NULLs
    , CASE WHEN [moe_crs_withdrawal_date] IS NOT NULL AND [moe_crs_withdrawal_date] < [moe_enr_prog_end_date] THEN [moe_crs_withdrawal_date] ELSE [moe_enr_prog_end_date] END AS [end_date] -- [moe_enr_prog_end_date] has no NULLs
    , 1 AS tertiary_study_any -- this will include those with NULL as study_type_code (meaning 'non applicable (non type D courses)') who are not included elsewhere
    , CASE WHEN [moe_enr_study_type_code] IN (3,4) THEN 1 ELSE NULL END AS tertiary_study_part_time
    , CASE WHEN [moe_enr_study_type_code] NOT IN (3,4) THEN 1 ELSE NULL END AS tertiary_study_full_time -- approximating 120 credits (for full time) times .03 as a minimum threshold
INTO [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging]
FROM [IDI_Clean_202410].[moe_clean].[enrolment] enr
LEFT JOIN [IDI_Clean_202410].[moe_clean].[course] crs
ON enr.snz_uid = crs.snz_uid
AND enr.[moe_enr_snz_unique_nbr] = crs.[moe_crs_snz_unique_nbr]
AND enr.[moe_enr_prog_start_date] = crs.[moe_crs_start_date]
WHERE moe_enr_qual_type_code = 'D' -- include formal education of more than 1 week duration and .03 EFTS
-- filter to within RDP quarters (starts before last RDP quarter and ends after first RDP quarter starts):
AND [moe_enr_prog_start_date] <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
)
AND CASE WHEN [moe_crs_withdrawal_date] IS NOT NULL AND [moe_crs_withdrawal_date] < [moe_enr_prog_end_date] THEN [moe_crs_withdrawal_date] ELSE [moe_enr_prog_end_date] END >= (
    SELECT MIN(startdate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
)

UNION ALL

/*Enrolment in industry training*/
SELECT DISTINCT [snz_uid]
    , [provider_code]
    , [source]
    , [start_date]
    , ISNULL([moe_itl_end_date], DATEFROMPARTS([final_year], 12, 31)) AS end_date --where end_date is NULL, impute the end date as the last day of the final year of recorded participation
    , [tertiary_study_any]
    , [tertiary_study_part_time]
    , [tertiary_study_full_time]

FROM 
(
    SELECT [snz_uid]
        , CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
        , 'tec_it_learner' AS [source]
        , [moe_itl_start_date] AS [start_date] -- [moe_itl_start_date] has no NULLs
        , MAX(moe_itl_year_nbr) OVER (PARTITION BY SNZ_UID, MOE_ITL_EDUMIS_2016_CODE) AS final_year --imputing
        , [moe_itl_end_date]
        , 1 AS tertiary_study_any
        , NULL AS tertiary_study_part_time
        , NULL AS tertiary_study_full_time
    FROM [IDI_Clean_202410].[moe_clean].[tec_it_learner]
    WHERE [moe_credit_value_nbr] >= 4 -- approximateing 120 credits (for full time) times .03 as a minimum threshold
    AND [moe_itl_start_date] <= (
        SELECT MAX(enddate)
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    )
    AND [moe_itl_year_nbr] >= (
        SELECT MIN(YEAR(startdate))
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    )- 1
)k
 CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] (snz_uid)



/**************************************************************************************
Step 2: Join to quarters (more than one row per person per quarter)
NB: could leave source in here if wanted to split by source 
**************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[tmp_enrolled_tertiary_education_quarters];

SELECT a.snz_uid
    , q.quarter
    , MAX(a.tertiary_study_any) AS tertiary_study_any
    , MAX(a.tertiary_study_part_time) AS tertiary_study_part_time
    , MAX(a.tertiary_study_full_time) AS tertiary_study_full_time
    , MAX(CASE WHEN a.source = 'tertiary' THEN 1 ELSE NULL END) AS tertiary_excl_ITO
    , MAX(CASE WHEN a.source = 'tec_it_learner' THEN 1 ELSE NULL END) AS ITO

INTO [IDI_Sandpit].[DL-MAA2023-55].[tmp_enrolled_tertiary_education_quarters]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
GROUP BY a.snz_uid
    , q.quarter
 CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[tmp_enrolled_tertiary_education_quarters] (snz_uid, quarter)



/**************************************************************************************
Step 3: Join to master table
**************************************************************************************/

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS tert_study_any
    , COLUMN IF EXISTS tert_study_non_ITO_pt
    , COLUMN IF EXISTS tert_study_non_ITO_ft
    , COLUMN IF EXISTS tert_study_non_ITO
    , COLUMN IF EXISTS tert_study_ITO;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD tert_study_any int
    , tert_study_non_ITO_pt int
    , tert_study_non_ITO_ft int
    , tert_study_non_ITO int
    , tert_study_ITO int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET tert_study_any = CASE WHEN tertiary.tertiary_study_any = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , tert_study_non_ITO_pt = CASE WHEN tertiary.tertiary_study_part_time = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , tert_study_non_ITO_ft = CASE WHEN tertiary.tertiary_study_full_time = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , tert_study_non_ITO = CASE WHEN tertiary.tertiary_excl_ITO = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , tert_study_ITO = CASE WHEN tertiary.ITO = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END

FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_enrolled_tertiary_education_quarters] tertiary
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = tertiary.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = tertiary.[quarter]

--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


/**************************************************************************************
Step 4: Create entity tables
Note: At least for 202310 refresh, there are no cases where entity_1 is NULL
**************************************************************************************/

-- Entities for any tertiary study indicator

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ANY_ENT]

SELECT a.snz_uid
    , q.quarter
    , CAST(a.provider_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ANY_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
WHERE tertiary_study_any = 1
GROUP BY snz_uid
    , quarter
    , provider_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ANY_ENT] ([snz_uid], [quarter])
; ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ANY_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


-- Entities for part-time tertiary study indicator

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_PT_ENT]

SELECT a.snz_uid
    , q.quarter
    , CAST(a.provider_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_PT_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
WHERE tertiary_study_part_time = 1
GROUP BY snz_uid
    , quarter
    , provider_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_PT_ENT] ([snz_uid], [quarter])
; ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_PT_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


-- Entities for full-time tertiary study indicator

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_FT_ENT]

SELECT a.snz_uid
    , q.quarter
    , CAST(a.provider_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_FT_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
WHERE tertiary_study_full_time = 1
GROUP BY snz_uid
    , quarter
    , provider_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_FT_ENT] ([snz_uid], [quarter])
; ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_FT_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)

-- Entities for tertiary excluding ITO

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_ENT]

SELECT a.snz_uid
    , q.quarter
    , CAST(a.provider_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
WHERE source = 'tertiary'
GROUP BY snz_uid
    , quarter
    , provider_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_ENT] ([snz_uid], [quarter])
; ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_NON_ITO_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


-- Entities for ITO

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ITO_ENT];

SELECT a.snz_uid
    , q.quarter
    , CAST(a.provider_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ITO_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging] a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.start_date <= q.enddate
AND a.end_date >= q.startdate
WHERE source = 'tec_it_learner'
GROUP BY snz_uid
    , quarter
    , provider_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ITO_ENT] ([snz_uid], [quarter])
; ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[TERT_STUDY_ITO_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


/**************************************************************************************
Step 5: Drop temporary tables when done
**************************************************************************************/
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[tmp_tertiary_education_staging]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[tmp_enrolled_tertiary_education_quarters]
