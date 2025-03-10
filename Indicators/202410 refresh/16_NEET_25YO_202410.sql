/**************************************************************************************************
Title: NEET
Author: Charlotte Rose (adapted from Dan Young's sql convertion of the OT NEET indicator)
Peer review: 

Inputs & Dependencies:
	- IDI_Sandpit.[DL-MAA2023-55].[master_table_202410] (population definition)
	- [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
	- IDI_Clean_202410.[data].[person_overseas_spell]
	- IDI_Clean_202410.[ir_clean].[ird_ems]
	- IDI_Clean_202410.[cor_clean].[ra_ofndr_major_mgmt_period_a]
	- [IDI_Clean_202410].[moe_clean].[student_enrol] 
	- [IDI_Clean_202410].[moe_clean].[enrolment]
	- [IDI_Clean_202410].[moe_clean].[tec_it_learner]
	- [IDI_Clean_202403].[acc_clean].[claims]


Outputs:
- Update to [master_table_202410]

Description:
Indication of whether a person has had a NEET period of over 30 days in the previous 12 months in the year in which they turned 25
	NEET defined as:
	Not in employment (including withholding payment (contractors) and paid parental leave)
	Not in education (school or tertiary)
	Not overseas
	Not in prison
	Not deemed unfit for work by either MSD or ACC

Intended purpose:
Understand the number of people aged 25 who are NEET. Young people are usually more severely affected by economic crises than other age groups. 
Research suggests this group is the first to lose their jobs and last to gain employment. This may incur lasting costs to the economy, society, the individual and their families.

Notes:
1) DY: 'Currently this does not build tables for entity counts. When I submitted this, I submitted without entity counts and included the below explanation:
	"	Entity counts have not been provided for this, on the basis that:
		- this reflects periods where a person is not enrolled in education, nor employed, nor overseas, nor in prison. It's not clear how to apply the output rules to this (or whether they can sensibly be applied)
		- this is being measured across a year, and across a large geographic area, so it is very extremely unlikely that anything could be inferred about individuals.	"

The conceptual difficulty seems to me to be that if you are NEET, bar a short period of employment, it is unlikely that the employer has any way of knowing anything, other than that you were not NEET during
the employment. On the other hand, with more granular groups, this might break down. Be careful!

The practical difficulty is that we are likely to deal with lots of different, overlapping, spells which we condense into single blocks of time. If we want to track entities, the way around this
might be to add entities into the first table, and keep the snz_uids, entities, and start/ends, and construct counts for periods of interest using this. It could be difficult to reconcile this though:
for example, whether we could combine businesses AND education providers (rules seem to say "no"), so may need multiple tables for this - and whether this leads to a sensible result.'


Parameters & Present values:
  Current refresh = 202410
  Prefix = _
  Project schema = [DL-MAA2023-55]
  Earliest start date = 2019

Issues: 
- Employment data rarely has a start_date, so usually we impute the start date as the start of the month for the return period, therefore the most granular employment data is monthly
- Main difference to OT's code is the imputation of withdrawal dates from tertiary enrolment

 Runtime (before joinng to master) - 00:03:49
 Runtime (joining to master) - 

History (reverse order):
2024-11-04 CR added clause to 'EET' for those on sickness and disability benefits - i.e incapcaitated and deemed unfit for work
2023-05-20 CR - adapted DY OT_NEET code

***/


-- NEET Def starts here
/*********************************************
			NEET
*********************************************/


DROP TABLE IF EXISTS #input_pop;

SELECT a.snz_uid
    , a.dob
    , MAX(enddate) AS end_date
    , MIN(startdate) AS start_date
INTO #input_pop
FROM(
    SELECT *
    FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
    WHERE Age = 25
    AND POPULATION = 1
)a
GROUP BY a.snz_uid
    , a.dob;

/* create a table of everything that counts as Education, employment and training 
(as well as other periods we don't expect data like overseas spells and corrections) */

/* overseas spells */

DROP TABLE IF EXISTS IDI_Sandpit.[DL-MAA2023-55].EET_draft_25;
SELECT a.snz_uid
    , CAST(a.pos_applied_date AS date) AS [start_date]
    , CASE WHEN a.pos_ceased_date IS NULL THEN '9999-12-31' ELSE CAST(a.pos_ceased_date AS date) END AS [end_date] --giving nulls (current spells) a max end date
    , 'overseas' AS status
INTO IDI_Sandpit.[DL-MAA2023-55].EET_draft_25
FROM IDI_Clean_202410.[data].person_overseas_spell a
JOIN #input_pop b
ON a.snz_uid = b.snz_uid
WHERE CAST(a.pos_applied_date AS date) <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
) -- keeping to RDP quarters
AND CASE WHEN a.pos_ceased_date IS NULL THEN '9999-12-31' ELSE CAST(a.pos_ceased_date AS date) END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))

-- (so if we're looking a year before the earliest date to define NEET then maybe restrict to this - anyone who is overseas for longer shouldn't be in our res pop (I think))

UNION

/* school enrolments */ --probably none for 25/yo

SELECT a.snz_uid
    , a.moe_esi_start_date AS [start_date]
    , a.moe_esi_end_date AS [end_date]
    , 'education' AS status
FROM(
    SELECT a.snz_uid
        , a.moe_esi_start_date
        , CASE WHEN a.moe_esi_end_date IS NULL THEN '9999-12-31' ELSE a.moe_esi_end_date END AS moe_esi_end_date --giving nulls (current spells) a max end date
    FROM [IDI_Clean_202410].[moe_clean].[student_enrol] a
    WHERE a.moe_esi_start_date <= (
        SELECT MAX(enddate)
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    ) -- keeping to RDP quarters, interested in up to a year before earliest date
    AND CASE WHEN a.moe_esi_end_date IS NULL THEN '9999-12-31' ELSE a.moe_esi_end_date END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))
    AND DATEDIFF(DAY, moe_esi_start_date,  CASE WHEN a.moe_esi_end_date IS NULL THEN '9999-12-31' ELSE a.moe_esi_end_date END) ! = 1
)a --excluding one day enrolments
JOIN #input_pop b
ON a.snz_uid = b.snz_uid

UNION

/* tertiary enrolments */

SELECT a.snz_uid
    , a.[start_date]
    , a.[end_date]
    , 'education' AS status
FROM 
(
    SELECT DISTINCT enr.snz_uid
        , CAST([moe_enr_provider_code] AS int) AS provider_code
        , 'tertiary' AS [source]
        , [moe_enr_prog_start_date] AS [start_date] -- [moe_enr_prog_start_date] has no NULLs
        , CASE WHEN [moe_crs_withdrawal_date] IS NOT NULL AND [moe_crs_withdrawal_date] < [moe_enr_prog_end_date] THEN [moe_crs_withdrawal_date] ELSE [moe_enr_prog_end_date] END AS [end_date] -- [moe_enr_prog_end_date] has no NULLs
        , 1 AS tertiary_study_any -- this will include those with NULL as study_type_code (meaning 'non applicable (non type D courses)') who are not included elsewhere
    FROM [IDI_Clean_202410].[moe_clean].[enrolment] enr
    LEFT JOIN [IDI_Clean_202410].[moe_clean].[course] crs
    ON enr.snz_uid = crs.snz_uid
    AND enr.[moe_enr_snz_unique_nbr] = crs.[moe_crs_snz_unique_nbr]
    AND enr.[moe_enr_prog_start_date] = crs.[moe_crs_start_date]
    WHERE moe_enr_qual_type_code = 'D' -- include formal education of more than 1 week duration and .03 EFTS
    AND [moe_enr_prog_start_date] <= (
        SELECT MAX(enddate)
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    ) -- keeping to RDP quarters
    AND CASE WHEN [moe_crs_withdrawal_date] IS NOT NULL AND [moe_crs_withdrawal_date] < [moe_enr_prog_end_date] THEN [moe_crs_withdrawal_date] ELSE [moe_enr_prog_end_date] END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))

    UNION

/*Enrolment in industry training*/

    SELECT DISTINCT b.[snz_uid]
        , b.[provider_code]
        , b.[source]
        , b.[start_date]
        , ISNULL(b.end_date, DATEFROMPARTS(b.[final_year], 12, 31)) AS end_date --where end_date is NULL, impute the end date as the last day of the final year of recorded participation
        , b.[tertiary_study_any]

    FROM(
        SELECT [snz_uid]
            , CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
            , 'tec_it_learner' AS [source]
            , [moe_itl_start_date] AS [start_date] -- [moe_itl_start_date] has no NULLs
            , MAX(moe_itl_year_nbr) OVER (PARTITION BY SNZ_UID, MOE_ITL_EDUMIS_2016_CODE) AS final_year --imputing
            , [moe_itl_end_date] AS [end_date]
            , 1 AS tertiary_study_any
        FROM [IDI_Clean_202410].[moe_clean].[tec_it_learner]
        WHERE [moe_credit_value_nbr] >= 4 -- approximateing 120 credits (for full time) times .03 as a minimum threshold
        AND [moe_itl_start_date] <= (
            SELECT MAX(enddate)
            FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
        ) -- keeping to RDP quarters
        AND [moe_itl_year_nbr] >= (
            SELECT MIN(YEAR(DATEDIFF(YEAR, -1, startdate)))
            FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
        ) -- minus a year from the start date
        GROUP BY [snz_uid]
            , [moe_itl_ito_edumis_id_code]
            , [moe_itl_start_date]
            , [moe_itl_end_date]
            , [MOE_ITL_EDUMIS_2016_CODE]
            , [moe_itl_year_nbr]
    )b
)a

JOIN #input_pop b
ON a.snz_uid = b.snz_uid

UNION

/* employment */ -- inlcuding WHP and PPL which we will inlcude in definition, ideally would use employment spells however this would not include WHP and PPL

SELECT a.snz_uid
    , CASE WHEN ir_ems_employee_start_date IS NOT NULL 
			AND ir_ems_employee_start_date<ir_ems_return_period_date
			AND DATEDIFF(DAY,ir_ems_employee_start_date,ir_ems_return_period_date)<60 
			THEN ir_ems_employee_start_date  
		ELSE DATEADD(DAY, -1, DATEFROMPARTS(YEAR(ir_ems_return_period_date),MONTH(ir_ems_return_period_date),1)) END AS [start_date] --trial making this the end of month before 
    , ir_ems_return_period_date AS [end_date]
    , 'employment' AS [status]
FROM [IDI_Clean_202410].[ir_clean].[ird_ems] a
JOIN #input_pop b
ON a.snz_uid = b.snz_uid
WHERE ir_ems_income_source_code IN ('W&S','WHP','PPL')
AND CASE WHEN ir_ems_employee_start_date IS NOT NULL 
			AND ir_ems_employee_start_date < ir_ems_return_period_date
			AND DATEDIFF(DAY,ir_ems_employee_start_date,ir_ems_return_period_date)<60 
			THEN ir_ems_employee_start_date  
		ELSE DATEADD(DAY, -1, DATEFROMPARTS(YEAR(ir_ems_return_period_date),MONTH(ir_ems_return_period_date),1)) END <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
) -- these aren't spells so actually we just want all of the return periods in the range of interest
AND CASE WHEN ir_ems_employee_start_date IS NOT NULL 
			AND ir_ems_employee_start_date < ir_ems_return_period_date
			AND DATEDIFF(DAY,ir_ems_employee_start_date,ir_ems_return_period_date)<60 
			THEN ir_ems_employee_start_date  
		ELSE DATEADD(DAY, -1, DATEFROMPARTS(YEAR(ir_ems_return_period_date),MONTH(ir_ems_return_period_date),1)) END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters])) -- these aren't spells so actually we just want all of the return periods in the range of interest

UNION

/* corrections */

SELECT a.snz_uid
    , CAST(a.cor_rommp_period_start_date AS date) AS [start_date]
    , CASE WHEN a.cor_rommp_period_end_date IS NULL THEN '9999-12-31' ELSE CAST(a.cor_rommp_period_end_date AS date) END AS [end_date] -- never nulls but in case this changes
    , 'corrections' AS [status]
FROM IDI_Clean_202410.[cor_clean].ra_ofndr_major_mgmt_period_a a
JOIN #input_pop b
ON a.snz_uid = b.snz_uid
WHERE a.cor_rommp_directive_type NOT IN ('AGED_OUT','ALIVE','ERROR','NA')
AND a.cor_rommp_period_start_date < a.cor_rommp_period_end_date
AND a.cor_rommp_period_start_date <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
) -- keeping to RDP quarters
AND CASE WHEN a.cor_rommp_period_end_date IS NULL THEN '9999-12-31' ELSE a.cor_rommp_period_end_date END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))

UNION 


--/* Off work on ACC */

SELECT a.[snz_uid]
    , a.[acc_cla_first_wc_payment_date]
    , CASE WHEN a.[acc_cla_last_wc_payment_date]  IS NULL THEN '9999-12-31' ELSE a.[acc_cla_last_wc_payment_date] END AS [end_date] -- never nulls but in case this changes
    , 'ACC' AS [status]
FROM [IDI_Clean_202410].[acc_clean].[claims] a
JOIN #input_pop b
ON a.snz_uid = b.snz_uid
WHERE a.[acc_cla_first_wc_payment_date] IS NOT NULL
AND a.[acc_cla_first_wc_payment_date] <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
) -- keeping to RDP quarters
AND CASE WHEN a.[acc_cla_last_wc_payment_date] IS NULL THEN '9999-12-31' ELSE a.[acc_cla_last_wc_payment_date] END >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))

UNION

--/*Incapacitatied as per MSD benefit receipt OR caring for someone who is incapacitatied*/

SELECT i.[snz_uid]
    , i.period_start_date AS [start_date]
    , IIF(i.period_end_date IS NULL, '9999-12-31',i.period_end_date) AS end_date
    , 'Incapcitated' AS [status]
FROM [IDI_Community].[cm_read_INCOME_T1_INC_SUPPORT_PAYMT].[income_t1_inc_support_paymt_202410] i
INNER JOIN #input_pop b
ON i.snz_uid = b.snz_uid
WHERE i.income_source_type = 'Main benefit'
AND i.income_source IN ('Supported Living Payment Health Condition & Disability','Supported Living Payment')
AND i.period_start_date <= (
    SELECT MAX(enddate)
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
) -- keeping to RDP quarters
AND IIF(i.period_end_date IS NULL, '9999-12-31',i.period_end_date) >= DATEADD(YEAR, -1, (SELECT MIN(startdate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]))


/* add a period before 15 as we don't count that as NEET*/
UNION

SELECT DISTINCT snz_uid
    , '1900-01-01' /* could use birth day but this way washes out incorrect entries from other tables prior to birth */ AS [start_date]
    , DATEFROMPARTS(YEAR(dob)+15,MONTH(dob),1) AS [end_date]
	--, CASE WHEN DATEFROMPARTS(YEAR(dob)+15,month(dob),1) > start_date THEN DATEFROMPARTS(YEAR(dob)+15,month(dob),1) --takes either the date they entered the country or the date they were born
	--	ELSE start_date END AS [end_date]
    , 'childhood' AS status
FROM #input_pop

UNION

/* add the current date, this just bookends the code to make sure peiords of NEET that are still open are captured*/

SELECT snz_uid
    , end_date AS [start_date]
    , DATEADD(DAY, 1, end_date) AS [end_date]
    , 'bookend' AS status
FROM #input_pop


--DY: the next three steps combine individual spells into combined periods where a person was EET.

-- As a more technical description...
-- (1) For each period and person, we order the rows by date;
-- (2) We create two new columns used to link continuous or overlapping periods of EET-ness (linked_start and linked_end). 
--		If I understand correctly, these are basically temporary variables and their current value is used to set the 
--		value for that row in the data. We can apply logic to update these variables as we go.
--		(nb. the value given to the current row is the value AFTER any updates from the logic)
-- (3) For each row we update the two columns as follows :
--		(a) if it is the very first row we use the start_date and end_date to set these values; otherwise
--		(b) if the start_date is greater than the previous end_date/current linked_end_date, we have a new spell
--			and we reset the values to reflect the start_date and end date of this row; otherwise
--		(c) we know that the current row overlaps the current spell (as the start date falls within the spell). If the end 
--			date of the current row is greater than the linked_end_date, it must extend the current spell - in which case we 
--			update the linked_end_date to reflect the end_date of the current row. (Otherwise, the current row falls wholly 
--			within the current spell so we do not need to update anything).

-- The end result of this process is that each row is assigned to a spell with a common start date. Each row that is part of the 
-- spell can, however, have a different end date. (Can not must - it might be that someone coincidentally finishes two activities, say
-- employment and education, on the same day).

-- To resolve this, we group the data by reference period, person and spell start date, order by spell end date (latest last) and 
-- take the last row for each group.

--For each person (we don't have multiple periods) take the distinct from spells start dates and the distinct end dates 
--from spells, that do not fall within another spell. Join these together (where the end date > the start date).
--Group by start date and take the minimum end date.


--- EET_linked_25 RUN AT LOW DEMAND TIME --

DROP TABLE IF EXISTS IDI_Sandpit.[DL-MAA2023-55].EET_linked_25;
WITH start_dates AS(
    SELECT snz_uid
        , [start_date]
    FROM IDI_Sandpit.[DL-MAA2023-55].EET_draft_25 a
    WHERE NOT EXISTS(
        SELECT 1
        FROM IDI_Sandpit.[DL-MAA2023-55].EET_draft_25 b
        WHERE a.snz_uid = b.snz_uid
        AND a.[start_date] <= b.[end_date]
        AND a.[start_date] > b.[start_date] -- apply strict inequality otherwise rows will match to themselves
    )
)
    , end_dates AS(
    SELECT snz_uid
        , end_date
    FROM IDI_Sandpit.[DL-MAA2023-55].EET_draft_25 a
    WHERE NOT EXISTS(
        SELECT 1
        FROM IDI_Sandpit.[DL-MAA2023-55].EET_draft_25 b
        WHERE a.snz_uid = b.snz_uid
        AND a.[end_date] >= b.[start_date]
        AND a.[end_date] < b.[end_date] -- apply strict inequality otherwise rows will match to themselves
    )
)
SELECT a.snz_uid
    , a.[start_date] AS [linked_start]
    , MIN(b.[end_date]) AS [linked_end]
INTO IDI_Sandpit.[DL-MAA2023-55].EET_linked_25
FROM start_dates a
LEFT JOIN end_dates b
ON a.snz_uid = b.snz_uid
AND a.[start_date] <= b.end_date
GROUP BY a.snz_uid
    , a.[start_date]

/* Next we create NEET periods. This is basically the reverse of the above. We join our EET spells onto itself, based on 
reference period, snz_uid, and EET period end date being less than the EET period start date.
When an EET period ends, NEET status lasts until the start of the next EET period.
The end date is actually the day they are EET.

*/

DROP TABLE IF EXISTS #NEET_periods; -- sort qtr dates
SELECT a.snz_uid
    , a.linked_end AS NEET_start_date
    , MIN(b.linked_start) AS NEET_end_date --
    , DATEDIFF(DAY,a.linked_end,MIN(b.linked_start)) AS NEET_length -- called NEET length lifetime in OT, which is correctly calcuated at the next step. Call it what it is for now.
INTO #NEET_periods
FROM IDI_Sandpit.[DL-MAA2023-55].EET_linked_25 a
INNER JOIN IDI_Sandpit.[DL-MAA2023-55].EET_linked_25 b
ON a.snz_uid = b.snz_uid
AND a.linked_end < b.linked_start
GROUP BY a.snz_uid
    , a.linked_end



-- Get all of the neet spells within the last year - all of those that overlap with the year
DROP TABLE IF EXISTS #NEET_summary;
WITH neet_yr_summary AS(
    SELECT snz_uid
        , q.quarter
        , NEET_length
        , CASE WHEN n.NEET_start_date < DATEADD(YEAR,-1,q.enddate) THEN DATEADD(YEAR,-1,q.enddate) ELSE NEET_start_date END AS NEET_start_date_yr
        , CASE WHEN n.NEET_end_date > q.enddate THEN q.enddate ELSE NEET_end_date END AS NEET_end_date_yr
        , DATEDIFF(DAY, CASE WHEN n.NEET_start_date < DATEADD(YEAR,-1,q.enddate) THEN DATEADD(YEAR,-1,q.enddate) ELSE NEET_start_date END, 
	CASE WHEN n.NEET_end_date > q.enddate THEN q.enddate ELSE NEET_end_date END) AS NEET_length_yr
    FROM #NEET_periods n
    INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
    ON n.NEET_start_date <= q.enddate
    AND n.NEET_end_date > DATEADD(YEAR,-1,q.enddate)
)
    , 
 neet_qt_summary AS(
    SELECT snz_uid
        , q.quarter
        , DATEDIFF(DAY, CASE WHEN n.NEET_start_date < q.startdate THEN q.startdate ELSE NEET_start_date END 
	,CASE WHEN n.NEET_end_date > q.enddate THEN q.enddate ELSE NEET_end_date END) AS NEET_length_qt
    FROM #NEET_periods n
    INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
    ON n.NEET_start_date <= q.enddate
    AND n.NEET_end_date > q.startdate
)

SELECT a.*
    , b.NEET_length_qt
INTO #NEET_summary
FROM neet_yr_summary a
LEFT JOIN neet_qt_summary b
ON a.snz_uid = b.snz_uid
AND a.quarter = b.quarter

DROP TABLE IF EXISTS #NEET_summary_final;

SELECT n.snz_uid
    , n.quarter
    , SUM(n.NEET_length) AS total_NEET_length
    , SUM(n.NEET_length_yr) AS NEET_length_yr
    , CASE WHEN SUM(n.NEET_length_yr) >= 180 THEN 1 ELSE NULL END AS long_term_NEET -- 6 months
    , CASE WHEN SUM(n.NEET_length_yr) >= 30 THEN 1 ELSE NULL END AS short_term_NEET -- 1 month //not using//
    , CASE WHEN SUM(n.NEET_length_qt) >=30 THEN 1 ELSE NULL END AS NEET_qt -- 
INTO #NEET_summary_final
FROM #NEET_summary n
--INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q on n.quarter = q.quarter
GROUP BY n.snz_uid
    , n.quarter


------------------------------------------------- Add and update columns into Master Table

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS NEET_6mo_in_yr_25yr
    , COLUMN IF EXISTS NEET_1mo_in_qt_25yr;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD NEET_6mo_in_yr_25yr bit
    , NEET_1mo_in_qt_25yr bit;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET NEET_6mo_in_yr_25yr = neet.long_term_NEET
    ,  --only take the working age population for the employed indicator
 NEET_1mo_in_qt_25yr = neet.NEET_qt

FROM #NEET_summary_final neet
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = neet.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = neet.[quarter];

--CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ([snz_uid], [quarter])
--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS IDI_Sandpit.[DL-MAA2023-55].EET_linked_25;
DROP TABLE IF EXISTS IDI_Sandpit.[DL-MAA2023-55].EET_Draft_25;

