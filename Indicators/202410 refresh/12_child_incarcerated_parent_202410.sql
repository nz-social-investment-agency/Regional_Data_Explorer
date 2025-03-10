                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       /**************************************************************************************************
Title: Child with parent in corrections
Author: Ashleigh Arendt
Peer review:

Inputs & Dependencies:
- [IDI_Clean_{refresh}].[cor_clean].[ra_ofndr_major_mgmt_period_a]
- [IDI_Clean_{refresh}.[data].[personal_detail]

Outputs:
- Update to [master_table_202410]

Description: 
Identifies children with parents who have had any interaction with corrections in the past 12 months, and the subset of which whose parents were incarcerated (in prison or in remand)

Intended purpose:
There's evidence to suggest children with a parent in prison experience a wide range of negative impacts, including long-term poor health, educational and social outcomes and are at high risk of future improsonment themselves.

Notes:
1) Relies on the parents being identified in the personal_details table. For a given quarter, about 15% of people aged 0-24 do not have parents identified, 10% of ages 0-14.
This statistic may well be higher for the corrections population as they have interacted with the system. 
2) We compare the number of parents identified and extrapolate to the prison population assuming the % of parents is 66% (using 2015 report by superu - Improving outcomes for children with a parent in prison) and align closely with corrections figures

Parameters & Present values:
  Current refresh = 202410
  Prefix = _
  Project schema = [DL-MAA2023-55]
  Earliest start date = '01-1919' Consistent records appear at this date

Issues:

 Runtime (before joinng to master) - 00:00:46 
 Runtime (joining to master) - 

History (reverse order):
2024-04-19 - AA, adapted from CW code

**************************************************************************************************/


/* Process to identify children with incarcerated parents
-- 1. Limit corrections data to min max spells
-- 2. Get parent-child links for those in corrections
-- 3. Flag where for a given quarter the parent was in corrections

*/



/* 1. CORRECTIONS DATA */
-- Limit the time window and keep anyone who
DROP TABLE IF EXISTS #corrections;

SELECT [snz_uid]
    , [cor_rommp_directive_type]
    , [cor_rommp_period_start_date]
    , [cor_rommp_period_end_date]
INTO #corrections
FROM [IDI_Clean_202410].[cor_clean].ra_ofndr_major_mgmt_period_a
WHERE cor_rommp_period_start_date <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
)
AND cor_rommp_period_end_date >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))
AND [cor_rommp_directive_type] NOT IN ('ALIVE'); --alive is used to show periods not managed by corrections

/* 2. PARENT CHILD LINKS */
-- Get parent child list for all of the people in corrections
-- less than half have parents identified in the personal details table

DROP TABLE IF EXISTS #child_parents;

SELECT b.snz_uid AS child_snz_uid
    , snz_parent1_uid AS parent_snz_uid
INTO #child_parents
FROM #corrections a
INNER JOIN [IDI_Clean_202410].[data].[personal_detail] b
ON a.snz_uid = b.snz_parent1_uid
WHERE snz_parent1_uid IS NOT NULL

UNION 

SELECT b.snz_uid AS child_snz_uid
    , snz_parent2_uid AS parent_snz_uid
FROM #corrections a
INNER JOIN [IDI_Clean_202410].[data].[personal_detail] b
ON a.snz_uid = b.snz_parent2_uid
WHERE snz_parent2_uid IS NOT NULL
AND snz_parent1_uid <> snz_parent2_uid; -- parents are different


/* 3. CREATE FLAG FOR CORRECTION IN GIVEN TIME WINDOW */

-- List of children - might blow up if you have multiple parents so need to do group by afterwards, only selecting cases where children are identified
DROP TABLE IF EXISTS #corr_with_kids;

SELECT *
INTO #corr_with_kids
FROM #corrections c
INNER JOIN #child_parents cp
ON c.snz_uid = cp.parent_snz_uid

-- Join on quarters
DROP TABLE IF EXISTS #children_quarters;

SELECT [quarter]
    , [child_snz_uid]
    , MAX(correction_flag) AS corr_flg
    , MAX(incarcerated_flag) AS inc_flg
INTO #children_quarters
FROM(
    SELECT *
        , 1 AS correction_flag
        , CASE WHEN cor_rommp_directive_type IN ('imprisonment', 'remand') THEN 1 ELSE 0 END AS incarcerated_flag
    FROM #corr_with_kids c
    INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] qt
    ON c.[cor_rommp_period_start_date] <= qt.enddate
    AND c.[cor_rommp_period_end_date] >= DATEADD(YEAR, -1, qt.enddate) -- parent corrections spell occurred at some point within a year from end of quarter
)k
GROUP BY [quarter]
    , [child_snz_uid]


/* Join to master table */

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS cp_corr_any
    , COLUMN IF EXISTS cp_corr_inc;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD cp_corr_any int
    , cp_corr_inc int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET
 cp_corr_any = CASE WHEN cp.corr_flg = 1 AND AGE_RDP IN (1,2,3) THEN 1 ELSE NULL END
    , cp_corr_inc = CASE WHEN cp.inc_flg = 1 AND AGE_RDP IN (1,2,3)  THEN 1 ELSE NULL END

FROM #children_quarters cp
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = cp.child_snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = cp.[quarter]

--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
