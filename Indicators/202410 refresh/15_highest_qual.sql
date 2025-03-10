/**************************************************************************************************
Title: Highest Qualification
Author: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Community].[cm_read_HIGHEST_NQFLEVEL_SPELLS].[highest_nqflevel_spells] this should be the code for the latest refresh, for this version we have created our own table as the entity information wasn't available for 202310 refresh  
Outputs:
- 

Description:
Determine the highest qualification level for the population as of the end date of each quarter.

Intended purpose:
Qualifications are correlated with higher rates of employment and income. Measuring qualifications is one aspect of the skills and capabilities that a person brings into the labour market.
 
Notes:
- Latest data available for 'nqf_attained' is May 2023 for the 202310 refresh
- Most data is updated in the month of December - likely from when people get the data


Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:
 
History (reverse order):
2024-02-25 AA
**************************************************************************************************/

/* Reducing the size of the highest qualification dataset to the time period of interest */

DROP TABLE IF EXISTS #qt_highest_quals;
SELECT *
INTO #qt_highest_quals
FROM  [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_entity] a --should be [IDI_Community].[cm_read_HIGHEST_NQFLEVEL_SPELLS].[highest_nqflevel_spells]
WHERE nqf_attained_date <= (SELECT MAX(enddate) FROm [IDI_UserCode].[DL-MAA2023-55].[mt_quarters])
AND until_date >= DATEADD(YEAR, -1, (SELECT MIN(enddate) FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters])) --allow for a year before the earliest end date to capture those who turned 25

/* Joining to master table */

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] DROP COLUMN IF EXISTS highest_qual__no_qual,
																COLUMN IF EXISTS highest_qual__school,
																COLUMN IF EXISTS highest_qual__diploma,
																COLUMN IF EXISTS highest_qual__geq_bach,
																COLUMN IF EXISTS highest_qual__geq_school,
																COLUMN IF EXISTS highest_qual__unknown; 

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] ADD highest_qual__no_qual tinyint,
															highest_qual__school tinyint,
															highest_qual__diploma tinyint,
															highest_qual__geq_bach tinyint,
															highest_qual__geq_school tinyint,
															highest_qual__unknown tinyint;
GO

UPDATE
	[IDI_Sandpit].[DL-MAA2023-55].[master_table]
SET
	highest_qual__no_qual = CASE WHEN a.max_nqflevel_sofar = 0 AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END,
	highest_qual__school = CASE WHEN a.max_nqflevel_sofar IN (1,2,3) AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END,
	highest_qual__diploma = CASE WHEN a.max_nqflevel_sofar IN (4,5,6) AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END,
	highest_qual__geq_bach = CASE WHEN a.max_nqflevel_sofar IN (7,8,9,10) AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END,
	highest_qual__geq_school = CASE WHEN a.max_nqflevel_sofar > 0 AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END,
	highest_qual__unknown = CASE WHEN a.max_nqflevel_sofar IS NULL AND AGE_RDP NOT IN (1,2) THEN 1 ELSE NULL END

FROM #qt_highest_quals a
	WHERE a.snz_uid = [IDI_Sandpit].[DL-MAA2023-55].[master_table].snz_uid
	AND a.nqf_attained_date <= [IDI_Sandpit].[DL-MAA2023-55].[master_table].enddate
	AND a.until_date > [IDI_Sandpit].[DL-MAA2023-55].[master_table].enddate


-- Update master table for 25YO population

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] DROP COLUMN IF EXISTS highest_qual_25YO__no_qual,
																COLUMN IF EXISTS highest_qual_25YO__school,
																COLUMN IF EXISTS highest_qual_25YO__diploma,
																COLUMN IF EXISTS highest_qual_25YO__geq_bach,
																COLUMN IF EXISTS highest_qual_25YO__geq_school,
																COLUMN IF EXISTS highest_qual_25YO__unknown;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table] ADD highest_qual_25YO__no_qual tinyint,
															highest_qual_25YO__school tinyint,
															highest_qual_25YO__diploma tinyint,
															highest_qual_25YO__geq_bach tinyint,
															highest_qual_25YO__geq_school tinyint,
															highest_qual_25YO__unknown tinyint;
GO


UPDATE
	[IDI_Sandpit].[DL-MAA2023-55].[master_table]
SET
	highest_qual_25YO__no_qual = CASE WHEN a.max_nqflevel_sofar = 0 AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END,
	highest_qual_25YO__school = CASE WHEN a.max_nqflevel_sofar IN (1,2,3) AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END,
	highest_qual_25YO__diploma = CASE WHEN a.max_nqflevel_sofar IN (4,5,6) AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END,
	highest_qual_25YO__geq_bach = CASE WHEN a.max_nqflevel_sofar IN (7,8,9,10) AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END,
	highest_qual_25YO__geq_school = CASE WHEN a.max_nqflevel_sofar > 0 AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END,
	highest_qual_25YO__unknown = CASE WHEN (a.max_nqflevel_sofar IS NULL) AND [IDI_Sandpit].[DL-MAA2023-55].[master_table].AGE_25YO = 1 THEN 1 ELSE NULL END 

FROM #qt_highest_quals a
	WHERE a.snz_uid = [IDI_Sandpit].[DL-MAA2023-55].[master_table].snz_uid
	AND a.nqf_attained_date <= DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, [IDI_Sandpit].[DL-MAA2023-55].[master_table].[DOB]) + 1, 0)))
	AND a.until_date > DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, [IDI_Sandpit].[DL-MAA2023-55].[master_table].[DOB]) + 1, 0)))


-- Create entity tables

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_ENT];
SELECT DISTINCT [snz_uid]
	  ,[quarter]
	  ,[entity] AS entity_1
INTO [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_ENT]
FROM #qt_highest_quals
INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] qt
ON nqf_attained_date <= qt.enddate
AND until_date > qt.enddate

CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_ENT] ([snz_uid], [quarter])
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

-- Create entity table for 25 YO population

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_25YO_ENT];
SELECT DISTINCT a.[snz_uid]
	  ,mt.[quarter]
	  ,a.[entity] AS entity_1
INTO [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_25YO_ENT]
FROM #qt_highest_quals a
INNER JOIN (SELECT * FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table] WHERE AGE = 25) mt
ON a.snz_uid = mt.snz_uid
AND a.nqf_attained_date <= DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, mt.[DOB]) + 1, 0)))
	AND a.until_date > DATEADD(YEAR, 25, (DATEADD(mm, DATEDIFF(m,0, mt.[DOB]) + 1, 0)))

CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_25YO_ENT] ([snz_uid], [quarter])
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[highest_qual_25YO_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


