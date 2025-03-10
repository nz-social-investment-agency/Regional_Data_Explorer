/*

This script uses the ages (RDP_AGE) in the master population table to create a flag as to whether someone is in an age group during any given quater.

These 'bespoke' ages are used to filter indicators which are specific to a life stage, or, as denominators used to calculate percentages.

For example ECE data looks at two age groups within the 'RDP_AGE' band of 0-4, so we use AGE_0_2 and AGE_3_4 to group the ECE data,
and use these age bands from the full population to calculate the % of children attedning ECE. 

Note: some of the agebands are not currently being used, so have been commented out */

---Create all bespoke age bands in master--



ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP -- Bespoke 'turned xx' ages --
																	 --COLUMN IF EXISTS AGE_8MO, -- //not currently using//
 COLUMN IF EXISTS AGE_5YO
    , COLUMN IF EXISTS AGE_25YO
																	--,COLUMN IF EXISTS AGE_45YO //not currently using//
    , COLUMN IF EXISTS AGE_65YO
    , COLUMN IF EXISTS AGE_0_2YO
    , COLUMN IF EXISTS AGE_3_4YO
																	--,COLUMN IF EXISTS AGE_2YO //not currently using//

																	-- 15 and over --
    , COLUMN IF EXISTS AGE_GE15

																	--Working age--
																	--,COLUMN IF EXISTS AGE_Working //not currently using//

																	-- School ages --
    , COLUMN IF EXISTS AGE_compulsory_school
    , COLUMN IF EXISTS AGE_school_aged

																	-- Agebands to match MSD benefits data --
    , COLUMN IF EXISTS AGE_18_24
    , COLUMN IF EXISTS AGE_25_39
    , COLUMN IF EXISTS AGE_40_54
    , COLUMN IF EXISTS AGE_55_64;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD -- Bespoke 'turned xx' ages --
																	-- AGE_8MO BIT,-- //not currently using//
 AGE_5YO BIT
    , AGE_8MO BIT
    , AGE_25YO BIT
																	--,AGE_45YO BIT //not currently using//
    , AGE_65YO BIT
    , AGE_0_2YO BIT
    , AGE_3_4YO BIT
																	--,AGE_2YO BIT //not currently using//

																	-- 15 and over --
    , AGE_GE15 BIT

																	--Working age--
																	--,AGE_Working BIT //not currently using//

																	-- School ages --
    , AGE_compulsory_school BIT
    , AGE_school_aged BIT

																	-- Agebands to match MSD benefits data --
    , AGE_18_24 BIT
    , AGE_25_39 BIT
    , AGE_40_54 BIT
    , AGE_55_64 BIT;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET

-- Bespoke 'turned xx' ages --

	--AGE_8MO = CASE WHEN DATEADD(MONTH, 8, [DOB]) <= [enddate]
	--					AND DATEADD(MONTH, 8, [DOB]) >= DATEADD(DAY, 1, DATEADD(YEAR, -1, [enddate]))
	--					AND [POPULATION] = 1 THEN 1
	--					ELSE NULL END, //not currently using//

 AGE_5YO = CASE WHEN AGE = 5 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_25YO = CASE WHEN AGE = 25 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 

	--AGE_45YO = CASE WHEN AGE = 45 AND POPULATION = 1 THEN 1 ELSE NULL END, //not currently using//

 AGE_65YO = CASE WHEN AGE = 65 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_0_2YO = CASE WHEN AGE IN (0,1,2) AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_3_4YO = CASE WHEN AGE IN (3,4) AND POPULATION = 1 THEN 1 ELSE NULL END
    , 

	--AGE_2YO = CASE WHEN AGE = 2 AND POPULATION = 1 THEN 1 ELSE NULL END, //not currently using//

-- 15 and over --

 AGE_GE15 = CASE WHEN AGE > 14 THEN 1 ELSE NULL END
    , 

--Working age--

	--AGE_working = CASE WHEN AGE BETWEEN 15 AND 64 THEN 1 ELSE NULL END, //not currently using//

-- School ages --

 AGE_compulsory_school = CASE WHEN AGE BETWEEN 6 AND 15 THEN 1 ELSE NULL END
    , --for NETS attendance services as NETS only looks at schildren who legally have to be at school

 AGE_school_aged = CASE WHEN AGE BETWEEN 5 AND 18 THEN 1 ELSE NULL END
    ,  --for Unjustified Absence (UA) attendance services, UA usually only looks at children who legally have to be at school, but can look at older children (low priority)

-- Agebands to match MSD benefits data --

 AGE_18_24 = CASE WHEN AGE BETWEEN 18 AND 24 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_25_39 = CASE WHEN AGE BETWEEN 25 AND 39 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_40_54 = CASE WHEN AGE BETWEEN 40 AND 54 AND POPULATION = 1 THEN 1 ELSE NULL END
    , 
 AGE_55_64 = CASE WHEN AGE BETWEEN 55 AND 64 AND POPULATION = 1 THEN 1 ELSE NULL END
FROM [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410];


--------------------------------------------------------/* space saving - */-----------------------------------------------------------

--master should already be indexed

--CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ([snz_uid], [quarter])

--Please compress to save space--

--ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);

