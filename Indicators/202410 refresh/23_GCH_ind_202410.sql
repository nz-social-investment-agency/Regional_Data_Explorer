/**************************************************************************************************
Title: Geographical Classifications for Health
Author: Ashleigh Arendt
Peer review: Wian Lusse
Inputs & Dependencies:
- [IDI_Sandpit].[DL-MAA2023-55].[gch_sa1_2018] (Geographical classifications for health concordance obtained externally, see https://rhrn.nz)
	NOTE: the concordance table must be uploaded to sandpit from CSV (SA12018_to_GCH2018.csv) before running the script
- [IDI_Metadata_202406].[data].[meshblock_concordance]
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[meshblock_current_higher_geography] 


Outputs:
- Update to [master_table]

Description:
The Geographical Classifications for Health is a rural-urban geographical classification which classifies SA1's according to their proximiting to large urban areas with respect to Health.
GCH comprises 5 categories from Urban 1, Urban 2 based on population size, and from Rural 1 to Rural 3 based on drive time to closest major, large, medium and small urban areas.
Please see the technical report under https://rhrn.nz/gch/publications 'The Geographic Classification for Health' Whitehead, Davie, de Graaf et al. (2021).

Intended purpose:
Aim to allow health researchers and policy makers to accurately monitor rural-urban variations in health outcomes.

Notes:
1) The GCH is based on Stats NZ geographies and classifications from 2018
2) 

Parameters & Present values:
  Current refresh = 202406
  Prefix = _
  Project schema = [DL-MAA2023-55]
  Earliest start date = 
 
Issues:
- Disclaimer: GCH has not been designed to uncritically guide health policy and funding decisions and is not an index of healthcare accessibility or workforce shortage.

Runtime (before adding to master): 00:00:51
 
History (reverse order):
2024-04-26 - AA

**************************************************************************************************/



/* Mapping each meshblock to GCH classification */
DROP TABLE IF EXISTS #mb_gch_class;

SELECT DISTINCT m.[ant_meshblock_code]
, g.[column2] AS gch_class
INTO #mb_gch_class
FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table] m
INNER JOIN [IDI_Metadata_202406].[data].[meshblock_concordance] AS conc24
ON conc24.[MB2024_code] = m.[ant_meshblock_code]
LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[meshblock_current_higher_geography] AS b
ON conc24.[MB2018_code] = b.[MB2018_V1_00]
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-55].[gch_sa1_2018] AS g
on b.[SA12018_V1_00] = g.[column1]; -- column 1 is the 2018 sa1


/* Match on ant_meshblock_code */

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202406] DROP COLUMN IF EXISTS GCH_U1, COLUMN IF EXISTS GCH_U2, COLUMN IF EXISTS GCH_R1
															, COLUMN IF EXISTS GCH_R2, COLUMN IF EXISTS GCH_R3;
																
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202406] ADD GCH_U1 int, GCH_U2 int, GCH_R1 int, GCH_R2 int, GCH_R3 int;
GO

UPDATE
	[IDI_Sandpit].[DL-MAA2023-55].[master_table_202406]
SET
	
	GCH_U1 = CASE WHEN gch.[gch_class] = 'U1' THEN 1 ELSE null END,
	GCH_U2 = CASE WHEN gch.[gch_class] = 'U2' THEN 1 ELSE null END,
	GCH_R1 = CASE WHEN gch.[gch_class] = 'R1' THEN 1 ELSE null END,
	GCH_R2 = CASE WHEN gch.[gch_class] = 'R2' THEN 1 ELSE null END,
	GCH_R3 = CASE WHEN gch.[gch_class] = 'R3' THEN 1 ELSE null END

FROM #mb_gch_class gch
	WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202406].ant_meshblock_code = gch.[ant_meshblock_code];