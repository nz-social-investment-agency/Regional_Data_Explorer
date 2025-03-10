/*********************************************
Title: B4SC
Author: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202410].[moh_clean].[b4sc]

Outputs:
Outputs include:
-- No record of check performed before 5
-- Check performed before 5
-- Check performed, evidence of no referrals for all tests
-- Check performed, evidence of referral for one of the tests
-- Check performed, no data for referral or otherwise

Description:
This code uses data on Ministry of Health's B4 School Checks (B4SC) to identify children who have received their B4SC check before they turn 5. 
These tests are across four different areas: dental, vision, hearing & growth, then two additional questionnaires are included: the Strengths & Difficulties Quaestionnaire and the Parental Evaluation of Development Score. 
This code is adapted from Oranga Tamariki definitions, with further advise from Sheetalpreet Singh <sheetalpreet.singh@health.govt.nz> from Te Whatu Ora.

Intended purpose:
To identify populations who are receiving their before school check, and whether they receive a referral for their check and get an indication of any future outcomes.

Notes:
There looks to be a potential delay with data becoming available in the dataset.
		archive		most recent complete record (by check dates)
		202410		2023-07
		202403		2023-07
		202310		2022-07
		202306		2022-07
		202303		2022-07
		202210		2021-07
		202206		2021-07
		202203		2021-07

Max qtr of complete data id 2023Q2 as max date of complete data is July 2023 (for all check types)

-- Ages are approximate as we only have month not day of birth, so we check that the check occured before or on the day of the first month following their 5th birthday
-- The check date is sourced from 5 different dates in priority order: check_date (general date for a check), vision_date,hearing_date,growth_date, dental_date, sdq_date, ped_date
-- Referral logic:
	When someone has had a referral in any of the four tests, they are counted as a referral
	If they have evidence of no referral across all of the tests then they are counted as a non-referral
	Otherwise, we deem that there is not enough evidence to categorise them as they may have had a referral in one area that wasn't registered

-- Latest check date is July 2022
-- B4SC started national roll out in 2008, earliest available data is 2008-01-27, however in the data it appears the monthly figures don't pick up until March 2009
-- If our earliest date is 2020-04-01, then the oldest child who could have had b4sc would need to have turned 5 as of March 2010, so the oldest would be 15 years old in 2020-04-01
-- Comparison rates use all children in the denominator, 'in theory, all 4YO are eligible to receive a B4SC', DHB's send invitations to all parents with 4YO's enrolled with a PHO
-- The quality issues seem specific to the SDQ and obesity measures: quality issues with the SDQ tend to relate to teacher responses, so following advise from health we limit to parent responses
-- Coverage rates increase between 2009-2013 to reach over 90%

-- Ambiguity in whether to include 'Advice Given' or 'Declines' as non-referrals or unknowns
-- We chose non-referral for the former as health said usually this is guidance given by the practitioner which doesn't indicate they have serious issues
-- We chose declines for the latter as there's not enough informaiton to tell the outcome of the child


-- These B4SC are soon to change to be held between the ages of 2-3.

Max qtr of complete data is 2023Q3 as max date of complete data is July 2023 (for all check types)

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_b4sc
  Project schema = [DL-MAA2023-55]

Issues:
- Many unknowns, sometimes check_dates occur with no information about the specific tests
- latest date for 202410 refresh in 202307

History (reverse order):
2024-11-19 AA


Run time: 
- <1 min

**********************************************/
--check max date--

--SELECT a.moh_bsc_check_date
--	,COUNT(snz_uid)
--FROM [IDI_Clean_202410].[moh_clean].[b4sc] a 
--GROUP BY a.moh_bsc_check_date
--ORDER BY a.moh_bsc_check_date desc

DROP TABLE IF EXISTS #b4sc_health;
SELECT [SNZ_UID]
    , MOH_BSC_CHECK_DATE AS CHECK_DATE
    , MOH_BSC_vision_DATE AS vision_DATE
    , MOH_BSC_hearing_DATE AS hearing_DATE
    , MOH_BSC_growth_DATE AS growth_DATE
    , MOH_BSC_dental_DATE AS dental_DATE
    , moh_bsc_sdqp_date AS sdqp_DATE
    , moh_bsc_peds_date AS peds_DATE
    , MOH_BSC_DENTAL_DECAY_NBR
    , 

		/*DENTAL SCORE
		Children with a Lift the Lip (oral health) score of 2-6 are referred (see the Indicators for the Well Child / Tamariki Ora Quality Improvement Framework*/
		-- for health performance reporting they identify both those who received a dental score 2-6 AND were 'Referred' - advice from Sheetpreet Singh on 29-1-24
		-- advice from health to treat those needing a referral but with non-referral outcome texts as non-referrals
		CASE WHEN MOH_BSC_DENTAL_DECAY_NBR >= 2 AND MOH_BSC_DENTAL_DECAY_NBR <= 6 AND moh_bsc_dental_outcome_text IN ('Referred', 'Enrolled AND Referred', 'Referral Declined', 'Under care') THEN 1
			WHEN MOH_BSC_DENTAL_DECAY_NBR = 1 AND moh_bsc_dental_outcome_text IN ('NOT Referred', 'Advice Given', 'Enrolled') THEN 0
			WHEN MOH_BSC_DENTAL_DECAY_NBR IS NULL THEN NULL
			ELSE NULL
		END AS B4SC_DENTAL_FLAG
    , 

		/*Vision outcome */
		-- Decision to add in vision scores from health for referrals - advice from Sheetpreet Singh on 29-1-24
		CASE WHEN MOH_BSC_VISION_OUTCOME_TEXT IN ('Referred', 'Under care') AND 
			([moh_bsc_vision_score_l_text] IN ('6_12', '6_18', '6_24+') OR [moh_bsc_vision_score_l_text] IS NULL OR 
			[moh_bsc_vision_score_r_text] IN ('6_12', '6_18', '6_24+') OR [moh_bsc_vision_score_r_text] IS NULL) THEN 1 
			 WHEN MOH_BSC_VISION_OUTCOME_TEXT = 'Pass Bilaterally' THEN 0
			 WHEN MOH_BSC_VISION_OUTCOME_TEXT = 'Rescreen' OR MOH_BSC_VISION_OUTCOME_TEXT = 'Decline' THEN NULL
			 ELSE NULL
		END AS B4SC_VISION_FLAG
    , 


		/*Hearing outcome */
		-- Decision to add in hearing scores from health for referrals - advice from Sheetpreet Singh on 29-1-24

		CASE WHEN MOH_BSC_HEARING_OUTCOME_TEXT IN ('Referred', 'Under care') AND 
			([moh_bsc_hearing_audiomtry_l_text] IN ('Fail') OR [moh_bsc_hearing_audiomtry_l_text] IS NULL OR 
			[moh_bsc_hearing_audiomtry_r_text] IN ('Fail') OR [moh_bsc_hearing_audiomtry_r_text] IS NULL) THEN 1
			 WHEN MOH_BSC_HEARING_OUTCOME_TEXT = 'Pass Bilaterally'  THEN 0
			 WHEN MOH_BSC_HEARING_OUTCOME_TEXT = 'Rescreen' OR MOH_BSC_HEARING_OUTCOME_TEXT = 'Decline' THEN NULL
			 ELSE NULL
		END AS B4SC_HEARING_FLAG
    , 

		/*Growth (incl. BMI) - Children whose BMI is over 21 are referred (see pg 43 of B4SC practitioners handbook)
		  IDI does not contain information on BMI so recommended to just take outcome text*/
		CASE WHEN MOH_BSC_GROWTH_OUTCOME_TEXT IN ('Referred', 'Under Care', 'Referral Declined') THEN 1 
			 WHEN MOH_BSC_GROWTH_OUTCOME_TEXT IN ('NOT Referred', 'Advice Given') THEN 0
			 WHEN MOH_BSC_GROWTH_OUTCOME_TEXT = 'Declined' THEN NULL
			 ELSE NULL
		END AS B4SC_GROWTH_FLAG
    , 

		/*Strength and Difficulties Questionnaire */
		CASE WHEN ([moh_bsc_sdqp_conduct_nbr] + [moh_bsc_sdqp_emotional_nbr] + [moh_bsc_sdqp_hyperactive_nbr] + [moh_bsc_sdqp_peer_prob_nbr] >= 17)
		 AND [moh_bsc_sdqp_outcome_text] IN ('Referred', 'Under Care', 'Referral Declined') THEN 1
			WHEN [moh_bsc_sdqp_outcome_text] IN ('NOT Referred', 'Advice Given') THEN 0
			ELSE NULL
		END AS B4SC_SDQP_FLAG
    , 

		/*Parental Evaluation of Development Score */
		CASE WHEN [moh_bsc_peds_pathway_code] IN ('A') AND [moh_bsc_peds_outcome_text] IN ('Referred', 'Completed - Referral Declined', 'Under Care') THEN 1
			WHEN [moh_bsc_peds_outcome_text] IN ('NOT Referred', 'Advice Given') THEN 0
			ELSE NULL
		END AS B4SC_PED_FLAG

INTO #b4sc_health
FROM [IDI_Clean_202410].[moh_clean].[b4sc]


DROP TABLE IF EXISTS #b4sc_health_flags;
SELECT SNZ_UID
    , CASE WHEN (B4SC_DENTAL_FLAG = 1 OR B4SC_HEARING_FLAG=1 OR B4SC_VISION_FLAG=1 OR B4SC_GROWTH_FLAG=1 OR B4SC_SDQP_FLAG=1 OR B4SC_PED_FLAG=1) THEN 1
			WHEN (B4SC_DENTAL_FLAG = 0 AND B4SC_HEARING_FLAG=0 AND B4SC_VISION_FLAG=0 AND B4SC_GROWTH_FLAG=0 AND B4SC_SDQP_FLAG=0 AND B4SC_PED_FLAG=0) THEN 0
			ELSE -99 END AS B4SC_referral
    , COALESCE(check_date,vision_date,hearing_date,growth_date,dental_date,sdqp_DATE,peds_DATE) AS general_date
    , CASE WHEN COALESCE(check_date,vision_date,hearing_date,growth_date, dental_date, sdqp_DATE, peds_DATE) IS NULL THEN 0 ELSE 1 END AS check_flag

INTO #b4sc_health_flags
FROM #b4sc_health;

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
DROP COLUMN IF EXISTS B4SC__check_referral
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410] ADD B4SC__check_referral int;
GO

UPDATE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410]
SET B4SC__check_referral = CASE WHEN h.B4SC_referral = 1 THEN 1 ELSE NULL END

FROM #b4sc_health_flags h
WHERE [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].snz_uid = h.snz_uid
AND DATEADD(YEAR, 5, (DATEADD(mm, DATEDIFF(m,0, [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[DOB]) + 1, 0))) >= h.general_date
AND [IDI_Sandpit].[DL-MAA2023-55].[master_table_202410].[AGE] = 5;
