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


Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:
- The latest month available in IRD doesn't have values for PBN / ENT numbers, so the anzsic codes are not identifiable which will bring the values down for that quarter

History (reverse order):
2024-05-27 -  CR Peer review
2024-02-22 - AA updated documentation for Regional Data Project
2023-08-01 - updated to make consistent with approach to D4C
2023-05-01 - automatic update to IDI_Clean_202410
2022-04-05 JG Updated project and refresh for Data for Communities
2020-05-20 SA v1
**************************************************************************************************/

/*  */

DROP TABLE IF EXISTS #industry_helper;
SELECT DISTINCT ir.[snz_uid]
    , qt.[quarter]
    , ABS(CAST(HashBytes('MD5', ir.[ir_ems_enterprise_nbr]) AS int)) AS [ir_ems_enterprise_nbr] -- need to turn into number not a string
    , ABS(CAST(HashBytes('MD5', ir.[ir_ems_pbn_nbr]) AS int)) AS [ir_ems_pbn_nbr] -- need to turn into number not a string
    , LEFT(COALESCE(ir.[ir_ems_pbn_anzsic06_code], ir.[ir_ems_ent_anzsic06_code]), 1) AS anzsic06
INTO #industry_helper
FROM [IDI_Clean_202410].[ir_clean].[ird_ems] ir
INNER JOIN [IDI_Usercode].[DL-MAA2023-55].[mt_quarters] qt
ON ir.ir_ems_return_period_date >= qt.startdate
AND ir.ir_ems_return_period_date <= qt.enddate --takes all entries for that quarter
WHERE ir.snz_ird_uid > 0
AND ir.ir_ems_income_source_code = 'W&S'
AND ir.ir_ems_gross_earnings_amt > 0
AND ir.ir_ems_snz_unique_nbr = 1

GO
 CREATE NONCLUSTERED INDEX my_index_name ON #industry_helper (snz_uid)
;
 ALTER TABLE #industry_helper REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

DROP TABLE IF EXISTS #temp;
SELECT DISTINCT [snz_uid]
    , [quarter]
    , CASE MAX(CASE WHEN anzsic06 = 'A' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_A
    , CASE MAX(CASE WHEN anzsic06 = 'B' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_B
    , CASE MAX(CASE WHEN anzsic06 = 'C' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_C
    , CASE MAX(CASE WHEN anzsic06 = 'D' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_D
    , CASE MAX(CASE WHEN anzsic06 = 'E' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_E
    , CASE MAX(CASE WHEN anzsic06 = 'F' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_F
    , CASE MAX(CASE WHEN anzsic06 = 'G' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_G
    , CASE MAX(CASE WHEN anzsic06 = 'H' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_H
    , CASE MAX(CASE WHEN anzsic06 = 'I' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_I
    , CASE MAX(CASE WHEN anzsic06 = 'J' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_J
    , CASE MAX(CASE WHEN anzsic06 = 'K' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_K
    , CASE MAX(CASE WHEN anzsic06 = 'L' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_L
    , CASE MAX(CASE WHEN anzsic06 = 'M' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_M
    , CASE MAX(CASE WHEN anzsic06 = 'N' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_N
    , CASE MAX(CASE WHEN anzsic06 = 'O' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_O
    , CASE MAX(CASE WHEN anzsic06 = 'P' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_P
    , CASE MAX(CASE WHEN anzsic06 = 'Q' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_Q
    , CASE MAX(CASE WHEN anzsic06 = 'R' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_R
    , CASE MAX(CASE WHEN anzsic06 = 'S' THEN 1 ELSE 0 END) WHEN 1 THEN 1 ELSE NULL END AS industry_sql_S
INTO #temp
FROM #industry_helper GROUP BY [snz_uid], [quarter]


-- Could further group from anzsic code to broader industries

ALTER TABLE #temp REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

 CREATE NONCLUSTERED INDEX my_index_name ON #temp (snz_uid)
;
GO

------------------------------------------------- Remove existing column (if any) from Master Table

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS industry_sql_A
    , COLUMN IF EXISTS industry_sql_B
    , COLUMN IF EXISTS industry_sql_C
    , COLUMN IF EXISTS industry_sql_D
    , COLUMN IF EXISTS industry_sql_E
    , COLUMN IF EXISTS industry_sql_F
    , COLUMN IF EXISTS industry_sql_G
    , COLUMN IF EXISTS industry_sql_H
    , COLUMN IF EXISTS industry_sql_I
    , COLUMN IF EXISTS industry_sql_J
    , COLUMN IF EXISTS industry_sql_K
    , COLUMN IF EXISTS industry_sql_L
    , COLUMN IF EXISTS industry_sql_M
    , COLUMN IF EXISTS industry_sql_N
    , COLUMN IF EXISTS industry_sql_O
    , COLUMN IF EXISTS industry_sql_P
    , COLUMN IF EXISTS industry_sql_Q
    , COLUMN IF EXISTS industry_sql_R
    , COLUMN IF EXISTS industry_sql_S;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD industry_sql_A tinyint
    , industry_sql_B tinyint
    , industry_sql_C tinyint
    , industry_sql_D tinyint
    , industry_sql_E tinyint
    , industry_sql_F tinyint
    , industry_sql_G tinyint
    , industry_sql_H tinyint
    , industry_sql_I tinyint
    , industry_sql_J tinyint
    , industry_sql_K tinyint
    , industry_sql_L tinyint
    , industry_sql_M tinyint
    , industry_sql_N tinyint
    , industry_sql_O tinyint
    , industry_sql_P tinyint
    , industry_sql_Q tinyint
    , industry_sql_R tinyint
    , industry_sql_S tinyint;
GO

------------------------------------------------- Add and update columns into Master Table


UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET industry_sql_A = CASE WHEN ir.industry_sql_A = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_B = CASE WHEN ir.industry_sql_B = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_C = CASE WHEN ir.industry_sql_C = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_D = CASE WHEN ir.industry_sql_D = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_E = CASE WHEN ir.industry_sql_E = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_F = CASE WHEN ir.industry_sql_F = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_G = CASE WHEN ir.industry_sql_G = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_H = CASE WHEN ir.industry_sql_H = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_I = CASE WHEN ir.industry_sql_I = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_J = CASE WHEN ir.industry_sql_J = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_K = CASE WHEN ir.industry_sql_K = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_L = CASE WHEN ir.industry_sql_L = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_M = CASE WHEN ir.industry_sql_M = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_N = CASE WHEN ir.industry_sql_N = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_O = CASE WHEN ir.industry_sql_O = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_P = CASE WHEN ir.industry_sql_P = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_Q = CASE WHEN ir.industry_sql_Q = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_R = CASE WHEN ir.industry_sql_R = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
    , industry_sql_S = CASE WHEN ir.industry_sql_S = 1 AND AGE_RDP > 2 THEN 1 ELSE NULL END
FROM #temp ir
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ir.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ir.[quarter];


-- Compress table
--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)


-- These entity count tables sometimes have multiple entries for an individual, for a quarter, so in this case take the one that gives the individual the highest earnings
-- might be better to partition over the industry, snz_uid and quarter to get the pbn and ent number from the highest paid job

/* Create entity counts tables */
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_A_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_A_ENT]
FROM #industry_helper
WHERE anzsic06 = 'A' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_A_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_A_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_B_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_B_ENT]
FROM #industry_helper
WHERE anzsic06 = 'B' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_B_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_B_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_C_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_C_ENT]
FROM #industry_helper
WHERE anzsic06 = 'C' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_C_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_C_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_D_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_D_ENT]
FROM #industry_helper
WHERE anzsic06 = 'D' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_D_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_D_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_E_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_E_ENT]
FROM #industry_helper
WHERE anzsic06 = 'E' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_E_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_E_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_F_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_F_ENT]
FROM #industry_helper
WHERE anzsic06 = 'F' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_F_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_F_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_G_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_G_ENT]
FROM #industry_helper
WHERE anzsic06 = 'G' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_G_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_G_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_H_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_H_ENT]
FROM #industry_helper
WHERE anzsic06 = 'H' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_H_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_H_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_I_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_I_ENT]
FROM #industry_helper
WHERE anzsic06 = 'I' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_I_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_I_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_J_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_J_ENT]
FROM #industry_helper
WHERE anzsic06 = 'J' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_J_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_J_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_K_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_K_ENT]
FROM #industry_helper
WHERE anzsic06 = 'K' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_K_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_K_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_L_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_L_ENT]
FROM #industry_helper
WHERE anzsic06 = 'L' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_L_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_L_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_M_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_M_ENT]
FROM #industry_helper
WHERE anzsic06 = 'M' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_M_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_M_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_N_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_N_ENT]
FROM #industry_helper
WHERE anzsic06 = 'N' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_N_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_N_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_O_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_O_ENT]
FROM #industry_helper
WHERE anzsic06 = 'O' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_O_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_O_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_P_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_P_ENT]
FROM #industry_helper
WHERE anzsic06 = 'P' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_P_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_P_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_Q_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_Q_ENT]
FROM #industry_helper
WHERE anzsic06 = 'Q' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_Q_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_Q_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_R_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_R_ENT]
FROM #industry_helper
WHERE anzsic06 = 'R' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_R_ENT] ([snz_uid], [quarter])
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_R_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_S_ENT];
SELECT DISTINCT [snz_uid]
    , [quarter]
    , [ir_ems_enterprise_nbr] AS entity_1
    , [ir_ems_pbn_nbr] AS entity_2
INTO [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_S_ENT]
FROM #industry_helper
WHERE anzsic06 = 'S' CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_S_ENT] ([snz_uid], [quarter])
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[INDUSTRY_SQL_S_ENT]
REBUILD PARTITION = ALL
WITH(
    DATA_COMPRESSION = PAGE
);





/**********************************************************************************************************/
