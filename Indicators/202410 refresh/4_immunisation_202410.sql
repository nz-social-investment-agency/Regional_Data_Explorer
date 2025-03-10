/**************************************************************************************************
Title: 8 month immunisation
Author: Ashleigh Arendt
Peer Review: Charlotte Rose

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies:
- [IDI_Clean_$(refresh)].[moh_clean].[nir]
Outputs:
- imm_8_month
- imm_60_month

Description:
Flags for whether individuals received their full set of vaccinations at ages 8MO and 60MO according to the Immunisation Schedule. 
These flags are applied to people who turned that milestone age within a year of the end of quarter date i.e.:
- 1 = if they turned 8 MO 1 year before enddate for a given quarter and also were flagged as receiving a full immunisation

Intended purpose:
To calculate trends in immunisation rates for early years populations.

Notes:
	There looks to be a potential delay with data becoming available in the dataset.
		archive		most recent complete record (by birth month/year)
		$(refresh)		2022-12
		202406		2022-12
		202310		2021-12
		202306		2021-12
		202303		2021-12
		202210		2021-06
		202206		2021-06
		202203		2019-06

for $(refresh) refresh the latest complete imm data will be from 2023Q2, as last complete data is children with birth date 202212, so 8mo in 202308

Datasets have varying update / refresh times, since we are using the personal details table which combines many of them, 
we may get more children with ages under 8 months than Health have access to?

-- Standard is to exclude PCV immunisation:
This is only relevant for children born up to 2011 in the health data for 8MO vaccinations, and there's no difference for 60 Months. 
We include here but does not effect the numbers. Note from MoH: "The NIR has been in use since 2006. in 2008 PCV was added to the imm scedule. 
To phase this in gently a second measure was created (all complete exc. PCV) the 2 flags meant that MoH has visibility over who was fully 
immunised on the new schedule compared to the old schedule."

For people born after 2011, there are no instances of differing immunisation schedules, thus for our use (looking at people born after 2014) we have excluded the excl_PCV measure entirelty.


Parameters & Present values:
  Current refresh = $(refresh)
  Prefix = imm_
  Project schema = DL-$(project)

Issues:

History (reverse order):
2024-01-26 AA



**************************************************************************************************/
 --check max date--

 --SELECT a.moh_nir_birth_year_nbr
	--,a.moh_nir_birth_month_nbr
	--,COUNT(snz_uid)
 --FROM [IDI_Clean_$(refresh)].[moh_clean].[nir] a
 --GROUP BY a.moh_nir_birth_year_nbr,a.moh_nir_birth_month_nbr
 --Order by a.moh_nir_birth_year_nbr desc,a.moh_nir_birth_month_nbr desc

 /*PARAMETERS

SQLCMD only (Activate by clicking Query->SQLCMD Mode)*/

--Update with project and current refresh--

:setvar project "MAA20XX-XX" :setvar newmaster "Master_population_$(refresh)" :setvar refresh "$(refresh)"



/* remove */
DROP TABLE IF EXISTS #temp

/* create */
SELECT snz_uid
    , CASE WHEN [moh_nir_imm_stat_8_month_ind] = 1 THEN 1 
			WHEN [moh_nir_imm_stat_8_month_ind] = 0 THEN 0
			ELSE NULL END AS imm_8_month
    , CASE WHEN [moh_nir_imm_stat_60_month_ind] = 1 THEN 1 
			WHEN [moh_nir_imm_stat_60_month_ind] = 0 THEN 0
			ELSE NULL END AS imm_60_month
INTO #temp
FROM [IDI_Clean_$(refresh)].[moh_clean].[nir]

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
DROP COLUMN IF EXISTS imm_8_month
    , COLUMN IF EXISTS imm_60_month; 

ALTER TABLE [IDI_Sandpit].[DL-$(project)].[$(newmaster)] ADD imm_8_month tinyint
    , imm_60_month tinyint;
GO

UPDATE [IDI_Sandpit].[DL-$(project)].[$(newmaster)]
SET imm_8_month = CASE WHEN imm.imm_8_month = 1 AND AGE_8MO = 1 THEN 1 ELSE NULL END
    ,  -- setting condition that they are also part of POPULATION_8MO (they turned 8MO in the last year)
 imm_60_month = CASE WHEN imm.imm_60_month = 1 AND AGE_5YO = 1 THEN 1 ELSE NULL END -- setting condition that they are also part of POPULATION_5YO (they turned 5 in the last year)

FROM #temp imm
WHERE [IDI_Sandpit].[DL-$(project)].[$(newmaster)].snz_uid = imm.snz_uid

