/**************************************************************************************************
Title: Paid employees
Author: Ashleigh Arendt
PR: Charlotte Rose

Inputs & Dependencies:
- [IDI_Clean].[ir_clean].[ird_ems]
Outputs:
- Matched to master table

Description:
Counts anyone who has been a paid employee at some point within a quarter. Employment is inferred from the presence of wage and salary income on PAYE filings from employers to IRD.
*   Employment can be defined as having a paid job with the relationship registered and recorded by the Inland Revenue Department (IRD). This excludes unpaid job arrangements or under the table cash jobs not registered with IRD.

Intended purpose:
Helps to gauge the populations ability to earn a living and sense of purpose. May indicate likely demand for support services if the values are especially low.
 
Notes:
1) There are two sources to check entity data for:
   ir_ems_pbn_nbr = Permanent Business Number (PBN)
   ir_ems_enterprise_nbr = Enterprise Number
2) There are a number of records (~2% of the working population) for which both the PBN and Enterprise numbers are missing.
3) Figures are not seasonally adjusted
4) Data comes from tax data, if individuals are not reporting their self-employment income to IRD or are not meeting the income cut off amount for reporting SE income then they are not captured

Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:
- Misses self-employed
 
History (reverse order):
2024-05-27 - CR Peer review
2024-05-27 - AA - aligning with code modules before release

**************************************************************************************************/


/****** Entities and Employment data for each quarter for all people >15 *****/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[EMPLOYED_ENT];
SELECT DISTINCT ir.[snz_uid]
		,qt.[quarter]
		,abs(cast(HashBytes('MD5', ir.[ir_ems_enterprise_nbr]) as int)) AS [entity_1] -- need to turn into number not a string
		,abs(cast(HashBytes('MD5', ir.[ir_ems_pbn_nbr]) as int)) AS [entity_2] -- need to turn into number not a string
INTO [IDI_Sandpit].[DL-MAA2023-55].[EMPLOYED_ENT]
FROM [IDI_Clean_202410].[ir_clean].[ird_ems] ir
	INNER JOIN [IDI_Usercode].[DL-MAA2023-55].[mt_quarters] qt
ON  ir.ir_ems_return_period_date >= qt.startdate
	AND ir.ir_ems_return_period_date <= qt.enddate --takes all entries for that quarter

WHERE ir.snz_ird_uid > 0				
	AND ir.ir_ems_income_source_code = 'W&S'	
	AND ir.ir_ems_gross_earnings_amt > 0
	AND ir.ir_ems_snz_unique_nbr = 1

	GO

CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[EMPLOYED_ENT] ([snz_uid], [quarter]);
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[EMPLOYED_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


DROP TABLE IF EXISTS #temp_employed;
SELECT snz_uid
, quarter
, 1 as employed

INTO #temp_employed
FROM [IDI_Sandpit].[DL-MAA2023-55].[EMPLOYED_ENT]
GROUP BY snz_uid, quarter

CREATE CLUSTERED INDEX my_index_name ON #temp_employed ([snz_uid], [quarter])



------------------------------------------------- Remove existing column (if any) from Master Table

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] DROP COLUMN IF EXISTS employed, COLUMN IF EXISTS employed__65YO;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD employed tinyint, employed__65YO tinyint;
GO

------------------------------------------------- Add and update columns into Master Table


UPDATE
	[IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET
	employed = CASE WHEN ir.employed = 1 AND AGE > 14 THEN 1 ELSE NULL END, --only take the working age population for the employed indicator
	employed__65YO = CASE WHEN ir.employed = 1 AND AGE = 65 THEN 1 ELSE NULL END

FROM 
	#temp_employed ir
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ir.snz_uid
	AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ir.[quarter];

	-- compress master to save space--

--ALTER TABLE  [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
