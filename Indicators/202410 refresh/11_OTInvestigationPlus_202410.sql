/**************************************************************************************************
Title: OT_interactionsPlus
Author: Dan Young
Edited by: Charlotte Rose

Inputs & Dependencies:
- [IDI_Clean].[cyf_clean].[cyf_intakes_event]
- [IDI_Clean].[cyf_clean].[cyf_intakes_details]
- [cyf_investgtns_event]
- [cyf_investgtns_details]
- [cyf_ev_cli_fgc_cys_f]
- [cyf_placements_event]
- [cyf_placements_details]

Outputs:
- Update to [master_table]

Description:
Indicators of whether a child or young person has previously had to date, any of the following:
- an investigation following from a report of concern to OT
- a family group conference (following investigation of a RoC)
- a placement (including where placed with whanau, or remaining in current residence but while under legal custody of OT)

Intended purpose:
Understanding whether tamariki and rangatahi have experienced trauma

Notes and limitations:
	-	We have been advised that there are different approaches to recording reports of concern between different regions, which 
		results in some areas reporting more/less than others. Thus we are not collecting data for ROCs for RDP.
	-	While this indicator looks over the lifetime, overall numbers are still relatively low. This may 
		prevent granular breakdowns by demographic/region or other indicator
	-	Data quality:
			- not all persons in OT data have a birthday in the personal_detail table. We lose about 2% of uids (accounting for <0.5% of the data) from these
			- we then lose a further ~2% of uids and rows where the start date of the event predates the persons birthday (after accounting for birthday being a mid-month proxy)
			- joining the data onto our dataset then produces a ~9.5% loss due to a number of people in the OT dataset are not on the spine (only reference in pd table is MSD)
			- Further ~5% loss due to the people not being in our population definition (overseas or deceased mostly)

	- Looking at records compared to published figures (eg, by OT) for a comparable period (12mo < 30/03/2023):			
		Investigations -	are a bit lower (7-10%) compared to OT published figures for Referred for Assessment or Investigation. The difference is currently assumed to be
							due to the mismatch in what is being measured. Investigation-only figures could not be found at the time of review.
		FGC -				FGCs can come through the Youth Justice or the Care and Protection stream. When published figures for both are summed our redults are 2% higher than published figueres

		Placements -		numbers with a placement spell overlapping the end of a final year are a close match to the published figures. Differences might be based on data 
							available at the time of reporting.

		Note that this code does not make all the distinctions discussed above, as the interest is in ANY interactions with the OT system above ROC to date as a binary indicator.


Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Hardcoded dates:
	- ctrl+f for <HCD>

Issues:

History (reverse order):
2024-01-24 CR - Updated for RDP
2023-08-02 DY - removed RoC based on conversation with Steve Murray at OT
2023-06-30 DY - v1
**************************************************************************************************/


DROP TABLE IF EXISTS #temp_inv;
DROP TABLE IF EXISTS #temp_fgc;
DROP TABLE IF EXISTS #temp_pla;


-- Investigation events (following a RoC)
SELECT a.[snz_uid]
    , a.[cyf_ive_event_from_date_wid_date] AS startdate
    , 'Inv' AS ot_event_type
INTO #temp_inv
FROM [IDI_Clean_202410].[cyf_clean].[cyf_investgtns_event] a 

-- Family group conference (following investigation)
SELECT [snz_uid]
    , [cyf_fge_event_from_date_wid_date] AS startdate
    , 'FGC' AS ot_event_type
INTO #temp_fgc
FROM [IDI_Clean_202410].[cyf_clean].[cyf_ev_cli_fgc_cys_f];

-- Placement (following FGC)
-- There are a range of reasons for a placement, including justice system-related (eg, held at a Corrections Youth Unit)
-- Placements can also include 'remain home' placements where the family retain physical custody, but legally the tamaiti is in the care of the CE.
-- These may all still be a good signal
SELECT [snz_uid]
    , [cyf_ple_event_from_date_wid_date] AS startdate
    , 'Pla' AS ot_event_type
INTO #temp_pla
FROM [IDI_Clean_202410].[cyf_clean].[cyf_placements_event];

-- Combine to one table
DROP TABLE IF EXISTS #OT_interactions;
SELECT k.*
    , d.snz_birth_date_proxy
INTO #OT_interactions
FROM(
    SELECT *
    FROM #temp_inv
    UNION
    SELECT *
    FROM #temp_fgc
    UNION
    SELECT *
    FROM #temp_pla
)k
LEFT JOIN [IDI_Clean_202410].[data].[personal_detail] d
ON k.snz_uid = d.snz_uid
WHERE k.startdate > '2005-06-30' -- <HCD> Used to limit the dataset to a manageable size - based on being interested in school aged children.
AND EOMONTH(k.startdate) >= snz_birth_date_proxy -- ensure child was born at time of interaction

--flag for any interaction above ROC
DROP TABLE IF EXISTS #temp
SELECT ot.snz_uid
    , MAX( CASE WHEN ot.ot_event_type IS NOT NULL THEN 1 ELSE NULL END) AS ot_flag
    , MIN(ot.startdate) AS startdate
INTO #temp
FROM #OT_interactions ot
GROUP BY ot.snz_uid

-- Add to master
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS OT_Inv_plus;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD OT_Inv_plus int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET OT_Inv_plus = CASE WHEN ot.ot_flag IS NOT NULL THEN 1 ELSE NULL END
FROM #temp ot
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ot.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].enddate >= ot.startdate;



ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS OT_Inv_plus_5YO;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD OT_Inv_plus_5YO int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET OT_Inv_plus_5YO = CASE WHEN ot.ot_flag IS NOT NULL THEN 1 ELSE NULL END
FROM #temp ot
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = ot.snz_uid
AND DATEADD(YEAR, 5, (DATEADD(mm, DATEDIFF(m,0, [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[DOB]) + 1, 0))) >= ot.startdate
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[AGE] = 5;
