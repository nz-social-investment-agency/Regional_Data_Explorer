/**************************************************************************************************
Title: ECE attendance
Author: Simon Anastasiadis
Edited by Dan Young & Charlotte Rose

Inputs & Dependencies:
- [IDI_Clean_202410].[moe_clean].[ece_student_attendance]
Outputs:
- [IDI_Sandpit].[DL-MAA2023-55].[defn_ece_attendance]

Description:
Recorded attendance at an ECE centre

Intended purpose:
Identifying who has attended Early Childhood Education, when they attended and the hours on average per week they attended.

Notes:
1) ECE attendance has been binned to 10-hour wide bins, those with 0 or NULL hours, but marked as 'present' have been grouped into an unknown hours category
2) There may be some inaccuracy at the margins as there will be periods where ECEs are not open. Desktop research suggests that many
   will have terms/holiday periods aligned with primary schools. This has 380-390 half days per year, across four terms.
   Terms appear to be roughly aligned with a quarter, but there may be some cross-over. Precise calculation would also need to take into
   account things like teacher-only days and any difference in the timing of regional holidays (eg, Auckland Anniversary Day is observed 
   in Q1 (January); Hawke's Bay Anniversary Day is observed in Q4 (October)) that could result in different distribution of opening 
   across the year.
3) As a result, this should not be used for very fine distinctions. Researchers using this code could look at the number of people close to the cut-off to
   consider if the binning is appropriate for their purposes.
4) Note from MoE - data in IDI and in PIM (Participation Intensity Measure) are sources from the ELI (Early Learning Information - a series of databases which 
   holds data primarily on enrolment and participation appolication, trying to reconcile the two would be difficult and not advised primarily due to the 
   complexity and construction of the PIM. Also noting that ELI is alive system and extracts taken at different times will differ. Thus this has not been reconciled and will be caveated as above
5) The oldest age in the quarter has been used
6) Will not match ECE census data as census can double count people attending multiple ECEs, and IDI does not contain data for all ECE types i.e playgroups, Kohanga Reo services etc (see IDI metadata)
7) As per 4) and 6) this has not been reconciled and will be caveated as above

Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-55]
  Earliest start date = '2018-01-01'

Issues:


History (reverse order):
2024-07-15 CR added age filter when adding to master to filter out those over 5yr
2023-01-15 CR updates for Regional Data Project
2022-04-05 JG Updated project and refresh for Data for Communities
2020-05-25 SA v1
**************************************************************************************************/
-------------------------------------------------------- Education: ECE Attendance --------------------------------------------------------
/* Outputs: Column added to dataset: ECE_HRS_WK - The hours on average per week the person attended ECE
			Table containing contributing entities: ECE_HRS_WK_ENT (Join on snz_uid and quarter)

Runtime: approx 9 minutes
*/

/* Clear table */
DROP TABLE IF EXISTS #temp;
GO
SELECT DISTINCT a.[snz_uid]
    , a.[snz_moe_uid]
    , a.[moe_esa_provider_code] AS [ProviderNumber]
    , a.[moe_esa_attendance_date] AS [AttendanceDate]
    , a.[moe_esa_provider_code]
    , COALESCE(a.[moe_esa_duration],0) AS Duration
    , b.[quarter]
    , [enddate]
    , [startdate]
INTO #temp
FROM [IDI_Clean_202410].[moe_clean].[ece_student_attendance] a
INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] b
ON a.[moe_esa_attendance_date] <= b.enddate
AND a.[moe_esa_attendance_date] >= b.startdate
WHERE [moe_esa_ece_attendance_code] = 'PRESENT'
AND CAST(a.[moe_esa_attendance_date] AS DATE) >= '2020-04-01'
AND CAST(a.[moe_esa_attendance_date] AS DATE) <= '2024-04-01'; -- Use a manual end date to avoid the end of the series
GO


DROP TABLE IF EXISTS #ece_attendance
SELECT snz_uid
    , CASE WHEN SUM(Duration)/600.00 IS NULL OR SUM(Duration)/600.00 = 0 THEN 1 ELSE NULL END AS ECE_HRS_WK__unk
    , CASE WHEN SUM(Duration)/600.00 < 10 AND SUM(Duration)/600.00 > 0 THEN 1 ELSE NULL END AS ECE_HRS_WK__00_10
    , CASE WHEN SUM(Duration)/600.00 < 20 AND SUM(Duration)/600.00 >= 10 THEN 1 ELSE NULL END AS ECE_HRS_WK__10_20
    , CASE WHEN SUM(Duration)/600.00 < 30 AND SUM(Duration)/600.00 >= 20 THEN 1 ELSE NULL END AS ECE_HRS_WK__20_30
    , CASE WHEN SUM(Duration)/600.00 >= 30 THEN 1 ELSE NULL END AS ECE_HRS_WK__30
    , #temp.[quarter]
INTO #ece_attendance
FROM #temp
GROUP BY snz_uid
    , [quarter] --Attended_ECE

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS ECE_HRS_WK__unk
    , COLUMN IF EXISTS ECE_HRS_WK__00_10
    , COLUMN IF EXISTS ECE_HRS_WK__10_20
    , COLUMN IF EXISTS ECE_HRS_WK__20_30
    , COLUMN IF EXISTS ECE_HRS_WK__30
    , COLUMN IF EXISTS ECE_HRS_WK__less_than_10
    , COLUMN IF EXISTS ECE_HRS_WK__greater_than_10
    , COLUMN IF EXISTS ECE_HRS_WK__greater_than_20

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD 
																--ECE_HRS_WK__unk bit,
 ECE_HRS_WK__00_10 bit
    , ECE_HRS_WK__10_20 bit
    , ECE_HRS_WK__20_30 bit
    , ECE_HRS_WK__30 bit
																--ECE_HRS_WK__less_than_10 bit,  //not using for RDP//
																--ECE_HRS_WK__greater_than_10 bit,
																--ECE_HRS_WK__greater_than_20 bit;
GO


UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET
	--ECE_HRS_WK__unk = ece.ECE_HRS_WK__unk,
 ECE_HRS_WK__00_10 = CASE WHEN ece.ECE_HRS_WK__00_10 =1 AND AGE_RDP = 1 THEN 1 ELSE NULL END
    , ECE_HRS_WK__10_20 = CASE WHEN ece.ECE_HRS_WK__10_20 = 1 AND AGE_RDP = 1 THEN 1 ELSE NULL END
    , ECE_HRS_WK__20_30 = CASE WHEN ece.ECE_HRS_WK__20_30 = 1 AND AGE_RDP = 1 THEN 1 ELSE NULL END
    , ECE_HRS_WK__30 = CASE WHEN ece.ECE_HRS_WK__30 = 1 AND AGE_RDP = 1 THEN 1 ELSE NULL END
	--ECE_HRS_WK__less_than_10 = CASE WHEN ece.ECE_HRS_WK__unk = 1 OR ece.ECE_HRS_WK__00_10 = 1 THEN 1 ELSE null END, //not using for RDP//
	--ECE_HRS_WK__greater_than_10 = CASE WHEN ece.ECE_HRS_WK__10_20 = 1 OR ece.ECE_HRS_WK__20_30 = 1 OR ece.ECE_HRS_WK__30 = 1 THEN 1 ELSE null END,
	--ECE_HRS_WK__greater_than_20 = CASE WHEN ece.ECE_HRS_WK__20_30 = 1 OR ece.ECE_HRS_WK__30 = 1 THEN 1 ELSE null END
FROM #ece_attendance ece
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ece.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = ece.[quarter]



ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS ECE_HRS_WK__any

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD 
																--ECE_HRS_WK__unk bit,
 ECE_HRS_WK__any bit

GO


UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET ECE_HRS_WK__any = CASE WHEN ECE_HRS_WK__00_10 = 1 OR ECE_HRS_WK__10_20 = 1 OR ECE_HRS_WK__20_30 = 1 OR ECE_HRS_WK__30 = 1 AND AGE_RDP = 1 THEN 1 ELSE NULL END

FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]



ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS ECE_HRS_WK__20

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD 
																--ECE_HRS_WK__unk bit,
 ECE_HRS_WK__20 bit

GO


UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET ECE_HRS_WK__20 = CASE WHEN ECE_HRS_WK__20_30 = 1 OR ECE_HRS_WK__30 = 1 AND AGE_RDP = 1 THEN 1 ELSE NULL END

FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].ECE_HRS_WK_ENT

SELECT DISTINCT snz_uid
    , ProviderNumber AS entity_1
    , [quarter]
INTO [IDI_Sandpit].[DL-MAA2023-55].ECE_HRS_WK_ENT
FROM #temp
/* Add index */
CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].ECE_HRS_WK_ENT (snz_uid)
;
 GO
/* Compress final table to save space */
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].ECE_HRS_WK_ENT REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO

DROP TABLE IF EXISTS #ece_attendance
DROP TABLE IF EXISTS #temp
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO
