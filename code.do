**********************************************************
*This files solves the coding task given by the Econ RA Guide, available publicly on Github at https://raguide.github.io/new_email.
**********************************************************


************************************************************
***********1- Constructing Merged Panel Data***********
************************************************************


*HOSPITAL DATA- has 17 variables and 177 observations. So 177 hospitals over 16 years (2000-2015)
import delimited "/Users/vishakhasingla/Downloads/hospital.csv",clear

describe
su

count if missing(hospital, cases0, cases1 ,cases2, cases3, cases4 ,cases5, cases6 ,cases7, cases8 ,cases9 ,cases10, cases11, cases12 ,cases13 ,cases14 ,cases15)
duplicates report

*no missing or duplicate rows found.

*making the hospital file ready for merging

*extracting the city name from the hospital name
gen city = word(hospital, 1) + " " + word(hospital, 2)


*reshaping into long format
reshape long cases, i(hospital) j(year)

******************************************************************************

*Data                               Wide   ->   Long
*-----------------------------------------------------------------------------
*Number of observations              177   ->   2,832       
*Number of variables                  18   ->   4           
*j variable (16 values)                    ->   year
*xij variables:
*             cases0 cases1 ... cases15   ->   cases
*-----------------------------------------------------------------------------
******************************************************************************
save "/Users/vishakhasingla/Desktop/predoc/task2/edited data/hospital_edited",replace

*CITY DATA- has 35 variables and 50 observations.
import delimited "/Users/vishakhasingla/Downloads/city.csv", clear 
describe
su
duplicates report
*no missing or duplicate rows found.

*correcting the type of the lawchange variable from string to float
gen lawchange_num = (lawchange == "TRUE")
drop lawchange
describe

*reshaping into long format
reshape long factory_ production_, i(city population lawchange_num) j(year)
rename factory_ factory
rename production_ production

******************************************************************************
*Data                               Wide   ->   Long
*-----------------------------------------------------------------------------
*Number of observations               50   ->   800         
*Number of variables                  35   ->   6           
*j variable (16 values)                    ->   year
*xij variables:
*     factory_0 factory_1 ... factory_15   ->   factory_
*production_0 production_1 ... production_15->  production_
*-----------------------------------------------------------------------------
******************************************************************************


save "/Users/vishakhasingla/Desktop/predoc/task2/edited data/city_edited",replace

**********************************************
*Merging datasets


use "/Users/vishakhasingla/Desktop/predoc/task2/edited data/hospital_edited", clear
merge m:1 city year using "/Users/vishakhasingla/Desktop/predoc/task2/edited data/city_edited"

* Check for merge issues
tab _merge
*there are 2,736 merged observations that will be retained in the final dataset.

* Drop unmatched obs if needed
drop if _merge != 3
drop _merge


save "/Users/vishakhasingla/Desktop/predoc/task2/edited data/merged_data",replace

************************************************************
***********2- Data Analysis***********
************************************************************

*collapsing dataset to city level data for analysis since we do not require hospital level data

collapse (sum) cases (mean) population factory production, by(city year lawchange)

* Creating variables for analysis

gen asthma_rate = cases / population * 1000
gen post = (year >= 7)
gen post_treated = post * lawchange_num


*encoding the city variable 
encode city, gen(city_id)

*converting into panel dataset in Stata
xtset city_id year

************************************************************
*Panel variable: city_id (strongly balanced)
* Time variable: year, 0 to 15
*        Delta: 1 unit
************************************************************

save "/Users/vishakhasingla/Desktop/predoc/task2/edited data/merged_data",replace



use "/Users/vishakhasingla/Desktop/predoc/task2/edited data/merged_data", clear

*running covariate balance tests pre treatment
keep if year < 7

ttest cases, by(lawchange_num) 
*not statistically different
ttest population, by(lawchange_num) 
*statistically significant- control group cities had lower populations than treatment group cities (p-value= 0.0128)
ttest factory, by(lawchange_num)
*not statistically different

*checking parallel trends assumption for pre-treatment control and treatment groups through a leads and lags study
use "/Users/vishakhasingla/Desktop/predoc/task2/edited data/merged_data", clear

gen rel_year = year - 7

*creating dummies for treatment years
* Pre-treatment years (rel_m6 to rel_m1)
foreach i in 6 5 4 3 2 1 {
    gen rel_m`i' = (rel_year == -`i') & lawchange_num == 1
}

* Post-treatment years (rel1 to rel8)
forvalues i = 1/8 {
    gen rel`i' = (rel_year == `i') & lawchange_num == 1
}

xtreg asthma_rate rel_m6 rel_m5 rel_m4 rel_m3 rel_m2 rel_m1 rel1 rel2 rel3 rel4 rel5 rel6 rel7 rel8 i.year, fe cluster(city_id)

*since the coefficients on all but one m* variable are not significant, we can accept the parallel trends assumption pre-treatment.	
	 
*making the classic DID graph

*calculating averages for the control and treated groups

collapse (mean) asthma_rate, by(lawchange_num year)

twoway (line asthma_rate year if lawchange_num == 1, sort lcolor(red) lpattern(solid)) (line asthma_rate year if lawchange_num == 0, sort lcolor(blue) lpattern(solid)),legend(label(1 "Treated") label(2 "Control")) title("Asthma Rate Over Time: Treated vs Control")ytitle("Mean Asthma Rate") xtitle("Year") xline(7, lpattern(dash) lcolor(black))

use "/Users/vishakhasingla/Desktop/predoc/task2/edited data/merged_data", clear

*to check if there is any difference between pre and post treatment outcomes in control and treatment groups

xtreg asthma_rate post_treated lawchange_num i.year, fe cluster(city_id)

*After 2007, treated cities (those that received the Pokeball factory subsidy) saw an average increase in asthma rate of 2.59 per 1,000 children relative to control cities, controlling for year and city fixed effects. This effect is statistically significant with a p-value of 0.004.

**we are using fixed effects (time invariant variable) and lawchange_num is constant over time for each city (either treated or not), so it gets omitted from the regression.

*Robustness check by running a placebo test- shifting the treatment year to 2005 as a placebo
gen placebo_post = year >= 5
gen placebo_did = placebo_post * lawchange_num

xtreg asthma_rate placebo_did lawchange_num i.year, fe cluster(city_id)
*the coefficient of 2.59 turns out to be statistically significant at 0.3% significance level. 

*shifting the treatment year to 2005 as a placebo
gen placebo_post2 = year >= 10
gen placebo_did2 = placebo_post * lawchange_num

xtreg asthma_rate placebo_did2 lawchange_num i.year, fe cluster(city_id)
*the coefficient of 2.62 turns out to be statistically significant at 0.3% significance level. 
*the leads and lags study above also shows similar results. 

*So while we are getting a significant DiD estimate, the results are doubtful, because placebo tests also show statistically significant effects 


















