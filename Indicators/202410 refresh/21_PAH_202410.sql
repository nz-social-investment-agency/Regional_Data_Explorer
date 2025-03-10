/**************************************************************************************************
Title: Potentially Avoidable Hospitalisations
Author: Ashleigh Arendt
Peer review: Charlotte Rose

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies: 
- [IDI_Community].[cm_read_MOH_ASH_PAH].[moh_ash_pah_202410] (code module)


Outputs:
- Update to [master_table_202410]

Description:
PAH = Preventable by population level intervention / health programs / immunisation etc. This is part of the child youth and wellbeing strategy - child poverty related indicators report - 2019/2020.

This code uses the code module - see the Stats website under code modules for more information.


Intended purpose:
To identify disparities in rates of potentially avoidable hospitalisations to assess the performance of social interventions that aim to prevent them.

Notes:
-- events from as far back as 1914, earliest we're interested in is 14YO in 2020Q2 - have they ever had a PAH, so earliest date is 01-07-2005
-- 202310 refresh : latest data available for events is June 2022, so latest we published is 2022Q2
-- 202410 refresh: latest data available for events is June 2023, so latest we publish is 2023Q2
-- 202410 refresh: latest data available for events is June 2023, so latest we publish is 2023Q2
-- We're using the birth dates from MoH to align with OT's definition, in future it might be better to take the dates from the personal details table as they are pulled from a number of sources, some of which may be more reliable
-- See external file for PAH codes

Parameters & Present values:
  Current refresh = 202410
  Prefix = _
  Project schema = DL-MAA2023-55

Issues:
-- Many versions of this code, may not be the most up-to-date

History (reverse order):
2024-02-14 AA

Run time (before joining to master table): ~7 mins

**************************************************************************************************/

DROP TABLE IF EXISTS #child_pah_only;

SELECT DISTINCT snz_uid
    , quarter
    , qt.startdate AS qt_start
    , qt.enddate AS qt_end
    , ap.start_date AS pah_start
    , ap.end_date AS pah_end
    , 1 AS pah
INTO #child_pah_only
FROM [IDI_Community].[cm_read_MOH_ASH_PAH].[moh_ash_pah_202410] ap
INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] qt
ON ap.start_date <= qt.enddate
AND ap.end_date >= DATEADD(YEAR, -5, qt.startdate)
WHERE source_type = 'child_PAH'


DROP TABLE IF EXISTS #child_pah_final;
SELECT a.snz_uid
    , a.quarter
    , MAX(CASE WHEN pah_start <= qt_end THEN 1 ELSE 0 END) AS PAH_child
    , MAX(CASE WHEN pah_start <= qt_end AND pah_start > DATEADD(YEAR, -1, qt_end) THEN 1 ELSE 0 END) AS PAH_1y
    , MAX(CASE WHEN DATEADD(YEAR, 5, (DATEADD(mm, DATEDIFF(m,0, mt.dob) + 1, 0))) >= pah_start THEN 1 ELSE 0 END) AS PAH_5YO
INTO #child_pah_final
FROM #child_pah_only a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] mt
ON a.snz_uid = mt.snz_uid
GROUP BY a.snz_uid
    , a.quarter

--add to master-- Run time ~ 34min

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS PAH_5YO
    , COLUMN IF EXISTS PAH_child;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD PAH_5YO int
    , PAH_child int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET PAH_child = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].AGE_RDP IN (1,2) AND pah.PAH_child = 1 THEN 1 ELSE NULL END
    , PAH_5YO = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].AGE_5YO = 1 AND pah.PAH_5YO = 1 THEN 1 ELSE NULL END
FROM #child_pah_final pah
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = pah.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].quarter = pah.quarter;

SELECT pah_child
    , COUNT(*)
FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
GROUP BY pah_child

SELECT pah_5YO
    , COUNT(*)
FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
GROUP BY pah_5YO

