/**************************************************************************************************
Title: Attending school and employed
Author: Ashleigh Arendt
Peer Review: Wian Lusse

Inputs & Dependencies:
Employment:
- [IDI_Clean_$refresh$].[ir_clean].[ird_ems]
School Enroll:
- [IDI_Clean_$refresh$].[moe_clean].[student_enrol]
Chronic Absence:
- [IDI_Community].[cm_read_MOE_SCH_ATT_TERM].[moe_sch_att_term]
Extras:
-[IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_school_term_dates]

For RDP project relies on the school_enroll population to have been identified using the student_enrol indicator (see code).

Outputs:
Join to master table.

Description:
Population of children enrolled in school who are working during term time. Employment is indicated by the presence of wages and salaries (income > $0) in the ird_ems tables.
Data is matched on a term basis, and terms are assigned to the quarters than contain most of the constituent days.
Monthy IRD returns are only matched to students when the reference month falls entirely within the dates for a term, e.g. if a term falls between 2nd May and 8th July then only the June month 
will be included, or for between 31st January and 14th April both February and March ems records will be included.

Intended purpose
Attending school is likely to lead to qualifications and ability to earn higher salaries, being absent can be a signal of deeper issues

Notes:
- Regular employment data goes up to end of August 2023
for the Oct 2023 refresh, some dates are in future (thought to be potentially contracted pieces of work) 
- The latest data that contains pbn or ent numbers is the data from May 2023, therefore the 2023Q2 quarter is at risk of more suppression than other months
- Latest data on school attendance is April 2023 so 2023Q2 not included for those calculations
- There are 3 different entity counts to consider: education provider, PBN and enterprise number - this leads to a fair amount of suppression due to entity counts
	- note for the entities for this indicator there are cases where PBN and ENT numbers are null, but we wish to include the school counts, so when performing suppression check ensure that if count = 0 then this is also excluded
- Because we restrictIRD data to ensure a IRD return falls completely in a term period, and the length of terms differ, some quarters will be based on 2 months of IRD data, whilst others will only be based on one, this may introduce some data bias 

Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-55]


Issues:
- IRD data is captured monthly, so if someone stops attending school and starts working on separate weeks within the same month, we cannot distinguish this from them working on the same days or weeks that they attend school
- Terms do not align perfectly to quarters, depending on the year there are can be some overlap of terms into other quarters.

History (reverse order):
2024-05-03 AA
**************************************************************************************************/


/* Create term date - quarter overlap to assign terms to quarters */
USE IDI_UserCode
GO
 IF OBJECT_ID('[DL-MAA2023-55].[quarters_terms]','V') IS NOT NULL
DROP
VIEW [DL-MAA2023-55].[quarters_terms];
GO

CREATE
VIEW [DL-MAA2023-55].[quarters_terms] AS(
    SELECT t.YEAR
        , t.term
        , t.start_date AS term_start_date
        , t.end_date AS term_end_date
        , qt.startdate AS qt_start_date
        , qt.enddate AS qt_end_date
        , qt.quarter
    FROM [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_school_term_dates] t
    INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] qt
    ON t.start_date >= qt.startdate
    AND t.start_date <= qt.enddate
); -- terms over the current time period always start within the quarter we want to assign them to
GO

/* Get employed population (over term dates) */
-- Want this to follow term dates, currently return periods are only given at the end of the month
-- As such we only include return periods where the whole month is contained within a term

DROP TABLE IF EXISTS #employment_terms;
SELECT DISTINCT ir.[snz_uid]
    , qt.[quarter]
    , qt.[term]
    , ir.[ir_ems_enterprise_nbr] -- ent number
    , ir.[ir_ems_pbn_nbr] --pbn number
INTO #employment_terms
FROM [IDI_Clean_202410].[ir_clean].[ird_ems] ir
INNER JOIN [IDI_Usercode].[DL-MAA2023-55].[quarters_terms] qt
ON qt.term_start_date <= DATEFROMPARTS(YEAR(ir.ir_ems_return_period_date), MONTH(ir.ir_ems_return_period_date), 1) -- the first day of the month for the return date is after the start date for the term
AND qt.term_end_date >= ir.ir_ems_return_period_date -- the return date is after the end date so that the whole tax return period is within the term
WHERE ir.[ir_ems_gross_earnings_amt] > 0 -- ensure there are some earnings
AND ir.[ir_ems_income_source_code] IN ('W&S') -- only take wages & salary earnings
AND ir.[ir_ems_snz_unique_nbr] = 1 -- Only take one return for that month 
AND ir.[snz_ird_uid] > 0 -- remove spurious results
AND ir.[ir_ems_return_period_date] >= (
    SELECT MIN(startdate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
)
AND ir.[ir_ems_return_period_date] <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
)
GO

/* Join employed population to students who are enrolled in school for each quarter */
-- Flag for each person for each quarter whether they show up in the employment tables, only keeping those that do

DROP TABLE IF EXISTS #combined_table;

SELECT DISTINCT a.snz_uid
    , a.quarter
    , 1 AS student_employed
INTO #combined_table
FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] a
INNER JOIN #employment_terms b
ON a.snz_uid = b.snz_uid
AND a.quarter = b.quarter
WHERE a.POPULATION = 1
AND school_enrol = 1; --enrolled in school (from school_enroll script)

/* Chronic Absence */
-- Uses the code modules to identify students who had chronic absence during the term 

DROP TABLE IF EXISTS #chronically_absent;
SELECT a.*
    , b.quarter
    , 1 AS chronic_absence
INTO #chronically_absent
FROM [IDI_Sandpit].[DL-MAA2023-55].[school_attendance_term] a -- dataset from code modules output (should be replaced with the latest refresh when available ()
INNER JOIN [DL-MAA2023-55].[quarters_terms] b
ON a.YEAR = b.YEAR
AND a.term = b.term
WHERE attendance = 'Chronic Absence';

DROP TABLE IF EXISTS #employed_student_full;
SELECT a.*
    , chronic_absence
INTO #employed_student_full
FROM #combined_table a
LEFT JOIN #chronically_absent b
ON a.snz_uid = b.snz_uid
AND a.quarter = b.quarter;



/* Join to master table */

-- Working and chronic absence
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS working_student
    , COLUMN IF EXISTS working_student__ca;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD working_student int
    , working_student__ca int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET
 working_student = CASE WHEN e.student_employed = 1 AND school_enrol = 1 THEN 1 ELSE NULL END
    , working_student__ca = CASE WHEN e.chronic_absence = 1 AND school_enrol = 1 THEN 1 ELSE NULL END

FROM #employed_student_full e
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = e.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = e.[quarter]


-- Chronic absence (for base population if desired)
--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] DROP COLUMN IF EXISTS school_enrol__ca;
--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] ADD school_enrol__ca int;
--GO

--UPDATE
--	[IDI_Sandpit].[DL-MAA2023-55].[master_table]
--SET

--	school_enroll__ca = CASE WHEN ca.chronic_absence = 1 AND school_enrol = 1 THEN 1 ELSE null END

--FROM #chronically_absent ca
--	WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table].snz_uid = ca.snz_uid
--	AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].[quarter] = ca.[quarter] 

/* Create entity tables */

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[working_student_ENT];

SELECT s.snz_uid
    , s.quarter
    , s.entity_1 --take the education provider as the first entity
    , ABS(CAST(HashBytes('MD5', t.[ir_ems_enterprise_nbr]) AS int)) AS entity_2 --take the enterprise number as the second entity (convert to int)
    , ABS(CAST(HashBytes('MD5', t.[ir_ems_pbn_nbr]) AS int)) AS entity_3 --take the pbn number as the third entity (convert to int)

INTO [IDI_Sandpit].[DL-MAA2023-55].[working_student_ENT]
FROM [IDI_Sandpit].[DL-MAA2023-55].[school_enroll_ENT] s
INNER JOIN #employment_terms t
ON t.snz_uid = s.snz_uid
AND t.quarter = s.quarter
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[working_student_ENT] ([snz_uid], [quarter])
; ALTER TABLE  [IDI_Sandpit].[DL-MAA2023-55].[working_student_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)

/* Clear tables */

DROP TABLE IF EXISTS #employment_terms;
DROP TABLE IF EXISTS #combined_table;
DROP TABLE IF EXISTS #chronically_absent;
DROP TABLE IF EXISTS #employed_student_full;

