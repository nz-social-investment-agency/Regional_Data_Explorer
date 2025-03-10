/***************************************************************************************
Title: Highest Qualification
Author: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Community].[cm_read_INCOME_T2_TOTAL_INCOME].[income_t2_total_income_{refresh}] 
Outputs:
- Income bands added to master table

Description:
Determine the total income for each individual in New Zealand.

Intended purpose:
Personal income can be an indicator of wellbeing, those living in poverty are more likely to have poorer wellbeing outcomes.

Notes:
- Most spells fall within the month and within the tax year.


Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:
- Some spells do not fit within the tax year (for the income support payments), so proportional income amounts are entered assuming a constant payment rate over the time period, this may be inaccurate

History (reverse order):
2024-11-05 AA
*/

/*Looking at the total annual income,  everyone over the age of 15. */

--This is a huge calculation, it might be better to just match on the whole time period and then split into spells - could be better efficiency
DROP TABLE IF EXISTS #last12mo;

SELECT a.snz_uid
    , q.quarter
    , q.startdate
    , q.enddate
    , period_start_date
    , period_end_date
    , income_source
    , gross_income
    , CASE WHEN a.period_start_date <= DATEADD(YEAR,-1, q.enddate) AND a.period_end_date >= q.enddate THEN gross_income * 365 / DATEDIFF(DAY, a.period_start_date, a.period_end_date) WHEN a.period_end_date > q.enddate THEN gross_income * DATEDIFF(DAY, period_start_date, q.enddate) / DATEDIFF(DAY, period_start_date, period_end_date) WHEN a.period_start_date <= DATEADD(YEAR, -1, q.enddate) THEN gross_income * DATEDIFF(DAY, DATEADD(YEAR, -1, q.enddate), period_end_date) / DATEDIFF(DAY, period_start_date, period_end_date) ELSE gross_income END AS proportional_income

INTO #last12mo
FROM [IDI_Community].[cm_read_INCOME_T2_TOTAL_INCOME].[income_t2_total_income_202410] a
INNER JOIN [IDI_Sandpit].[dl-MAA2023-55].[master_table_202410] mt
ON mt.snz_uid = a.snz_uid
INNER JOIN(
    SELECT
    TOP 1 *
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    ORDER BY enddate DESC
)q
ON period_start_date <= q.enddate
AND period_end_date > DATEADD(YEAR,-1, q.enddate) -- using all quarters is too large so just take the latest
WHERE mt.POPULATION = 1
AND mt.AGE_RDP >= 3 -- over the age of 15 only


-- for total income we only use that latest quarter, so maybe limit to this?
-- get total income by person by quarter --

DROP TABLE IF EXISTS #last12mogrpd;

SELECT snz_uid
    , quarter
    , SUM(proportional_income) AS income_total_12m
    , SUM(CASE WHEN income_source = 'Wages AND Salary' THEN proportional_income ELSE 0 END) AS income_was_12m --optional wages and salary income
INTO #last12mogrpd
FROM #last12mo
GROUP BY snz_uid
    , quarter

SELECT DISTINCT quarter
FROM #last12mogrpd

DROP TABLE IF EXISTS #last12mo;

------------------------------------------------- Add and update columns into Master Table-------------------------------------------------------------
--All ages 15+--
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS TotalIncome__under20k
    , COLUMN IF EXISTS TotalIncome__20to40k
    , COLUMN IF EXISTS TotalIncome__40to60k
    , COLUMN IF EXISTS TotalIncome__60to80k
    , COLUMN IF EXISTS TotalIncome__80to100k
    , COLUMN IF EXISTS TotalIncome__100to120k
    , COLUMN IF EXISTS TotalIncome__over120k;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD TotalIncome__under20k bit
    , TotalIncome__20to40k bit
    , TotalIncome__40to60k bit
    , TotalIncome__60to80k bit
    , TotalIncome__80to100k bit
    , TotalIncome__100to120k bit
    , TotalIncome__over120k bit ;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET TotalIncome__under20k = CASE WHEN ti.income_total_12m <=19999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__20to40k = CASE WHEN ti.income_total_12m BETWEEN 20000.00 AND 39999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__40to60k = CASE WHEN ti.income_total_12m  BETWEEN 40000.00 AND 59999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__60to80k = CASE WHEN ti.income_total_12m  BETWEEN 60000.00 AND 79999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__80to100k = CASE WHEN ti.income_total_12m  BETWEEN 80000.00 AND 99999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__100to120k = CASE WHEN ti.income_total_12m  BETWEEN 100000.00 AND 119999.99 AND AGE_RDP >=3 THEN 1 ELSE NULL END
    , TotalIncome__over120k = CASE WHEN ti.income_total_12m >=120000.00 AND AGE_RDP >=3 THEN 1 ELSE NULL END
FROM #last12mogrpd ti
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ti.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ti.quarter;


	--Turning 25--

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS TotalIncome25YO__under20k
    , COLUMN IF EXISTS TotalIncome25YO__20to40k
    , COLUMN IF EXISTS TotalIncome25YO__40to60k
    , COLUMN IF EXISTS TotalIncome25YO__60to80k
    , COLUMN IF EXISTS TotalIncome25YO__80to100k
    , COLUMN IF EXISTS TotalIncome25YO__100to120k
    , COLUMN IF EXISTS TotalIncome25YO__over120k;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD TotalIncome25YO__under20k bit
    , TotalIncome25YO__20to40k bit
    , TotalIncome25YO__40to60k bit
    , TotalIncome25YO__60to80k bit
    , TotalIncome25YO__80to100k bit
    , TotalIncome25YO__100to120k bit
    , TotalIncome25YO__over120k bit ;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET TotalIncome25YO__under20k = CASE WHEN ti.income_total_12m <=19999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__20to40k = CASE WHEN ti.income_total_12m BETWEEN 20000.00 AND 39999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__40to60k = CASE WHEN ti.income_total_12m  BETWEEN 40000.00 AND 59999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__60to80k = CASE WHEN ti.income_total_12m  BETWEEN 60000.00 AND 79999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__80to100k = CASE WHEN ti.income_total_12m  BETWEEN 80000.00 AND 99999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__100to120k = CASE WHEN ti.income_total_12m  BETWEEN 100000.00 AND 119999.99 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , TotalIncome25YO__over120k = CASE WHEN ti.income_total_12m >=120000.00 AND AGE_25YO = 1 THEN 1 ELSE NULL END
FROM #last12mogrpd ti
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ti.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ti.quarter;
