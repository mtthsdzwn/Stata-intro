version 9
clear all
cd "/Users/matthijsdezwaan/workdir/Stata intro/presentation/part II/"

cap log close intro
log using "introduction.smcl", replace name(intro)
/**********************
Stata Introduction Part II
December 9, 2011
Author: Matthijs de Zwaan
**********************/

/* Setting up an example panel data set.
Use "set seed #" if you want to get the same
`random' numbers each time */
* make a data of 500 obs
clear
set obs 500
* make id-var
egen id = seq(), from(1) to(50) block(10)
* make time-var
bysort id: gen t = _n
* set as panel data 
xtset id t, yearly delta(1)
* make a regressor; uniform dist over [0,3)
generate x = 3*uniform()
* making fixed effects
gen ci =  sqrt(id)
* generate errors ~ N with mean 0, sd 1
gen e = rnormal()
summ e
return list
replace e = (e - r(mean))/(r(sd)) // make sure that mean = 0 and sd = 1
summ e
* generate dependent variable: constant = 1 + x + fixed effects
* Of course, we would nomally observe only y and x!
gen y = 1 + x + ci + e

summ
xtdes
pwcorr, star(0.05)

* Pooled OLS
regress y x
regress y x, cluster(id)
* Results are okay; why are the c_i not a problem?

* create new data; now, c_i are correlated with X
cap drop x
gen x = .5*rnormal() + .2*ln(id) // remember that ci = id, so now both depend on id

cap drop y
gen y = 1 + x + ci + e

summ
pwcorr, star(0.05)

* pooled OLS
regress y x
scatter y x
* Not even close to real model!

cap drop x
gen x = .5*rnormal() - .2*ln(id) // negative correlation

cap drop y
gen y = 1 + x + ci + e

summ
pwcorr, star(0.05)

regress y x
scatter y x

* Even worse! 
* Let's run the model for each panel.
gen bhat = .
summ id
return list
set trace on
set tracedepth 1
forval i = 1/`r(max)'	{ // or use the levelsof command in a smart way…
cap set trace off
	qui reg y x if id == `i'
	replace bhat = _b[x] if id == `i'
}
summ bhat
* coefficient is okay, but only 10 obs per panel -> some kind of pooling would be nice for efficiency
* A graph might clarify the problem
scatter y x, mlab(id)
scatter y x if id <= 5, mlab(id) msymbol(i) mlabpos(0)
#delimit;
graph twoway // see help graph twoway for the many options!
	scatter y x, legend(off) scheme(sj) ms(+)
||	lfit y x, lcolor(red) lwidth(1) lpattern(solid)
||	scatter y x if id == 1, mcolor(red) msymbol(d) msize(large)
||	lfit y x if id == 1, lcolor(red) lpattern(solid)
||	scatter y x if id == 11, mcolor(blue) msymbol(d) msize(large)
||	lfit y x if id == 11, lcolor(blue) lpattern(solid)
||	scatter y x if id == 21, mcolor(green) msymbol(d) msize(large)
||	lfit y x if id == 21, lcolor(green) lpattern(solid)
||	scatter y x if id == 31, mcolor(yellow) msymbol(d) msize(large)
||	lfit y x if id == 31, lcolor(yellow) lpattern(solid)
||	scatter y x if id == 41, mcolor(gray) msymbol(d) msize(large)
||	lfit y x if id == 41, lcolor(gray) lpattern(solid)
;
#delimit cr

* What to do!? Fixed effects panel estimation!
xtset
* quick look
preserve
xtdata, fe clear
scatter y x
reg y x
restore
xtreg y x, fe vce(robust)
ereturn list
matrix B = e(b)
matrix list B
matrix V = e(V)
matrix list V
* So what are my p-values?
scalar b = _b[x] // get the coeff and the se of x
scalar se = _se[x] // we could also have gotten these values from the matrices B and V
scalar t = b/se
di t
scalar p = ttail(e(df_r), abs(scalar(t))) // ``look up'' in the t distribution
di 2*p
scalar lb = b - invttail(e(df_r),0.025)*sescalar ub = b + invttail(e(df_r),0.025)*se
di "95% CI for b[x]: " %6.5f _col(20)lb %6.5f _col(30)ub // see help format


/* A new example: probit models
Dependent variable is 0/1, eg person is unemployed yes/no,
or, student passes test yes/no. 
We have an underlying ``latent variable'' y* that is continuous.
Y* is unobserved by the researcher!
If y* <= 0, y = 0; if y* > 0, y = 1
 */

clear
set obs 500
gen x1 = rnormal(1.3)
gen x2 = runiform()
gen e = rnormal()
qui summ e
replace e = (e - r(mean))/r(sd)
gen ystar = -1 + x1 + x2 + e
gen y = (ystar > 0)
summ
pwcorr

* Linear probability model; sometimes works okay…
reg ystar x1 x2
estimates store M1
reg y x1 x2, robust
est sto linprob
* …but not here
est table M1 linprob

* Probit model
probit y x1 x2
est sto probit
* logit model
logit y x1 x2
est sto logit
est table linprob probit logit

* more options for tables with the estout package 
* if you need to install: ssc install estout
* best thing: you can export!
#delimit;
esttab linprob logit probit /* using intro.csv */
,	star(* .1 ** .05 *** .01)
	mtitles(LPM probit logit) nonumbers
	coeflabels( x1 "X 1" x2 "X 2" _cons "Constant")
	/* these are the exporting options. Use csv to make a Excel-compatible
	file; tex for LaTeX; rtf for text (or Word). See the help file */
	/* csv replace */
;
#delimit cr

/* Let's graph the marginal effects. Remember that
max. likelihood models have MFX that differ for each observation!
Linear models (ie OLS-like) have constant MFX.
We look only at x1; x2 is analogous 
For linear models, Ey = c + b*x1, so the MFX
of x1 on y is dy/dx1 = b. 
In nonlinear models, Ey = f(c + bx1), where f(.)
depends on which estimator you are using. For logit, 
y* = Pr(y = 1 | x1) = (exp(c + bx1))/(1 + exp(c + bx1)), so the mfx is
dy/dx1 = (exp(c + bx1) / (1 + exp(c + bx1))^2)*b (yes it is,
check for yourself!).
For probit, f(.) is the standard normal cumul. distr.

The mfx depends on the entire distribution, and is thus different
for all observations! Documenting the coefficient - even 
if suitably transformed - is not always informative! 
Better to compute for all x, and make a graph/table. 
Also be careful with interactions/quadratics etc! It is
important to know what you are estimating to know how to interpret.
Usefull articles: 
- Ai & Norton, 2004, Econ. Letters, Interaction terms in logit and probit models
- Ai, Norton & Wang, 2004, stata journal, computing interaction effects and standard errors
	in logit and probit models.

This kind of stuff is valid - mutatis mutandis - for all nonlinear models:
count data, survival data, mulitinomial data etc
*/
cap drop xb
cap drop mflogit
est replay logit
scalar b = _b[x1]
predict xb, xb // Here, we compute c + b1*x1 + b2*x2 for all observations
gen mflogit = ((exp(xb)/(1 + exp(xb))^2))*b

cap drop xb
cap drop mfprobit
est replay probit
scalar b = _b[x1]
predict xb, xb
gen mfprobit = normalden(xb)*b // probit assumes the cumul. norm dens -> dy/dx is normal prob. dens.
graph twoway ///
	scatter mfprobit x1, ms(+) ///	
||	scatter mflogit x1, ms(x) mc(red)

/* These graphs are so diffuse, because the linear predictions
(the xb's) include the variation from x2, which is not very useful here.
We can also compute this while keeping x2 constant, for instance at it's 
mean. How could we do that? */

cap drop xb
cap drop mflogit
est replay logit
scalar b = _b[x1]
adjust x2, xb gen(xb) // Here, we compute c + b1*x1 + b2*mean(x2) for all observations
gen mflogit = ((exp(xb)/(1 + exp(xb))^2))*b

cap drop xb
cap drop mfprobit
est replay probit
scalar b = _b[x1]
adjust x2, xb gen(xb)
gen mfprobit = normalden(xb)*b // probit assumes the cumul. norm dens -> dy/dx is normal prob. dens.
graph twoway ///
	scatter mfprobit x1, ms(+) ///
||	scatter mflogit x1, ms(x) mc(red)

/* Take care with the adjust command if you use it with quadratic terms/interactions!
Stata does NOT recognise that your variable xsq = X^2. Setting x2 to its mean also
requires setting xsq = (mean(x2))^2. You NEED to do this manually! See the adjust help file
on how to this. */


/* We can also use the dprobit command (only for probit), 
or the mfx postestimation command */
probit y x1 x2 
mfx
dprobit y x1 x2

logit y x1 x2
mfx


/* extending it a bit…I show the (transformed) estimate, ie f'(mean(x)),
and the average of indiv. mfx, ie mean(f'(x)). Note the difference, 
and more importantly, note how little the average tells you! */
est res logit
local blog = ((exp(_b[x1])/(1 + exp(_b[x1]))^2))
qui summ mflogit, meanonly
local mflog = r(mean)
est res probit
local bprob = normalden(_b[x1])
qui summ mfprobit, meanonly
local mfprob = r(mean)

macro list _mflog _blog _mfprob _bprob

graph twoway ///
	scatter mfprobit x1 ///
, 	ms(+) mc(black) yline(`bprob', lc(black) lp(solid)) yline(`mfprob', lc(black) lp(dash)) ///
||	scatter mflogit x1 ///
, 	ms(x) mc(red) yline(`blog', lc(red) lp(solid)) yline(`mflog', lc(red) lp(dash))

/* We can also show predicted probabilities with the ``,pr'' option of predict and adjust */
cap drop plog
cap drop pprob
cap drop plin
est res logit
adjust x2, pr gen(plog)
est res probit
adjust x2, pr gen(pprob)
est res linprob
adjust x2, xb gen(plin)
sort x1
graph twoway ///
	line plog x1 ///
||	line pprob x1 ///
||	line plin x1 ///
, 	scheme(sj) ///
	legend(lab(1 "Logit") lab(2 "Probit") lab(3 "OLS") rows(1)) ///
	title(Predicted probabilities) ///
	ytitle("Predicted" "Probability", orient(horiz) size(medlarge)) yscale(titlegap(*5)) ///
	ylabel(, alternate) ///
	xtitle(X1, size(medlarge)) xscale(titlegap(*5)) ///
	yline(0 1, lc(black) lp(dash))
	
/* Programs */
/* If you need to do a certain task very often,
you can choose to make a program. Often, such a program
will be a loop as discussed before, but somehow generalised 
to accept different variables. You can save your program is an
.ado file in the appropriate directory. Stata will then look for your program 
when you call it.
A useful package is the adoedit package, which allows you
to easily call the code for other programs, so you can have a look
 */

*which greet
*adoedit greet

*log close intro
exit
