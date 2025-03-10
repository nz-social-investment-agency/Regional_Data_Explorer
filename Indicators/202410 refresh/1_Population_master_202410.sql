 /* 
Inputs used:
- This script creates a resident population definition to identify all people who are alive AND onshore for each quarter between a predefined range 
- Attaches geographic AND demographic information for this population to aid in summarisation of these populations.
- This serves as the base population for the regional data explorer, depending on the indicator there is also an option to select whether an individual is on the spine or not,
typically we filter for population = 1, unless the indicator relies on a single data source which it would be beneficial to align with the agency data.


Tables required:
IDI_Clean_$(refresh).[data].[snz_res_pop]
IDI_Clean_$(refresh).[data].[personal_detail]
IDI_Clean_$(refresh).[dol_clean].[movements]
IDI_Clean_$(refresh).[data].[apc_arp_spells]
IDI_Clean_$(refresh).[data].[address_notification]
[IDI_Metadata_$(refresh)].[data].[dep_index18_mb18]
[IDI_Metadata_$(refresh)].[data].[mb_higher_geo]

Notes:



*/

/*PARAMETERS

SQLCMD only (Activate by clicking Query->SQLCMD Mode)*/

--Update with project, current refresh AND current NZDep version--

:setvar project "MAA20XX-XX" :setvar newmaster "Master_population_202410" :setvar refresh "202410" :setvar NZDep "dep_index23_mb23"


/* Create frame */


/*	Logic: we create a view [IDI_UserCode].[DL-$(project)].[mt_quarters] that sets out our time periods AND the name for each
	We join this onto the population file, to get the frame for each period.*/


-- When a new qtr is added, drop the ealiest quarter.

USE IDI_UserCode
GO

DROP
VIEW IF EXISTS [DL-$(project)].[mt_quarters];
GO

CREATE
VIEW [DL-$(project)].[mt_quarters] AS(
    SELECT *
    FROM(
        VALUES('2020-07-01', '2020-09-30', '2020Q3')
            , ('2020-10-01', '2020-12-31', '2020Q4')
            , ('2021-01-01', '2021-03-31', '2021Q1')
            , ('2021-04-01', '2021-06-30', '2021Q2')
            , ('2021-07-01', '2021-09-30', '2021Q3')
            , ('2021-10-01', '2021-12-31', '2021Q4')
            , ('2022-01-01', '2022-03-31', '2022Q1')
            , ('2022-04-01', '2022-06-30', '2022Q2')
            , ('2022-07-01', '2022-09-30', '2022Q3')
            , ('2022-10-01', '2022-12-31', '2022Q4')
            , ('2023-01-01', '2023-03-31', '2023Q1')
            , ('2023-04-01', '2023-06-30', '2023Q2')
            , ('2023-07-01', '2023-09-30', '2023Q3')
            , ('2023-10-01', '2023-12-31', '2023Q4')
            , ('2024-01-01', '2024-03-31', '2024Q1')
            , ('2024-04-01', '2024-06-30', '2024Q2')
            , ('2024-07-01', '2024-09-30', '2024Q3')
            , ('2024-10-01', '2024-12-31', '2024Q4')

    )AS qrt([startdate], [enddate], [quarter])
);
GO


-------------------------------------------------------- Chunk: Population definition --------------------------------------------------------

DROP TABLE IF EXISTS #frame

SELECT DISTINCT a.snz_uid
    , [snz_birth_date_proxy] AS dob
    , DATEFROMPARTS([snz_deceased_year_nbr],[snz_deceased_month_nbr],1) AS dod
    , snz_spine_ind
INTO #frame
FROM(
--add in new births missing from res_pop AND apc tables
    SELECT DISTINCT snz_uid
    FROM IDI_Clean_$(refresh).[data].[personal_detail]
    WHERE snz_birth_year_nbr >= 1997
    AND snz_person_ind = 1 -- these are meant to be missing from res_pop AND apc, more coming from DIA, maybe remove IR people 
    UNION
    SELECT DISTINCT snz_uid
    FROM IDI_Clean_$(refresh).[data].[snz_res_pop]
    UNION
    SELECT DISTINCT snz_uid
    FROM IDI_Clean_$(refresh).[dol_clean].[movements] --some errors in movements where arrival / departure side by side, will result in us including people here for less time
    UNION
    SELECT DISTINCT snz_uid
    FROM IDI_Clean_$(refresh).data.apc_arp_spells
)AS a
LEFT JOIN IDI_Clean_$(refresh).[data].[personal_detail] AS b
ON a.snz_uid = b.snz_uid
WHERE b.snz_person_ind = 1

/*Movements - create movement spells

This identifies all border crossings - we want arrival AND departure spells to see if someone was or wasnt in the country in our period of interest.

This earliest data available is 1997

There appear to be some events missing - for example someone arrives in the country AND their next border crossing is also arriving in the country, 
without an interviening departure record*/

DROP TABLE IF EXISTS #movements
SELECT [snz_uid]
    , [dol_mov_movement_ind]
    , [dol_mov_carrier_datetime]
    , [dol_mov_carrier_date]
    , dol_mov_nationality_code
    , dol_mov_visa_type_code
    , RANK() OVER (PARTITION BY snz_uid ORDER BY [dol_mov_carrier_datetime]) AS indx1
    , RANK() OVER (PARTITION BY snz_uid ORDER BY [dol_mov_carrier_datetime] DESC) AS indx2
INTO #movements
FROM IDI_Clean_$(refresh).[dol_clean].[movements]

DROP TABLE IF EXISTS #movements_2
SELECT snz_uid
    , dol_mov_carrier_date
    , [dol_mov_carrier_datetime]
    , [dol_mov_movement_ind]
    , IIF([dol_mov_movement_ind]='A','indx1','indx1-1') AS indx --creates matching indx values for A AND then D
    , indx2
INTO #movements_2
FROM #movements

--The following creates every combination of indx AND snz_uid

DROP TABLE IF EXISTS #move_indx
SELECT DISTINCT snz_uid
    , indx
INTO #move_indx
FROM #movements_2 

--The following creates spells (NB there are some people with no dob AND hence no start spell date for their first spell)

DROP TABLE IF EXISTS #spells
SELECT z.snz_uid
    , a.dol_mov_carrier_date AS arrival_date
    , b.dol_mov_carrier_date AS departure_date
    , z.indx
    , b.indx2
INTO #spells
FROM #move_indx AS z
LEFT JOIN(
    SELECT *
    FROM #movements_2
    WHERE [dol_mov_movement_ind] = 'A'
)AS a
ON z.snz_uid = a.snz_uid
AND z.indx = a.indx
LEFT JOIN(
    SELECT *
    FROM #movements_2
    WHERE [dol_mov_movement_ind] = 'D'
)AS b
ON z.snz_uid = b.snz_uid
AND z.indx = b.indx

 --The following fills in missing border crossings 

DROP TABLE IF EXISTS #spells_2

SELECT a.snz_uid
    , CASE WHEN a.indx>0 AND a.arrival_date IS NULL THEN a.departure_date
		  WHEN a.indx>0 AND a.arrival_date IS NOT NULL THEN a.arrival_date
		  ELSE a.arrival_date END AS arrival_date
    , CASE WHEN a.indx2>1 AND a.departure_date IS NULL THEN a.arrival_date
		  WHEN a.indx2>1 AND a.departure_date IS NOT NULL THEN a.departure_date
		  ELSE a.departure_date END AS departure_date
    , indx
    , indx2
INTO #spells_2
FROM #spells AS a
ORDER BY snz_uid
    , indx

-- combines the first frame AND movement spells to create initial population

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project)].res_pop_$(refresh)

SELECT a.*
    , b.indx
    , CASE WHEN dob IS NOT NULL AND b.arrival_date IS NULL THEN dob
		  ELSE b.arrival_date END AS start_date
    , CASE WHEN dod IS NOT NULL AND b.departure_date IS NULL THEN dod 
		  WHEN dod IS NULL AND b.departure_date IS NULL THEN DATEFROMPARTS (9999,1,1)
		  ELSE b.departure_date END AS end_date
INTO [IDI_Sandpit].[DL-$(project)].res_pop_$(refresh)
FROM(
    SELECT *
    FROM #frame
)AS a
LEFT JOIN #spells_2 AS b
ON a.snz_uid = b.snz_uid

DROP TABLE IF EXISTS #spells_2
DROP TABLE IF EXISTS #frame
DROP TABLE IF EXISTS #movements
DROP TABLE IF EXISTS #movements_2
DROP TABLE IF EXISTS #spells
DROP TABLE IF EXISTS #move_indx
----------------------------------------------------------------------------------------------------------------

-- create time series

DROP TABLE IF EXISTS #mt_frame

SELECT DISTINCT pop.[snz_uid]
    , pop.[dob]
    , IIF(pop.[snz_spine_ind] = 1,1,NULL) AS [POPULATION]
    , quart.[quarter]
    , quart.[startdate]
    , quart.[enddate]
    , FLOOR(DATEDIFF(MONTH,pop.[dob],quart.[enddate])/12) AS [AGE] -- Age at end of quarter
INTO #mt_frame
FROM [IDI_Sandpit].[DL-$(project)].res_pop_$(refresh)pop
INNER JOIN [IDI_UserCode].[DL-$(project)].[mt_quarters] quart
ON pop.[start_date] <= quart.[enddate]
AND pop.[end_date] >= quart.[startdate]


-------------------------------------------------------- Chunk: demographics --------------------------------------------------------
DROP TABLE IF EXISTS #mt_frame_demo

SELECT frame.*
    , CASE WHEN AGE <= 4 THEN 1
			  WHEN AGE >= 5 AND AGE <= 14 THEN 2
			  WHEN AGE >= 15 AND AGE <= 24 THEN 3
			  WHEN AGE >= 25 AND AGE <= 44 THEN 4
			  WHEN AGE >= 45 AND AGE <= 64 THEN 5
			  WHEN AGE >=65 THEN 6
			  ELSE 99 END AS AGE_RDP
    , CASE WHEN dat.[snz_sex_gender_code] IS NULL THEN -99 ELSE dat.[snz_sex_gender_code] END AS sex_gender
    , CASE WHEN dat.[snz_sex_gender_code] IS NULL THEN -99 WHEN dat.[snz_sex_gender_code] = 3 THEN -99 ELSE dat.[snz_sex_gender_code] END AS sex_no_gender -- adding 'no_gender' as [snz_sex_gender_code] doesn't include an 'Another gender' category, thus we treat it as sex
    , CASE WHEN dat.[snz_ethnicity_grp1_nbr] = 1 THEN 1 ELSE NULL END AS european
    , CASE WHEN dat.[snz_ethnicity_grp2_nbr] = 1 THEN 1 ELSE NULL END AS maori
    , CASE WHEN dat.[snz_ethnicity_grp3_nbr] = 1 THEN 1 ELSE NULL END AS pacific
    , CASE WHEN dat.[snz_ethnicity_grp4_nbr] = 1 THEN 1 ELSE NULL END AS asian
    , CASE WHEN dat.[snz_ethnicity_grp5_nbr] = 1 THEN 1 ELSE NULL END AS MELAA
    , CASE WHEN dat.[snz_ethnicity_grp6_nbr] = 1 THEN 1 ELSE NULL END AS other
    , CASE WHEN (dat.[snz_ethnicity_grp1_nbr] != 1 AND
		dat.[snz_ethnicity_grp2_nbr] != 1 AND
		dat.[snz_ethnicity_grp3_nbr] != 1 AND
		dat.[snz_ethnicity_grp4_nbr] != 1 AND
		dat.[snz_ethnicity_grp5_nbr] != 1 AND
		dat.[snz_ethnicity_grp6_nbr] != 1) THEN 1 ELSE NULL END AS unknown_eth
INTO #mt_frame_demo
FROM #mt_frame frame
LEFT JOIN IDI_Clean_$(refresh).[data].[personal_detail] dat
ON frame.snz_uid = dat.snz_uid




-------------------------------------------------------- Chunk: geographies --------------------------------------------------------
/* Option 1: store higher level geographies separately */

DROP TABLE IF EXISTS #mt_frame

-- END OF QUARTER ADDRESSES
DROP TABLE IF EXISTS #frame_geographies;
WITH tmp AS(
    SELECT [snz_uid]
        , [snz_idi_address_register_uid] AS end_qrtr_address
        , ant_meshblock_code
        , ant_notification_date
        , ant_replacement_date
    FROM IDI_Clean_$(refresh).[data].[address_notification]
    WHERE [ant_replacement_date] >= (
        SELECT MIN(enddate)
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    )
    AND [ant_notification_date] <= (
        SELECT MAX(enddate)
        FROM [IDI_UserCode].[DL-MAA2023-55].[mt_quarters]
    )
    AND [ant_meshblock_code] IS NOT NULL
)

SELECT frame.*
    , dom.end_qrtr_address
    , dom.ant_meshblock_code
INTO #frame_geographies
FROM #mt_frame_demo frame
LEFT JOIN(
    SELECT *
    FROM tmp
)AS dom
ON frame.snz_uid = dom.snz_uid
AND frame.[enddate] >= dom.[ant_notification_date]
AND frame.[enddate] <= dom.[ant_replacement_date]

/* Create an address table. This includes: snz_idi_address_register_uid 
Some people do not have an address in the address notification table
,so expect there to be some NULLs coming through in #frame_geographies.
In general,the vast majority have an address, so we have enough to cover the population.

--NOTE: Need to update the concordance mapping each refresh if/when new meshblock or NZDep mapping becomes available-- */

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project).[address_table]

SELECT addresses.end_qrtr_address AS [snz_idi_address_register_uid]
    , addresses.[ant_meshblock_code]
    , b23.[IUR2023_V1_00] -- Urban/Rural classification
    , b23.[IUR2023_V1_00_NAME]
    , CAST(b23.[REGC2023_V1_00] AS INT) AS REGC -- Regional Council
    , b23.[REGC2023_V1_00_NAME]
    , CAST(b23.[TALB2023_V1_00] AS INT) AS TALB -- Territorial Authority or Local Board
    , b23.[TA2023_V1_00_NAME]
    , CAST(b23.[SA22023_V1_00] AS INT) AS SA2 -- Statistical Area 2
    , b23.[SA22023_V1_00_NAME]
    , CAST(b23.[SA32023_V1_00] AS INT) AS SA3 -- Statistical Area 3
    , b23.[SA32023_V1_00_NAME]
    , CASE WHEN b23.IUR2023_V1_00 IN (21,22) THEN b23.[TALB2023_V1_00] ELSE b23.UR2023_V1_00 END AS urban_rural
    , CASE WHEN b23.[IUR2023_V1_00_NAME] IN ('Rural settlement', 'Rural other', 'Oceanic', 'Inlet', 'Inland water') THEN 2
		  WHEN b23.[IUR2023_V1_00_NAME] IS NULL THEN -99
		  ELSE 1 END AS urban_rural_ind
    , CEILING(CASE WHEN dep.[NZDep2023] = '' THEN 0 ELSE dep.[NZDep2023] END /5.0) AS [NZDep]
INTO [IDI_Sandpit].[DL-$(project)].[address_table]
FROM(
    SELECT DISTINCT end_qrtr_address
        , [ant_meshblock_code]
    FROM #frame_geographies
)addresses
INNER JOIN [IDI_Metadata_$(refresh)].[data].[meshblock_concordance] AS conc24
ON conc24.[MB2024_code] = addresses.[ant_meshblock_code]
LEFT JOIN [IDI_Metadata_$(refresh)].[data].[mb_higher_geo] AS b23
ON conc24.[MB2023_code] = b23.[MB2023_V1_00]
LEFT JOIN(
    SELECT DISTINCT [MB2023_code]
        , [NZDep2023]
    FROM [IDI_Metadata_$(refresh)].[data].[$(NZDep)]
)dep
ON conc24.[MB2023_code] = dep.[MB2023_code]


/*** Creating the population master table ***/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh)

SELECT *
INTO [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh)
FROM #frame_geographies

DROP TABLE IF EXISTS #frame_geographies;

ALTER TABLE [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh)
DROP COLUMN IF EXISTS REGC
    , COLUMN IF EXISTS TALB
    , COLUMN IF EXISTS SA2
    , COLUMN IF EXISTS urban_rural_ind
    , COLUMN IF EXISTS NZDep;

ALTER TABLE [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh) ADD REGC SMALLINT
    , TALB INT
    , SA2 INT
    , urban_rural_ind INT
    , NZDep INT;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh)
SET REGC = CASE WHEN addr.[REGC] IS NULL THEN -99 ELSE addr.[REGC] END
    , TALB = CASE WHEN addr.[TALB] IS NULL THEN -99 ELSE addr.[TALB] END
    , SA2 = CASE WHEN addr.[SA2] IS NULL THEN -99 ELSE addr.[SA2] END
    , urban_rural_ind = CASE WHEN addr.[urban_rural_ind] IS NULL THEN -99 ELSE addr.[urban_rural_ind] END
    , NZDep = CASE WHEN addr.[NZDep] IS NULL OR addr.[NZDep] = 0 THEN -99 ELSE addr.[NZDep] END

FROM [IDI_Sandpit].[DL-$(project)].[address_table] addr 	WHERE [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh).ant_meshblock_code = addr.ant_meshblock_code


	-- Compress table to save space --


ALTER TABLE [IDI_Sandpit].[DL-$(project)].Master_population_$(refresh) REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO

	-- Drop inital popultion table --

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-$(project)].res_pop_$(refresh);



