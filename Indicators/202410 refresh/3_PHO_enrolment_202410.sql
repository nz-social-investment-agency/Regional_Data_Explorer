/**************************************************************************************************
Title: PHO enrolment
Author: Craig Wright

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies:
- [IDI_Clean].[moh_clean].[nes_enrolment]
- [IDI_Clean].[moh_clean].[pop_cohort_demographics]
Outputs:
- Update to mater table

Description:
Enrolment with Primary Health Organisation (PHO)

Intended purpose:
Create variable reporting pho enrolment by month of enrolment pho_enrolment =(0/1)
based on monthly enrolment

Notes:
	There looks to be a potential delay with data becoming available in the dataset.
		archive		most recent record
		202410		2023-06-01
		202410		2023-06-01
		202310		2022-11-01
		202306		2022-11-01
		202410		2022-11-01
		202210		2021-11-01
		202206		2021-11-01
		202203		2021-11-01


for 202410 refresh the latest complete quarter will be 2023Q1

Parameters & Present values:
  Current refresh = 202410
  Prefix = pho_
  Project schema = DL-$(project)
  Snapshot month = '202306'

Issues:

History (reverse order):
2023-03-27 DY compared with SWA Github version - same logic.
2022-04-13 JG Updated project and refresh for Data for Communities
2021-11-25 SA tidy
2021-10-12 CW


**************************************************************************************************/
--checking max date

--SELECT a.[moh_nes_snapshot_month_date]
--	,COUNT (a.snz_uid)
--FROM [IDI_Clean_202410].[moh_clean].[nes_enrolment] a
--GROUP BY a.[moh_nes_snapshot_month_date]
--ORDER BY a.[moh_nes_snapshot_month_date] desc

/*PARAMETERS

SQLCMD only (Activate by clicking Query->SQLCMD Mode)*/

--Update with project, current refresh--

:setvar project "MAA20XX-XX" :setvar newmaster "Master_population_202410" :setvar refresh "202410"

/* remove */
DROP TABLE IF EXISTS #temp

/* create */
SELECT a.[snz_uid]
    , CAST([moh_nes_snapshot_month_date] AS DATE) AS enrolment_date
INTO #temp
FROM [IDI_Clean_$(refresh)].[moh_clean].[nes_enrolment] AS a
WHERE [moh_nes_snapshot_month_date] >= (
    SELECT MIN(startdate)
    FROM IDI_UserCode.[DL-$(project)].[mt_quarters]
)
AND [moh_nes_snapshot_month_date] <= (
    SELECT MAX(enddate)
    FROM IDI_UserCode.[DL-$(project)].[mt_quarters]
);

SELECT DISTINCT t.snz_uid
    , mt.[quarter]
    , 1 AS pho_enrolment
INTO #pho_for_join
FROM #temp t
LEFT JOIN IDI_UserCode.[DL-$(project)].[mt_quarters] mt
ON t.enrolment_date <= mt.enddate
AND t.enrolment_date >= mt.startdate;


ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS pho_enrolment;
ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD pho_enrolment bit;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET pho_enrolment = pho.pho_enrolment

FROM #pho_for_join pho
WHERE [IDI_Sandpit].[DL-$(project)].[$(newmaster)].snz_uid = pho.snz_uid 	AND [IDI_Sandpit].[DL-$(project)].[$(newmaster)].[quarter] = pho.[quarter]

	--Compress to save space--

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(new master)] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);


