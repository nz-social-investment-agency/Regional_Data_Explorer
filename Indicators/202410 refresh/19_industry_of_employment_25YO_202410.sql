/**************************************************************************************************
Title: Industry of employment
Author: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean].[ir_clean].[ird_ems]
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[CEN_ANZSIC06]
Outputs:
- [IDI_UserCode].[DL-MAA2023-55].[defn_industry]

Description:
This builds on Simon Anastasiadis' script 'Industry of Employment' and joins the results to our master table.
It produces industry of employer based on the ANZSIC06 division code of the employer.
Requires people to be employees (have wages or salaries > 0)

Intended purpose:
Identify skills and skill shortages in a region, could help with planning if a lot of people work for an industry outside of the region and are reliant on roading to go to work.
Could be used in workforce planning and identifying areas that may casue shortages in the future, e.g. trades, health sector etc

Notes:
1) Industry as reported in monthly summary to IRD. Coded according to level 1
   of ANZSIC 2006 codes (19 different values).
2) There are two sources from which industry type can be drawn:
   PBN = Permanent Business Bumber
   ENT = The Entity
   We prioritise the PBN over the ENT.
3) Note that this is not identification of role/responsibilities due to lack of
   distinction between business industry and personal industry. For example the
   manager of a retirement home is likely to have ANZSIC code for personal care, not
   for management.
4) It appears that people are associated with a PBN based on the 
5) Latest complete qtr for 202410 refresh is 2024Q1


Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:

History (reverse order):
2024-02-22 - AA updated documentation for Regional Data Project
2023-08-01 - updated to make consistent with approach to D4C
2023-05-01 - automatic update to IDI_Clean_202410
2022-04-05 JG Updated project and refresh for Data for Communities
2020-05-20 SA v1
**************************************************************************************************/

/*  */


DROP TABLE IF EXISTS #industry_helper_25;
SELECT DISTINCT ir.[snz_uid]
    , mt.[quarter]
    , ABS(CAST(HashBytes('MD5', ir.[ir_ems_enterprise_nbr]) AS int)) AS [entity_1] -- need to turn into number not a string
    , ABS(CAST(HashBytes('MD5', ir.[ir_ems_pbn_nbr]) AS int)) AS [entity_2] -- need to turn into number not a string
    , LEFT(COALESCE(ir.[ir_ems_pbn_anzsic06_code], ir.[ir_ems_ent_anzsic06_code]), 1) AS anzsic06
    , CASE WHEN (LEFT(COALESCE(ir.[ir_ems_pbn_anzsic06_code], ir.[ir_ems_ent_anzsic06_code]), 1)) IN ('A', 'B') THEN 'Primary'
			WHEN (LEFT(COALESCE(ir.[ir_ems_pbn_anzsic06_code], ir.[ir_ems_ent_anzsic06_code]), 1)) IN ('C', 'D', 'E') THEN 'Goods-producing'
			WHEN (LEFT(COALESCE(ir.[ir_ems_pbn_anzsic06_code], ir.[ir_ems_ent_anzsic06_code]), 1)) IN ('F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S') THEN 'Services'
			ELSE 'Other'
			END AS Industry_broad
INTO #industry_helper_25
FROM [IDI_Clean_202410].[ir_clean].[ird_ems] ir
INNER JOIN(
    SELECT *
    FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
    WHERE AGE = 25
)mt
ON ir.snz_uid = mt.snz_uid
AND ir.ir_ems_return_period_date < DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, mt.dob) + 1, 0)))  -- return processed before the first day of the month following their 25th birthday
AND ir.ir_ems_return_period_date >= DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, mt.dob), 0))) -- play around with this window (could set 3 months before)
WHERE ir.snz_ird_uid > 0
AND ir.ir_ems_income_source_code = 'W&S'
AND ir.ir_ems_gross_earnings_amt > 0
AND ir.ir_ems_snz_unique_nbr = 1

GO
 CREATE CLUSTERED INDEX my_index_name ON #industry_helper_25 (snz_uid);
 ALTER TABLE #industry_helper_25 REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

DROP TABLE IF EXISTS #temp;
SELECT DISTINCT [snz_uid]
    , [quarter]
    , CASE MAX(CASE WHEN Industry_broad = 'Primary' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_primary
    , CASE MAX(CASE WHEN Industry_broad = 'Goods-producing' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_goods
    , CASE MAX(CASE WHEN Industry_broad = 'Services' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_services

INTO #temp
FROM #industry_helper_25 GROUP BY [snz_uid], [quarter]


-- Could further group from anzsic code to broader industries

ALTER TABLE #temp REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

 CREATE CLUSTERED INDEX my_index_name ON #temp (snz_uid);
GO

------------------------------------------------- Remove existing column (if any) from Master Table

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS industry_sql_25YO_primary
    , COLUMN IF EXISTS industry_sql_25YO_goods
    , COLUMN IF EXISTS industry_sql_25YO_services;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD industry_sql_25YO_primary bit
    , industry_sql_25YO_goods bit
    , industry_sql_25YO_services bit;


------------------------------------------------- Add and update columns into Master Table


UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET industry_sql_25YO_primary = CASE WHEN ir.industry_sql_primary = 1 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , industry_sql_25YO_goods = CASE WHEN ir.industry_sql_goods = 1 AND AGE_25YO = 1 THEN 1 ELSE NULL END
    , industry_sql_25YO_services = CASE WHEN ir.industry_sql_services = 1 AND AGE_25YO = 1 THEN 1 ELSE NULL END
FROM #temp ir
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ir.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ir.[quarter];


-- Compress table

--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


-- These entity count tables sometimes have multiple entries for an individual, for a quarter, so in this case take the one that gives the individual the highest earnings
-- might be better to partition over the industry, snz_uid and quarter to get the pbn and ent number from the highest paid job

/* Create entity counts tables */
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_primary_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [entity_1]
    , [entity_2]
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_primary_ENT]
FROM #industry_helper_25
WHERE Industry_broad = 'Primary' CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_primary_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_primary_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_goods_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [entity_1]
    , [entity_2]
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_goods_ENT]
FROM #industry_helper_25
WHERE Industry_broad = 'Goods-producing' CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_goods_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_goods_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_services_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [entity_1]
    , [entity_2]
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_services_ENT]
FROM #industry_helper_25
WHERE Industry_broad = 'Services' CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_services_ENT] ([snz_uid], [quarter])
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_25YO_services_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

/**********************************************************************************************************/

