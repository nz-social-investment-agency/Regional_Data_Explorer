/**************************************************************************************************
Title:Driving Licence Holders
Author: Ashleigh Arendt
Peer review: Charlotte Rose

Inputs & Dependencies:
- [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_$idicleanversion$]

Outputs:
- Update to [master_table]

Description:
Number of drivers licence holders of specific licence classes and stages.
Looking at all ages over 15 as well as those who turned 25

Intended purpose:
Drivers licences enable better access to work, education, healthcare, social connectness and more.

Notes:
1) NZ licences only
2) Only photo licences, excludes temporary paper licence holders
3) Following Waka Kotahi data is limited to current licence holders with the following licence classes:
	- Class 1 Motor Cars and Light Motor Vehicles - learner, restricted or full
	- Class 6 MOtorcycles, Moped or ATV - learner, restricted or full
4) Licence holders under 16 are excluded as the legal age increased from 15 to 16 in August 2011.

Parameters & Present values:
  Current refresh = 202410
  Prefix = _
  Project schema = [DL-MAA2023-55]
  Earliest start date = '2018-01-01'

Issues:

Runtime: ~20 minutes

History (reverse order):
2023-03-24 AA - using Code Modules new version of driving licence code

**************************************************************************************************/

DROP TABLE IF EXISTS #current_driving_licence;
SELECT a.snz_uid
    , b.quarter
    , a.nzta_dlr_licence_class_text
    , a.nzta_dlr_licence_stage_text
    , 1 AS current_licence

INTO #current_driving_licence
FROM(
    SELECT *
    FROM [IDI_Community].[cm_read_NZTA_DRIVER_LICENCES_STATUS].[nzta_driver_licences_status_202410]
    WHERE nzta_dlr_class_status_text = 'CURRENT'
    AND nzta_dlr_licence_class_text IN ('MOTOR CARS AND LIGHT MOTOR VEHICLES', 'MOTORCYCLES, MOPED OR ATV')
)a
INNER JOIN [IDI_UserCode].[DL-MAA2023-55].[mt_quarters] b
ON a.spell_start <= b.enddate
AND a.spell_end >= b.enddate


DROP TABLE IF EXISTS #current_driving_licence_types;
SELECT snz_uid
    , quarter
    , MAX(current_licence) AS holds_licence
    , MAX(CASE WHEN nzta_dlr_licence_stage_text = 'FULL' THEN 1 ELSE NULL END) AS holds_full
    , MAX(CASE WHEN nzta_dlr_licence_stage_text = 'LEARNER' THEN 1 ELSE NULL END) AS holds_learner
    , MAX(CASE WHEN nzta_dlr_licence_stage_text = 'RESTRICTED' THEN 1 ELSE NULL END) AS holds_restricted
    , MAX(CASE WHEN nzta_dlr_licence_class_text = 'MOTOR CARS AND LIGHT MOTOR VEHICLES' THEN 1 ELSE NULL END) AS car_licence
    , MAX(CASE WHEN nzta_dlr_licence_class_text = 'MOTORCYCLES, MOPED OR ATV' THEN 1 ELSE NULL END) AS motorcycle_licence
INTO #current_driving_licence_types
FROM #current_driving_licence
GROUP BY SNZ_UID
    , QUARTER

/* Join to Master Table */

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS dl_holder
    , COLUMN IF EXISTS dl_holder_full
    , COLUMN IF EXISTS dl_holder25YO
    , COLUMN IF EXISTS dl_holder_full25YO;
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD dl_holder INT
    , dl_holder_full INT
    , dl_holder25YO INT
    , dl_holder_full25YO INT;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET dl_holder = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].AGE > 15 AND holds_licence = 1 THEN 1 ELSE NULL END
    , dl_holder_full = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].AGE > 15 AND holds_full = 1 THEN 1 ELSE NULL END
    , dl_holder25YO = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].AGE_25YO = 1 AND holds_licence = 1 THEN 1 ELSE NULL END
    , dl_holder_full25YO = CASE WHEN [IDI_Sandpit].[DL-MAA2023-55].[Master_table_202410].AGE_25YO = 1 AND holds_full = 1 THEN 1 ELSE NULL END


FROM #current_driving_licence_types dl
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = dl.snz_uid
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].quarter = dl.quarter;
 ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO

DROP TABLE IF EXISTS #current_driving_licence;
DROP TABLE IF EXISTS #current_driving_licence_types;
