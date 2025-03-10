/**************************************************************************************************
Title: enrolled in School
Author: Ashleigh Arendt
Peer review: Charlotte Rose

Inputs & Dependencies:
- [IDI_Clean_$(refresh)].[moe_clean].[student_enrol] - this can be generated as part of the school attendance code module
- [IDI_UserCode].[DL-$(project)].[mt_quarters]

Outputs:
- Update to [$(newmaster)]

Description:
Indication of whether a child was enrolled in school as indicated by moe's student enrol dataset.

Intended purpose:
Get base populations to calculate rates for children's interactions with the school system.

Notes:
1) The student enrol data should have been updated within 5 days of a student joining
2) We are including children who attend private schools in our base population where we have enrolment data for them.
3) Primary and secondary school ages are determined with the following logic:
	- If someone is in year 1-8 AND between the ages of 5-13 inclusive then they are assigned to primary school, 
	or else if they are not in year 9-15 and are of primary school age (5-12) then they are assigned to primary school
	- If someone is in year 9-15 AND between the ages of 12 to 18 inclusive then they are assigned to secondary school,
	or else if they are not in year 1-8 and are of secondary school age (13-18) then they are assigned to secondary school
4) Excludes 1 day enrolments as recommended by MoE


Parameters & Present values:
  Current refresh = $(refresh)
  Prefix = _
  Project schema = [DL-$(project)]
  Earliest start date = 2007

Issues: 
- Data quality issues for student_enrol prior to 2007
- There are some children with unrealistic school years
- Extraction appears to be annual in August, therefore will only be updated in October refreshes. Max enrolment dates (by complete quarter) for refreshes are below;
	202303 Q22022
	202306 Q22022
	202310 Q22023
	202403 Q22023
	202406 Q22023
	$(refresh) Q22024


 Runtime (before joining to master) - 00:04:17
 Runtime (joining to master) - 01:58:59 

History (reverse order):
2023-03-14 - AA

**************************************************************************************************/
--check max date--

--SELECT TOP 40 e.moe_esi_end_date
--		,COUNT (*)
--FROM [IDI_Clean_$(refresh)].[moe_clean].[student_enrol] e 
--GROUP BY e.moe_esi_end_date
--ORDER BY e.moe_esi_end_date desc

/*PARAMETERS

SQLCMD only (Activate by clicking Query->SQLCMD Mode)*/

--Update with project and current refresh--

:setvar project "MAA20XX-XX" :setvar newmaster "Master_population_$(refresh)" :setvar refresh "$(refresh)"


DROP TABLE IF EXISTS #school_enrol_years;
SELECT a.snz_uid
    , quarter
    , a.moe_esi_provider_code AS entity_1
    , CASE WHEN moe_esi_entry_year_lvl_nbr > 0 THEN DATEDIFF(YEAR, moe_esi_start_date, enddate) + moe_esi_entry_year_lvl_nbr -- get the school year from the difference between the entry year level and the year associated with the quarter
		  ELSE NULL END AS year_level
INTO #school_enrol_years
FROM [IDI_Clean_$(refresh)].[moe_clean].[student_enrol] a
INNER JOIN [IDI_UserCode].[DL-$(project)].[mt_quarters] qt
ON a.moe_esi_start_date <= qt.enddate
AND CASE WHEN a.moe_esi_end_date IS NULL THEN '9999-12-31' ELSE a.moe_esi_end_date END >= qt.startdate --imputing nulls with max end date
LEFT JOIN [IDI_Clean_$(refresh)].[moe_clean].[provider_profile] b
ON a.moe_esi_provider_code = b.moe_pp_provider_code
LEFT JOIN [IDI_Clean_$(refresh)].[moe_clean].[student_per] c
ON a.snz_uid = c.snz_uid
WHERE DATEDIFF(DAY, moe_esi_start_date, IIF(a.moe_esi_end_date IS NULL,'9999-12-31',a.moe_esi_end_date)) ! = 1 -- exclude one day enrolments
AND(
    b.moe_pp_provider_auth_code NOT IN (42002, 42003)
    OR b.moe_pp_provider_auth_code IS NULL
) -- exclude private schools
AND(
    b.moe_pp_provider_type_code NOT IN (10031)
    OR b.moe_pp_provider_type_code IS NULL
)  -- exclude correspondence schools
AND(
    c.moe_spi_domestic_status_code ! = 60004
    OR c.moe_spi_domestic_status_code IS NULL
) -- exclude foreign fee paying students
GROUP BY a.snz_uid
    , quarter
    , a.moe_esi_provider_code
    , CASE WHEN moe_esi_entry_year_lvl_nbr > 0 THEN DATEDIFF(YEAR, moe_esi_start_date, enddate) + moe_esi_entry_year_lvl_nbr
		  ELSE NULL END

-- Create enrolled table correcting for cases where year levels have been reported successively

DROP TABLE IF EXISTS #enrolled;

WITH enrolled_pop AS(
    SELECT DISTINCT snz_uid
        , quarter
        , year_level
        , 1 AS enrolled
    FROM #school_enrol_years
    GROUP BY snz_uid
        , quarter
        , year_level
)
    , 
 multiple_years AS(
    SELECT snz_uid
        , quarter
        , COUNT(snz_uid) AS cnt
    FROM enrolled_pop
    GROUP BY snz_uid
        , quarter
)

SELECT DISTINCT a.quarter
    , b.snz_uid
    , IIF(b.cnt > 1, NULL,a.year_level) AS year_level
    , 1 AS enrolled
INTO #enrolled
FROM enrolled_pop a
LEFT JOIN multiple_years b
ON a.snz_uid = b.snz_uid
AND a.quarter = b.quarter


-- Add to master table

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS school_enrol
    , COLUMN IF EXISTS AGE_primary
    , COLUMN IF EXISTS AGE_secondary;

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD school_enrol int
    , AGE_primary int
    , AGE_secondary int;
GO


UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET school_enrol = CASE WHEN [IDI_Sandpit].[DL-$(project)].[$(newmaster)].AGE BETWEEN 5 AND 18 AND enrolled = 1 THEN 1 ELSE NULL END
    , 
 AGE_primary = CASE WHEN year_level BETWEEN 1 AND 8 AND enrolled = 1 AND AGE BETWEEN 5 AND 13 THEN 1 
						WHEN year_level NOT BETWEEN 9 AND 15 AND AGE BETWEEN 5 AND 12 AND enrolled = 1 THEN 1 
						ELSE NULL END
    , 
 AGE_secondary = CASE WHEN year_level BETWEEN 9 AND 15 AND enrolled = 1 AND AGE BETWEEN 12 AND 18 THEN 1 
						WHEN year_level NOT BETWEEN 1 AND 8 AND AGE BETWEEN 13 AND 18 AND enrolled = 1 THEN 1 
						ELSE NULL END
FROM #enrolled rr
WHERE [IDI_Sandpit].[DL-$(project)].[$(newmaster)].snz_uid = rr.snz_uid
AND [IDI_Sandpit].[DL-$(project)].[$(newmaster)].quarter = rr.quarter;



ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS school_enrol__compulsory;
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD school_enrol__compulsory int;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET school_enrol__compulsory = CASE WHEN AGE BETWEEN 6 AND 15 AND school_enrol = 1 THEN 1 ELSE NULL END

FROM #enrolled rr
WHERE [IDI_Sandpit].[DL-$(project)].[$(newmaster)].snz_uid = rr.snz_uid
AND [IDI_Sandpit].[DL-$(project)].[$(newmaster)].quarter = rr.quarter

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS school_enrol_compulsory;
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD school_enrol_compulsory int;

-- The following is for use later during the summarisation process --

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS AGE_prim_sec;
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD AGE_prim_sec int;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET AGE_prim_sec = CASE WHEN AGE_primary = 1 THEN 1
						WHEN AGE_secondary = 1 THEN 2
						ELSE NULL END 

FROM [IDI_Sandpit].[DL-$(project)].[$(newmaster)]


/* Entity counts */

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project)].[school_enrol_ENT];

SELECT DISTINCT [snz_uid]
    , [quarter]
    , CAST([entity_1] AS int) AS entity_1
INTO [IDI_Sandpit].[DL-$(project)].[school_enrol_ENT]
FROM #school_enrol_years

--Index and compress to save space--

CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-$(project)
].[school_enrol_ENT](
    [snz_uid]
        , [quarter]
);
 ALTER TABLE  [IDI_Sandpit].[DL-$(project)].[school_enrol_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)

 ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


