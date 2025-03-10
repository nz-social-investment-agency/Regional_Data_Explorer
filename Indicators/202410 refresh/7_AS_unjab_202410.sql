/**************************************************************************************************
Title: Referrals to attendance services
Author: Charlotte Rose
Peer review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202410].[moe_clean].[student_interventions]

Outputs:
- Update to [master_table_202410]

Description:
Referrals to attendance services (AS) for unjustified absence (UA)

This code is based on the logic developed by Andrew Webber as part of the alternative education evaluation

Intended purpose:
Identifying those young people under the age of 15 who have been referred to attendance services for unjustified absence.

Notes:
1) 

Parameters & Present values:
  Current refresh = 202410
  Prefix = _
  Project schema = [DL-MAA2023-55]
  Earliest start date = '2018-01-01'

Issues:


History (reverse order):
2023-12-15 - CR adapted code from Andrew Webbers Alt ed analysis

**************************************************************************************************/
-------------------------------------------------------- Education: Attendance service referrals --------------------------------------------------------
/* Outputs: Columns added to dataset: 

AS_UnjAbs - flag for any prior referral to attendance services for non attendance

Table containing contributing entities: 

Runtime (before adding to master): 00:00:01
Runtime (adding to master): 00:00:19
*/

--all attendance service referrals for unjustified absence--


DROP TABLE IF EXISTS #ats;

--unjustified absences--

SELECT a.snz_uid
    , a.moe_inv_inst_num_code
    , a.moe_inv_start_date AS startdate
    , CASE WHEN a.moe_inv_end_date > GETDATE() THEN GETDATE() -- ensure no nulls in end_date for those open interventions
 ELSE a.moe_inv_end_date END AS enddate
INTO #ats
FROM [IDI_Clean_202410].[moe_clean].[student_interventions] a
WHERE a.moe_inv_intrvtn_code = 32 --truancy (unjustified absence)
AND a.moe_inv_start_date >= (
    SELECT DATEADD (YEAR,-1,MIN(q.enddate))
    FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
)

--Flag whether child has been inovled with AS in the past 12mo--

DROP TABLE IF EXISTS #final;

SELECT DISTINCT a.snz_uid
    , q.quarter
    , 1 AS AS_UnjAbs
INTO #final
FROM #ats a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.startdate >= DATEADD(YEAR,-1,q.enddate)
AND a.startdate <= q.enddate
GROUP BY q.quarter
    , a.snz_uid


-- Add to master --
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS AS_UnjAbs;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD AS_UnjAbs int;

GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET AS_UnjAbs = CASE WHEN a.AS_UnjAbs = 1 AND AGE_compulsory_school = 1 THEN 1 ELSE NULL END

FROM #final a
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = a.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[quarter] = a.[quarter]

--ALTER TABLE  [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)	

-- create entity counts //

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[AS_UnJabs_ENT];

SELECT a.snz_uid
    , q.quarter
    , CAST(a.moe_inv_inst_num_code AS int) AS [entity_1]
INTO [IDI_Sandpit].[DL-MAA2023-55].[AS_UnJabs_ENT]
FROM #ats a
LEFT JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] q
ON a.startdate > DATEADD(YEAR,-1,q.enddate)
AND a.startdate <= q.enddate --start date for the intervention occurred before the end date of the quarter and enddate
GROUP BY snz_uid
    , quarter
    , moe_inv_inst_num_code
 CREATE CLUSTERED INDEX my_index_name ON  [IDI_Sandpit].[DL-MAA2023-55].[AS_UnJabs_ENT] ([snz_uid], [quarter])
;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[AS_UnJabs_ENT] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
