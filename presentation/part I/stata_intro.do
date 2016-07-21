/***************Project: Stata introduction LectureDate: November 19, 2010Author: Matthijs de Zwaan***************/

/* First things first */
* Version control
version 11.1
* clear anything that might be loaded into Stata
clear all
* Clear annoying end-of-page messages
set more off, perm
* no variable abbreviation
set varabbrev off
* If necessary, you can change the amount of memory allocated to Stata (for very large data sets)
set mem 500m
* See help query for other changes that you can make to your system
* close any log files
capture log close // capture: do if you can, don't if you can't
* set your working directory
cd "~/workdir/Stata intro/20101119/"
/* open your own log file. You can open multiple log files, 
but then you need to give them different names using the name() option.
See help log */

log using "log.smcl", replace name(log1)

* Load your data.
use example.dta, clear
use "~/workdir/Stata intro/20101119/example.dta", clear

/* 
Stata can also read csv files and other formats using the insheet command. 
You can export Excel data sheets into csv, then read those with Stata. See 
help insheet and help infile for more info.
Stata can also export using outsheet.
*/
outsheet using example.csv, replace comma
insheet using example.csv, names clear
* We are going to use a small data set that ships with Stata
sysuse auto, clear
* Have a look at the data
inspect
describe
summarize
list price if rep78 != 0
list price if rep78 == 0 | rep78 == 1
list price if rep78 < .
list price if rep78 >= .
list price if rep78 !< .
codebook
codebook price
codebook, problems
tab foreign rep78
browse // look, don't touch
edit // allows editing by hand; not often a good idea

* you can generate new variables. See help generate
generate logprice = ln(price) // log transformations
replace logprice = log10(price)
gen trunksq = trunk^2 // square
gen weigthXprice = weight*price // interaction terms

gen rep5 = 0
replace rep5 = 1 if rep78 <= 5 // NB! == for equality in if-conditions

tab rep78, generate(d_rep78) // creates a 0/1 dummy var for each level of rep78
summ d_rep78*

/* egen functions: extended generate. See help egen
many useful functions! Statistical functions, string 
functions (for words), creating groups, checking for 
differences etc */
egen meanprice = mean(price)
egen sdprice = sd(price)
gen highprice = 0
replace highprice = 1 if price > meanprice

/* grouping by foreign and rep78: each 
different combination of foreign and make 
gets a different number. Useful to use in 
if…conditions, or in programming loops (see later) */
egen group = group(foreign rep78) 

* label your variables; see also help label
label variable meanprice "Mean price"
lab var sdprice "Stand.dev. price"

* correlation tables
pwcorr length price mpg

/* Some analyses */
* OLS: use regress
reg price foreign weight length
* see help regress postestimation for a number of tests
estat hettest
cap drop pricehat
predict pricehat, xb
cap drop resid
predict resid, res
scatter resid pricehat, scheme(sj)
rvfplot, scheme(sj)
discard
* , vce() option for adjustment of residuals (heteroskedasticity etc)
reg price foreign weight length, vce(robust)
reg price foreign weight length, vce(cluster foreign)

/* "help estimation commands" provides a list of all estimation commands */
* store and tabulate results:
reg price foreign weight length
estimates store ols
reg price foreign weight length, vce(robust)
estimates store robust
reg price foreign weight length, vce(cluster foreign)
est sto cluster

est tab ols robust cluster, se p

* panel data:
use union.dta, clear
* use http://www.stata-press.com/data/r11/union.dta, clear
xtset idcode year // set as panel data, xtset PANEL TIME
xtreg grade not_smsa age south union black, fe
est sto fixed
xtreg grade not_smsa age south union black, re
est sto random
hausman fixed random

* time series data
use lutkepohl.dta, clear
* webuse lutkepohl, clear
tsset qtr
* makes time series analysis avaliable; newey, var, arima etc

* setting a time variable with tsset or xtset allows you to
* use time series var-lists, see help tsvarlist. You can use
* these directly in analyses, or use them to create new variables
use union.dta, clear
* use http://www.stata-press.com/data/r11/union.dta, clear
xtset idcode year // set as panel data, xtset PANEL TIME
xtreg grade L.grade not_smsa age south union black, fe // lags (t-1)
xtreg grade F.grade not_smsa age south union black, fe // leads (t+1)
xtreg D.grade not_smsa age south union black, fe // differences (t - (t-1))
gen relchange = (D.grade)/(L.grade)

use lutkepohl, clear
tsset qtr
reg consump L(1/3).(consump) L(0/3).(inc)

/* graphics */
* see help graph
sysuse auto.dta, clear
graph twoway scatter price mpg, scheme(sj)
graph twoway scatter price mpg if foreign == 0 || scatter price mpg if foreign == 1, scheme(sj)
graph twoway lfit price mpg, scheme(sj) // linear fit
graph twoway scatter price mpg || lfit price mpg || lowess price mpg, scheme(sj) /// locally weighted regression
	legend(lab(1 "Data") ///			lab(2 "Linear fit") ///			lab(3 "Locally weighted regression") rows(1))
graph save scatter.gph, replace
graph export scatter.pdf, replace // windows users can export to .wmv for documents

* not all graph commands are ``graph twoway'' commands
kdensity price
histogram price
discard

/* a little programming… */
* very useful if you have a list of things, for all of
* which you need to do the same operation.
* loops: foreach, forval, while
forval i = 1/10	{ /* between curly brackets comes your program */
	di "i = " `i' /* note the quotes! ` versus '; " " for strings */
}

local participants Olivier Vasiliki Ellen Matthijs /* local can hold a list of things */
foreach name of local participants	{
	if "`name'" != "Matthijs"	{
		di "`name' is a participant"
	}
	else {
		di "`name' is presenting"
	}
}

* local macro are only held "locally", ie they are forgotten after (part of) the program runs
* Running the two lines together works (ie select both and then do), but first doing the first
* and then the second does not (ie select line 1, do, then select 2, then do). Stata forgets the content
* of the local.
local participants Olivier Vasiliki Ellen Matthijs
di "`participants'"

/* foreach and forval basically do the same thing;
forval is faster for sequences (ususally of numbers) */

local count = 1
while `count' <= 10	{ // if count <= 10, do the coammands, otherwise don't
	di "`count'"
	local count = `count' + 1 // increase count by one (otherwise the program never stops!)
}

* you can build loops within loops
forval i = 1/5	{
	foreach x in a b c d e	{ /* note the use of "in" vrsus "of" before. check the helpfile! */
		di "`i'`x' " _continue
	}
}

* close your log file
log close
* Save your data, if necessary into a new name.
* let Stata know you're done
exit
