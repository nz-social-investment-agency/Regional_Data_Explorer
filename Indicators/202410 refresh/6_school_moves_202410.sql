
/**************************************************************************************************
Title: Number of school moves
Author: Charlotte Rose
Peer review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_$(refresh)].[moe_clean].[student_enrol]
- [IDI_Clean_$(refresh)].[moe_clean].[provider_profile]
- [IDI_Metadata_$(refresh)].[moe_school].[provider_type_code] 
- [IDI_Metadata_$(refresh)].[moe_school].[sch_region_code]

Outputs:
- Update to [$(newmaster)]

Description:
Finding the number of students who have had moree than two non-structural* school or kura moves more than twice in one school year. (MoE covers 1 March - 1 Nov as a 'year')

*Structural moves are a movement between schools or kura forced by the structure of the schooling system 
(e.g. a student moving between primary and intermediate, or intermediate and secondary school)

Intended purpose:
This indicator shows the number of students who have had more than two non-structural school moves in a year.

Research has found students who move schools OR kura regularly are more likely to underachieve in formal education compared 
with students with a more stable school life.

Notes:
1) 

Parameters & Present values:
  Current refresh = $(refresh)
  Prefix = _
  Project schema = [DL-$(project)]


Issues:
- OT have a similar indicator (WEL-31 dev-enrol) where they look at the prev 12mo, do not take into account primary to secondary as a structural move and do not filter 
  for moves between Mar & Nov. OTs figures are slightyly higher than MoE, however reporting periods dont match

- MoE look at moves within the calendar year, between 1 Mar and 1 Nov.

- Our code looks at previous 12 months, moves within the school year (Mar - Nov), and not structural 
(e.g. not primary to intermediate or secondary, intermediate to secondary, home school/ te kura etc to mainstream or vice versa)

- We get ~35% lower numbers to OT for Q2 2021, ~30% less than MoEs annual figures when matched to our population

- School enrol table extraction appears to be annual in August, therefore will only be updated in October refreshes. 
  Max enrolment dates (by complete quarter) for refreshes are below;
	202410 Q22024
	202406 Q22023
	202403 Q22023
	202310 Q22023
	202306 Q22022
	202303 Q22022


 Runtime (before joinng to master) - 00:10:58
 Runtime (joining to master) - 

History (reverse order):
2024-05-01 - AA small tweaks to remove Alt Ed duplicates
2024-03-18 - CR adapted code from AW Alt ed analysis

**************************************************************************************************/ 
/*PARAMETERS

SQLCMD only (Activate by clicking Query->SQLCMD Mode)*/

--Update with project and current refresh--

:setvar project "MAA20XX-XX" :setvar newmaster "Master_population_$(refresh)" :setvar refresh "$(refresh)"


DROP TABLE IF EXISTS #school_changes;

	-- all school spells

WITH schoolspells AS(
    SELECT DISTINCT e.snz_uid
        , e.snz_moe_uid
        , e.moe_esi_entry_year_lvl_nbr
        , e.moe_esi_provider_code
        , c.ProviderTypeId
        , c.ProviderTypeDescription AS [school_type]
        , e.moe_esi_start_date AS [date_started]
        , IIF(CAST(e.moe_esi_end_date AS date) IS NULL,GETDATE(),CAST(e.moe_esi_end_date AS Date)) AS [date_left] --imputing a dummy end date if still attending
        , e.moe_esi_extrtn_date AS [EXTRACT date]
    FROM [IDI_Clean_$(refresh)].[moe_clean].[student_enrol] e
    LEFT JOIN [IDI_Clean_$(refresh)].[moe_clean].[provider_profile] b
    ON e.moe_esi_provider_code = b.moe_pp_provider_code
    LEFT JOIN [IDI_Metadata_$(refresh)].[moe_school].[provider_type_code] c
    ON b.moe_pp_provider_type_code = c.ProviderTypeId
    WHERE e.moe_esi_end_date > (
        SELECT DATEADD(YEAR, -1, MIN(q.enddate))
        FROM [IDI_UserCode].[DL-$(project)].[mt_quarters] q
    )
    OR e.moe_esi_end_date IS NULL
)
    ,  -- keep into period of interest

 rank_schoolspells AS(
    SELECT *
        , ROW_NUMBER() OVER(PARTITION BY snz_uid ORDER BY date_started) AS [RANK]
    FROM schoolspells
)

	-- specify whether move was structural OR not.

SELECT a.*
    , IIF(a.moe_esi_provider_code!=b.moe_esi_provider_code,1,0) AS any_move
    , CASE WHEN  a.moe_esi_provider_code!=b.moe_esi_provider_code AND (
		(b.ProviderTypeId = 10024 AND a.ProviderTypeId IN (10023, 10025, 10032, 10029, 10030, 10033) AND a.moe_esi_entry_year_lvl_nbr>=7) 
			-- start school is Y1-6, next school is Y1-8/7-8/7-10/7-13/1-13/9-13, moving into Y7 OR above
		OR (b.ProviderTypeId = 10023 AND a.ProviderTypeId IN (10032, 10029, 10030, 10033) AND a.moe_esi_entry_year_lvl_nbr>=9)
			-- start school is Y1-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 OR above
		OR (b.ProviderTypeId = 10025 AND a.ProviderTypeId IN (10032, 10029, 10030, 10033) AND a.moe_esi_entry_year_lvl_nbr>=9)
			-- start school is Y7-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 OR above
		OR (b.ProviderTypeId = 10032 AND a.ProviderTypeId IN (10029, 10030, 10033) AND a.moe_esi_entry_year_lvl_nbr>=11)
			-- start school is Y7-10, next school is Y7-13/1-13/9-13, moving into Y11 OR above
		OR ((b.moe_esi_provider_code IN (972,498) OR a.ProviderTypeId=10026) AND a.ProviderTypeId IN (10024, 10023, 10025, 10032, 10029, 10030, 10033))
			-- start school is home school, te kura, OR special school, moving into any mainstream school
		OR (b.ProviderTypeId IN (10024, 10023, 10025, 10032, 10029, 10030, 10033) AND (a.moe_esi_provider_code IN (972,498) OR a.ProviderTypeId=10026))
			-- start school is a mainstream school, moving into home school, te kura, OR special school
		) THEN 1 ELSE 0 END AS structural_move
    , CASE WHEN (a.school_type = 'Alternative Education Provider' OR b.school_type = 'Alternative Education Provider' ) 
			AND DATEDIFF(DAY, a.date_started, b.date_started) < 7 THEN 1 -- next school is alt Ed provider AND they started a new associated school within week of starting alt ed
			WHEN (a.school_type = 'Teen Parent Unit' OR b.school_type = 'Teen Parent Unit' ) 
			AND DATEDIFF(DAY, a.date_started, b.date_started) < 7 THEN 1 -- next school is Teen Parent Unit AND they started a new associated school within week of joining TPU
			ELSE 0 END AS multipurpose_school
INTO #school_changes
FROM rank_schoolspells a
LEFT JOIN rank_schoolspells b
ON a.snz_uid = b.snz_uid
AND a.[RANK]-1 = b.[RANK]
ORDER BY a.snz_uid
    , a.[RANK]

-- all spells following non structural moves
DROP TABLE IF EXISTS #temp

SELECT s.snz_uid
    , s.moe_esi_provider_code
    , s.date_started
INTO #temp
FROM #school_changes s
WHERE s.structural_move <> 1 --not a stuctural move
AND s.multipurpose_school <> 1 --not teen parent OR alt ed duplicate
AND s.any_move = 1 --must not be their first school

-- Filter for children who have experienced at least 2 non-structural moves between the end date of the quarter AND a year prior
-- just select cases where a school was started in the past year, these are all now non structural moves so if a school was started it was a new move

DROP TABLE IF EXISTS #final;

SELECT a.quarter
    , a.snz_uid
    , 1 AS transience
INTO #final
FROM(
    SELECT s.snz_uid
        , q.quarter
        , COUNT(s.snz_uid) AS cnt -- count the number of new school moves within the period
    FROM #temp s
    INNER JOIN IDI_UserCode.[DL-$(project)].mt_quarters q
    ON s.date_started BETWEEN DATEADD(DAY, 1, DATEADD(YEAR,-1,q.enddate)) AND q.enddate
    GROUP BY q.quarter
        , s.snz_uid
)a
WHERE a.cnt >= 2



-- Add to master --
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS transient_student
    , COLUMN IF EXISTS transient_student__primary
    , COLUMN IF EXISTS transient_student__secondary;
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD transient_student int
    , transient_student__primary int
    , transient_student__secondary int;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET
 transient_student = CASE WHEN t.transience = 1 AND school_enrol = 1 THEN 1 ELSE NULL END
    , transient_student__primary = CASE WHEN t.transience = 1 AND AGE_primary = 1 THEN 1 ELSE NULL END
    , transient_student__secondary = CASE WHEN t.transience = 1 AND AGE_secondary = 1 THEN 1 ELSE NULL END

FROM #final t
WHERE [IDI_Sandpit].[DL-$(project)].[$(newmaster)].snz_uid = t.snz_uid
AND [IDI_Sandpit].[DL-$(project)].[$(newmaster)].[quarter] = t.[quarter]


/* Create entity tables */

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project)].[transient_student_ENT];

SELECT s.snz_uid
    , q.quarter
    , CAST(s.[moe_esi_provider_code] AS int) AS entity_1
INTO [IDI_Sandpit].[DL-$(project)].[transient_student_ENT]
FROM #temp s
INNER JOIN IDI_UserCode.[DL-$(project)].mt_quarters q
ON s.date_started BETWEEN DATEADD(DAY, 1, DATEADD(YEAR,-1,q.enddate)) AND q.enddate
INNER JOIN #final t
ON t.snz_uid = s.snz_uid
AND t.quarter = q.quarter

	--Index and compress to save space--

CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-$(project)].[transient_student_ENT] ([snz_uid], [quarter]);
ALTER TABLE  [IDI_Sandpit].[DL-$(project)].[transient_student_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


