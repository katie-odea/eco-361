clear all 

*Import health data and export to R for reshaping
import delimited using "data/PLACES__Local_Data_for_Better_Health__Census_Tract_Data_2020_release.csv"
drop year
drop statedesc
drop data_value_unit
drop data_value_footnote
drop geolocation
drop _merge
drop measure
drop category
drop low_confidence_limit
drop high_confidence_limit
drop totalpopulation
save cdc-health-data, replace

*Import reshaped health data
import delimited using "reshaped_brownfields_health.csv"
tostring locationname, gen(census_tract) format("%25.0f")
gen zero = 0
tostring zero, gen(zeroes) format("%12.0f")
preserve
keep if stateabbr == "AL" | stateabbr == "AZ" | stateabbr == "CA" | stateabbr == "CT" | stateabbr == "AK" | stateabbr == "AS" | stateabbr == "AR" | stateabbr == "CO"
rename census_tract censust
gen census_tract = zeroes + censust
drop censust
save cdc_first_states, replace
restore
drop if stateabbr == "AL" | stateabbr == "AZ" | stateabbr == "CA" | stateabbr == "CT" | stateabbr == "AK" | stateabbr == "AS" | stateabbr == "AR" | stateabbr == "CO"
append using cdc_first_states
drop zeroes zero locationname
save cdc-health-data, replace

*Import brownfields facility data
import delimited using "national_single/NATIONAL_SINGLE.CSV", clear
keep if (site_type_name == "BROWNFIELDS SITE") | (site_type_name == "POTENTIALLY CONTAMINATED SITE") | (site_type_name == "CONTAMINATED")
drop if missing(census_block_code)
tostring census_block_code, gen(census_block) format("%25.0f")
save brownfields-epa-facility-file, replace

*Clean data so that census block codes have a uniform number of digits
use brownfields-epa-facility-file, clear
gen zero = 0
tostring zero, gen(zeroes) format("%12.0f")
preserve
keep if state_code == "AL" | state_code == "AZ" | state_code == "CA" | state_code == "CT" | state_code == "AK" | state_code == "AS" | state_code == "AR" | state_code == "CO"
rename census_block censusb
gen census_block = zeroes + censusb
drop censusb
save epa_first_states, replace
restore
drop if state_code == "AL" | state_code == "AZ" | state_code == "CA" | state_code == "CT" | state_code == "AK" | state_code == "AS" | state_code == "AR" | state_code == "CO"
append using epa_first_states
drop zeroes zero census_block_code
save brownfields-epa-facility-file, replace

*Clean brownfields data so that census block code becomes census tract code 
gen census_tract = substr(census_block, 1, 11)
save brownfields-epa-facility-file, replace
 

*Clean brownfields data so that there is a variable for brownfields per tract
gen x=1
collapse (count) x, by(census_tract)
rename x brownfields_per_tract
save brownfields-epa-facility-file, replace

*Merge health and brownfields data
clear
use cdc-health-data
merge m:1 census_tract using brownfields-epa-facility-file
drop if _merge ==2
replace brownfields_per_tract = 0 if missing(brownfields_per_tract)
*Generate dummy variable for brownfields presence
gen brownfieldsdum = (brownfields_per_tract>0)
save merged-brownfields-health, replace

*Clean race/demographic data
clear
import delimited using "data/DECENNIALPL2020.P1_data_with_overlays_2021-11-04T115303.csv"
rename v1 GEO_ID
rename v3 total_pop 
rename v5 white
rename v6 black
drop if GEO_ID == "id"
drop if GEO_ID == "GEO_ID"
gen census_tract = substr(GEO_ID, 10, 20)
drop v4 v7 v8 v9 v10 v11 v12 v13 v14 v15 v16 v17 v18 v19 v20 v21 v22 v23 v24
drop v25 v26 v27 v28 v29 v30 v31 v32 v33 v34 v35 v36 v37 v38 v39 v40 v41 v42 v42 v44 v45 v43 v46 v47 v48 v49 v50 v51 v52 v53 v54 v55 v56 v57 v58 v59 v60 v61 v62 v63 v64 v65 v66 v67 v68 v69 v70 v71 v72 v73
drop v2
destring total_pop, replace
destring white, replace
destring black, replace
gen percent_white = white/total_pop
drop if missing(percent_white)
gen percent_black = black/total_pop
save percent_race, replace

*Merge race data with existing data
use merged-brownfields-health
merge m:1 census_tract using percent_race
keep if _merge==3
save brownfields_health_race, replace

*Generate key remaining variables for majority black, then perform regressions and export to tables
gen percentblack = percent_black*100
gen majority_black = percentblack>50
drop _merge
gen brownfieldsdum_majorityblack = brownfieldsdum*majority_black
eststo: reg cancer brownfieldsdum_majorityblack brownfieldsdum majority_black access_to_healthcare obesity, robust
eststo: reg bphigh brownfieldsdum_majorityblack brownfieldsdum majority_black access_to_healthcare obesity, robust
eststo: reg stroke brownfieldsdum_majorityblack brownfieldsdum majority_black access_to_healthcare obesity, robust
esttab, label title(Effect of Brownfields and Race on Health Outcomes at the Census Tract Level) nonumbers mtitles("Cancer" "High BP" "Stroke")
*summary/descriptive statistics
tab brownfieldsdum
tab brownfieldsdum_majorityblack 
tab majority_black
asdoc sum brownfieldsdum_majorityblack brownfieldsdum majority_black cancer stroke bphigh access_to_healthcare obesity
asdoc esttab







