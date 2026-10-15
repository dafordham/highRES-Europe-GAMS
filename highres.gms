******************************************
* highres main script
******************************************

* $ontext
option profile=1
* $offtext
option limrow=0, limcol=0, solprint=OFF
option decimals = 4
$offlisting
$ONMULTI
$ONEPS
$offdigit

* Switches:

* log = text file to store details about model run time, optimality or not, etc.
* gdx2sql (ON/OFF) = whether to convert output GDX to sqlite database -> easier
*                       to read into Python
* outname = output name of GDX file
*
* GWatts (YES/NO) = model is run in GW (YES) or MW (NO)
*
* storage (ON/OFF) = should storage be included in the model run
* hydrores (ON/OFF) = should reservoir hydro be incliuded in the model run
* sensitivity (ON/OFF) = whether a sensitivity file is available
* UC (ON/OFF) = unit committment switch
* store_uc (ON/OFF) = storage unit committment switch
*
* f_res (ON/OFF) = should frequency response requirements be modelled
*
* sense_run = sensitivity file identifier
* esys_scen = energy system scenario (sets the carbon budget and demands to be
*               used)
* psys_scen = power system scenario (sets which technologies are available)
* RPS = renewable portfolio standard
* vre_restrict = VRE land use deployment scenario name
* model_yr = which year in the future are we modelling
* weather_yr = which weather year do we use
* dem_yr = which demand year do we use
* trans_inv (OFF/TYNDP/USER) = new transmission capacity either:
*               i) no new transmission investment permitted
*               ii) upper limit based on TYNDP
*               iii) investment capped to user value "trans_cap_lim"
* trans_cap_lim = MW limit for each line available in model
* fx_caps_to = file containing capacities to fix the system to
*
* pathways
* Climate-Robust Pathways switches:
*
* fix_fleet = .dd file holding a previously solved fleet. When set, every
*               capacity in the system is fixed to it and only dispatch is
*               free. Empty means capacity stays a decision.
* fleet_floor = .dd file in the same format, for an expansion solve instead of
*               a dispatch. Existing capacity is fixed to the carried fleet and
*               new capacity is LOWER BOUNDED by what the file holds, so a
*               second expansion within a pathway step can only add to what the
*               first one built. Mutually exclusive with fix_fleet.
* ens_obj (ON/OFF) = minimise energy not served instead of minimising cost.
*               Requires fix_fleet. Cost is not constrained: ENS is the least
*               unserved energy the fleet can manage at any cost.
* fleet_from_inputs (ON/OFF) = write the fleet this model directory's inputs
*               describe (existing capacity plus plant under construction) to
*               %outname%.gdx and stop without solving. The starting fleet of
*               a pathway milestone.
* co2intensity = Average annual carbon dioxide emission intensity
*                the model is allowed to produce (gCO2/kWh)
* emis_price = emission price for non VRE
* store_initial_level = energy stored at the start (%/100)
* store_final_level = energy stored at the end (%/100)
* hydro_res_initial_fill = how full are the reservoirs at the start and end (%/100)
* hydro_res_min = minimum reservoir level (%/100)
*
* pen_gen (ON/OFF) = whether value of lost load (VoLL) is modelled
* pgen = pen_gen cost
*
* EV (ON/OFF) = whether to model electric vehicle charging through the storage module
* EV_flex (%) = percentage of electric vehicles modelled as flexible
* V2G (ON/OFF) = whether flexible EV charging allows for vehicle to grid (V2G)
*
* DISABLED switches
*
* fx_natcap (YES/NO) = fix total national capacities ->  let highRES decide
*                          where to place them
* water (ON/OFF) = model technologies with a water footprint
*
*
* Paths, logging and IO

$setglobal datafolderpath "."
$setglobal codefolderpath "."
$setglobal log "test_log"
$setglobal gdx2sql "OFF"
$setglobal outname "results"

* Units

$setglobal GWatts "YES"

* Modules

$setglobal storage "ON"
$setglobal hydrores "ON"
$setglobal sensitivity "OFF"
$setglobal UC "OFF"
$setglobal store_uc "OFF"

** Unit comittment switches

$setglobal f_res "OFF"
$setglobal f_res_mode "fixed"

* Case options

$setglobal co2_target_type "budget"
$setglobal co2_target_extent "zonal"
$setglobal sense_run "None"
$setglobal esys_scen "BASE"
$setglobal psys_scen "BASE"
$setglobal RPS "optimal"
$setglobal vre_restrict ""
$setglobal model_yr "2050"
$setglobal weather_yr "1995"
$setglobal dem_yr "1995"
$setglobal trans_inv "TYNDP"
$setglobal trans_cap_lim "20"
$setglobal fx_caps_to ""

* pathways
* Climate-Robust Pathways

$setglobal fix_fleet ""
$setglobal fleet_floor ""

$setglobal ens_obj "OFF"
$setglobal fleet_from_inputs "OFF"

*$setglobal co2intensity "2"
$setglobal emis_price "0"

$setglobal store_initial_level "0.5"
$setglobal store_final_level "0.5"

$setglobal hydro_res_initial_fill "0.8"
$setglobal hydro_res_min "0.5"

$set pen_gen "OFF"
$setglobal pgen "20.0"

* Caution: EV is not implemented for UC
$setglobal EV "OFF"
$ifThen "%EV%" == ON
$setglobal EV_flex "0"
$setglobal V2G "OFF"
$endif

* Disabled switches
$setglobal water "OFF"
$setglobal fx_natcap "NO"



**************************************************


* rescale from MW to GW for better numerics (allegedly)

scalar MWtoGW;

$ifThen "%GWatts%" == YES

MWtoGW=1E3;

$else

MWtoGW=1;

$endif


$INCLUDE %codefolderpath%/highres_data_input.gms

sets
gen_lin(z,non_vre)
ramp_on(z,non_vre)
mingen_on(z,non_vre)
ramp_and_mingen(z,non_vre)
;



$ifThen "%UC%" == ON

* UC on for all zones by default

set uc_z(z);
uc_z(z)=YES;

* generators that are represented as continous linear capacity chunks

gen_lin(z,non_vre)=not ((gen_uc_lin(non_vre) or gen_uc_int(non_vre)) and
    uc_z(z));

* generators that are continous linear chunks can have a mingen of 0

parameter gen_mingen_lin(non_vre);
gen_mingen_lin(non_vre)=0.;

$else

* if UC is not on all generators are linear chunks

gen_lin(z,non_vre)=YES;

parameter gen_mingen_lin(non_vre);
gen_mingen_lin(non_vre)=gen_mingen(non_vre);
gen_mingen_lin("NaturalgasOCGTnew")=0.0;
gen_mingen_lin("NaturalgasCCGTwithCCSnewOT")=0.0;

$endIf

$IF "%storage%" == ON $INCLUDE %codefolderpath%/highres_storage_setup.gms

* WARNING: for parameter updates to work there can be no arithmetic in the code
* before the update is run -> sensitivity data must be imported here


$IF "%sensitivity%" == ON $INCLUDE %datafolderpath%/sensitivity_%sense_run%.dd

* if no RPS set just do an optimal run

$IF "%RPS%" == "optimal" $GOTO optimal1

scalar
RPS
/%RPS%/
;
RPS=RPS/100.

$label optimal1
;

demand(z,h)=demand(z,h)/MWtoGW;
gen_cap2area(vre)=gen_cap2area(vre)/MWtoGW;
trans_links_cap(z,z_alias,trans)=trans_links_cap(z,z_alias,trans)/MWtoGW;
trans_links_lim_cap(z,z_alias,trans)=trans_links_lim_cap(z,z_alias,trans)/MWtoGW;
gen_unitsize(g)=gen_unitsize(g)/MWtoGW;
gen_maxramp(g)=gen_maxramp(g)/MWtoGW;




* Existing VRE capacity aggregated to zones

* exist_vre_cap_r(vre,z,r) = 0.0;

$ontext
gen_exist_pcap_z(z,vre,"FX")=sum(r,exist_vre_cap_r(vre,z,r));

$offtext

* Existing zonal capacity aggregated to national

parameter gen_exist_cap(g);
gen_exist_cap(g)=sum((z,lt),gen_exist_pcap_z(z,g,lt));

* Limit which regions a given VRE tech can be built in
* based on buildable area in that region. Stops offshore solar
* and onshore offshore wind.

set vre_lim(vre,z,r);
vre_lim(vre,z,r)=((area(vre,z,r)+sum(lt,gen_exist_pcap_r(vre,z,r,lt)))>0.);

* Non VRE cap lim to dynamic set, stops Nuclear being built in certain countries
*   (e.g. Austria)

set gen_lim(z,g);
gen_lim(z,non_vre)=((sum(lt,gen_lim_pcap_z(z,non_vre,lt))
    +sum(lt,gen_exist_pcap_z(z,non_vre,lt)))>0.);
gen_lim(z,vre)=(sum(r,(area(vre,z,r)+sum(lt,gen_exist_pcap_r(vre,z,r,lt))))>0.);



* Sets to ensure ramp/mingen constraints are only created where relevant

ramp_on(z,non_vre)=((gen_maxramp(non_vre)*60./gen_unitsize(non_vre)) < 1.0 and
    gen_lim(z,non_vre) and gen_lin(z,non_vre) and gen_unitsize(non_vre) > 0.);

mingen_on(z,non_vre)=(gen_mingen_lin(non_vre) > 0. and gen_lim(z,non_vre) and
    gen_lin(z,non_vre));

ramp_and_mingen(z,non_vre) = (ramp_on(z,non_vre) or mingen_on(z,non_vre));

* Buildable area per cell from km2 to MW power capacity

area(vre,z,r)=area(vre,z,r)$(vre_lim(vre,z,r))*gen_cap2area(vre);

* To be conservative, existing capacity is removed from new capacity limit

area(vre,z,r)=area(vre,z,r)-sum(lt,gen_exist_pcap_r(vre,z,r,lt));
area(vre,z,r)$(area(vre,z,r)<0.) = 0.;

* Fuel, varom and emission costs for non VRE gens;

gen_varom(non_vre)=gen_fuelcost(non_vre)+gen_emisfac(non_vre)*%emis_price%+
    gen_varom(non_vre);


* Penalty generation setup
* VoLL set at 20000£/MWh


* Solar marginal - small value necessary to avoid transmission system issue

gen_varom("Solar")=0.001;

*trans_varom(trans)=0.001;

* Rescale parameters for runs that are greater or less than one year

if (card(h) < 8760,
$ifthen "%co2_target_type%" == "budget"
$IF "%co2_target_extent%" == "all" co2_target=round(co2_target*(card(h)/8760.),8);
$IF "%co2_target_extent%" == "zonal" co2_target(z)=round(co2_target(z)*(card(h)/8760.),8);
$endif
gen_capex(g)=round(gen_capex(g)*(card(h)/8760.),8);
gen_fom(g)=round(gen_fom(g)*(card(h)/8760.),8);
gen_vreconnection(vre,z,r)=round(gen_vreconnection(vre,z,r)*(card(h)/8760.),8);
trans_line_capex(trans)=round(trans_line_capex(trans)*(card(h)/8760.),8);
trans_sub_capex(trans)=round(trans_sub_capex(trans)*(card(h)/8760.),8);

store_fom(s)=round(store_fom(s)*(card(h)/8760.),8);
store_pcapex(s)=round(store_pcapex(s)*(card(h)/8760.),8);
store_ecapex(s)=round(store_ecapex(s)*(card(h)/8760.),8);
);




Variables
costs                                    total electricty system costs

* pathways
$IF "%ens_obj%" == ON ens_total          total energy not served (objective when ens_obj is ON)

* Total cost components

costs_gen_capex(z)
costs_gen_fom(z)
costs_gen_varom(z)
costs_gen_vreconnection(z)
$IF "%UC%" == ON costs_gen_start(z)
costs_store_capex(z)
costs_store_fom(z)
costs_store_varom(z)
$IF "%store_uc%" == ON costs_store_start(z)
costs_trans_capex(z)
costs_trans_fom(z)
$IF "%pen_gen%" == ON costs_pgen(z)

Positive variables
var_new_pcap(g)                    new generation capacity at national level
var_new_pcap_z(z,g)                new generation capacity at zonal level
var_exist_pcap(g)                  existing generation capacity at national
*                                  level
var_exist_pcap_z(z,g)              existing generation capacity at zonal level
var_tot_pcap(g)                    total generation capacity at national level
var_tot_pcap_z(z,g)                total generation capacity at zonal level
var_gen(h,z,g)                     generation by hour and technology
var_new_vre_pcap_r(z,vre,r)        new VRE capacity at grid cell level by
*                                  technology and zone
var_exist_vre_pcap_r(z,vre,r)      existing VRE capacity at grid cell level by
*                                  technology and zone
var_vre_gen_r(h,z,vre,r)           VRE generation at grid cell level by hour
*                                  zone and technology
var_vre_curtail(h,z,vre,r)         VRE power curtailed
*var_non_vre_curtail(z,h,non_vre)
var_trans_flow(h,z,z_alias,trans)  Flow of electricity from node to node by hour
*                                  (MW)
var_tot_trans_pcap(z,z_alias,trans) Total transmission capacity node to node
var_new_trans_pcap(z,z_alias,trans)    Capacity of node to node transmission links
*                                  (MW)
var_exist_trans_pcap(z,z_alias,trans)  Existing capacity of node to node
*                                      transmissions links (MW)

var_pgen(h,z)                      Penalty generation

* pathways
$IF "%ens_obj%" == ON var_ens(h,z)  Energy not served by hour and zone

;

* Synchronous condensers can have negative generation - they require energy to
*   function

$IF "%f_res%" == ON var_gen.LO(h,z,"SynCon")=-inf;

*** Transmission set up ***

* Sets up bidirectionality of links

trans_links(z_alias,z,trans)$(trans_links(z,z_alias,trans))
    =trans_links(z,z_alias,trans);

trans_links_cap(z_alias,z,trans)$(trans_links_cap(z,z_alias,trans) > 0.)
    =trans_links_cap(z,z_alias,trans);

trans_links_dist(z,z_alias,trans)=trans_links_dist(z,z_alias,trans)/100.;

* Bidirectionality of link distances for import flow reduction -> both monodir
*   and bidir needed, former for capex.

parameter trans_links_dist_bidir(z,z_alias,trans);

trans_links_dist_bidir(z,z_alias,trans)=trans_links_dist(z,z_alias,trans);
trans_links_dist_bidir(z_alias,z,trans)$(trans_links_dist(z,z_alias,trans) > 0.)
    =trans_links_dist(z,z_alias,trans);

* Set transmission capacities to historic

var_exist_trans_pcap.FX(z,z_alias,trans)$(trans_links(z,z_alias,trans))
    = trans_links_cap(z,z_alias,trans);

$ifThen "%trans_inv%" == "OFF"

var_new_trans_pcap.UP(z,z_alias,trans)$(trans_links(z,z_alias,trans))= 0;

$elseif "%trans_inv%" == "TYNDP"

trans_links_lim_cap(z_alias,z,trans)$(trans_links_lim_cap(z,z_alias,trans))
    =trans_links_lim_cap(z,z_alias,trans);

var_new_trans_pcap.UP(z,z_alias,trans)$(trans_links(z,z_alias,trans))=
    trans_links_lim_cap(z,z_alias,trans);
    
$elseif "%trans_inv%" == "USER"

* Or limit all links to some maximum

var_new_trans_pcap.UP(z,z_alias,trans)$(trans_links(z,z_alias,trans))=
%trans_cap_lim%;

$endIf




*******************************

var_exist_pcap_z.UP(z,g)$(gen_exist_pcap_z(z,g,"UP"))
    = gen_exist_pcap_z(z,g,"UP");
*var_exist_pcap_z.L(z,g)$(gen_exist_pcap_z(z,g,"UP"))
*    = gen_exist_pcap_z(z,g,"UP");

var_exist_pcap_z.LO(z,g)$(gen_exist_pcap_z(z,g,"LO"))
    = gen_exist_pcap_z(z,g,"LO");
var_exist_pcap_z.FX(z,g)$(gen_exist_pcap_z(z,g,"FX"))
    = gen_exist_pcap_z(z,g,"FX");

var_exist_pcap_z.UP(z,g)$(not (sum(lt,gen_exist_pcap_z(z,g,lt)) > 0.)) = 0.0;



var_tot_pcap_z.UP(z,g)$(gen_lim_pcap_z(z,g,'UP'))=gen_lim_pcap_z(z,g,'UP');
var_tot_pcap_z.LO(z,g)$(gen_lim_pcap_z(z,g,'LO'))=gen_lim_pcap_z(z,g,'LO');
var_tot_pcap_z.FX(z,g)$(gen_lim_pcap_z(z,g,'FX'))=gen_lim_pcap_z(z,g,'FX');


var_exist_vre_pcap_r.UP(z,vre,r)$(gen_exist_pcap_r(vre,z,r,"UP"))=gen_exist_pcap_r(vre,z,r,"UP");
var_exist_vre_pcap_r.LO(z,vre,r)$(gen_exist_pcap_r(vre,z,r,"LO"))=gen_exist_pcap_r(vre,z,r,"LO");
var_exist_vre_pcap_r.FX(z,vre,r)$(gen_exist_pcap_r(vre,z,r,"FX"))=gen_exist_pcap_r(vre,z,r,"FX");

* turn off the potential for any existing capacity that is not given to the model

parameter gen_exist_r_on(z,g);
gen_exist_r_on(z,vre)=sum((r,lt),gen_exist_pcap_r(vre,z,r,lt));

var_exist_pcap_z.UP(z,g)$(not (sum(lt,gen_exist_pcap_z(z,g,lt)) > 0. or gen_exist_r_on(z,g) > 0.)) = 0.0;

* $IF "%fx_natcap%" == YES var_new_pcap.FX(g)$(gen_fx_natcap(g))=gen_fx_natcap(g);



$ifThen "%UC%" == ON
* parameters for UC, used by both gen and storage UC so needs to be defined
*   here

    scalars
    f_res_time      frequency response ramp up window (minutes)    / 0.083 /
    res_time        operating reserve ramp up window (minutes)     / 20. /
* unit_cap_lim_z only applies to techs being modelled as integer units normal linear
* UC techs will not be constrained by it
    unit_cap_lim_z  maximum capacity of each units deployed in each zone (MW) /50000./
    res_margin      operating reserve margin (fraction of demand)  / 0.1 /
    ;


    sets
    service_type    ancillary service type                / f_response, reserve/
    hh_minup(h)     max minup hours                       / 0*23 /
    hh_mindown(h)                                         / 0*7 /;
    ;
$endIf

$IF "%store_uc%" == ON $INCLUDE %codefolderpath%/highres_storage_uc_setup.gms

$IF "%UC%" == ON $INCLUDE %codefolderpath%/highres_uc_setup.gms

*$IF "%water%" == ON $INCLUDE %codefolderpath%/highres_water_setup.gms

$IF "%hydrores%" == ON $INCLUDE %codefolderpath%/highres_hydro.gms



$ifThen NOT "%fx_caps_to%" == ""

parameters
par_new_pcap_z(z,g)
par_exist_pcap_z(z,g)
par_new_store_pcap_z(z,s)
par_exist_store_pcap_z(z,s)
par_new_store_ecap_z(z,s)
par_exist_store_ecap_z(z,s)
par_trans_pcap(z,z_alias,trans)
;

$INCLUDE %datafolderpath%/%fx_caps_to%.dd
;

var_new_pcap_z.FX(z,g) = par_new_pcap_z(z,g);
var_exist_pcap_z.FX(z,g)=par_exist_pcap_z(z,g);

* redefine area, vre_lim and gen_lim so all VREs can be fixed

parameter area(vre,z,r);
area(vre,z,r)$(ord(z) eq ord(r))=par_new_pcap_z(z,vre);

vre_lim(vre,z,r)=((area(vre,z,r)+exist_vre_cap_r(vre,z,r))>0.);
gen_lim(z,vre)=sum(r,(area(vre,z,r)>0.));

var_new_store_pcap_z.FX(z,s)=par_new_store_pcap_z(z,s);
var_exist_store_pcap_z.FX(z,s)=par_exist_store_pcap_z(z,s);
var_new_store_ecap_z.FX(z,s)=par_new_store_ecap_z(z,s);
var_exist_store_ecap_z.FX(z,s)=par_exist_store_ecap_z(z,s);

var_trans_pcap.FX(z,z_alias,trans)=par_trans_pcap(z,z_alias,trans);


$endIf


*********************************************************
*** CLIMATE-ROBUST PATHWAYS: fix the fleet            ***
* pathways
*********************************************************

* Pins every capacity in the system to a previously solved fleet read from
* %fix_fleet%.dd, leaving only dispatch free.
*
* Deliberately separate from fx_caps_to above, which is left untouched. That 
* block didn't seem to work.
*
* VRE is fixed at grid cell level and never zonally. eq_new_vre_pcap_z already
* ties sum(cells) = var_new_pcap_z, so fixing both over-determines the system
* and any rounding mismatch makes it infeasible. Fixing only the zonal total
* would be worse: the optimiser could relocate VRE within a zone to suit
* whichever weather realisation it faces, which is re-investing rather than
* dispatching, and would understate ENS.
*
* The zonal VRE variables must therefore be FREED here, because the scenario
* bounds them independently a few hundred lines above: gen_exist_pcap_z pins
* existing VRE zonally, and any (z,g) the scenario does not mention has its
* existing capacity forced to zero. Both contradict a fleet that came from
* somewhere else. eq_exist_vre_pcap_z and eq_new_vre_pcap_z then define the
* zonal values from the fixed cells, which is the single source of truth.
*
* This did not surface while every fleet came from caps2dd.py reading a solved
* run of this same scenario, where the zonal value equals the scenario's by
* construction. A ledger disagrees -- AT.Solar is 1.92 GW in the 2030 ledger
* against the scenario's 0.1946 GW of 2010 capacity -- and CPLEX's conflict
* refiner names exactly that triple: eq_exist_vre_pcap_z(AT,Solar) with the
* cell fixed at 1.92 and the zonal variable pinned at 0.1946.

* Both switches read the same file in the same format, so caps2dd.py and
* ledger2dd.py serve either. fleet_dd is whichever one is set.

$setglobal fleet_dd ""
$if NOT "%fix_fleet%" == "" $setglobal fleet_dd "%fix_fleet%"
$if NOT "%fleet_floor%" == "" $setglobal fleet_dd "%fleet_floor%"

$ifThen.bothfleet NOT "%fix_fleet%" == ""
$if NOT "%fleet_floor%" == "" $abort fix_fleet and fleet_floor are mutually exclusive: one pins capacity for a dispatch, the other floors it for an expansion
$endIf.bothfleet

$ifThen.fxfleet NOT "%fleet_dd%" == ""

* caps2dd.py writes a block for every parameter below, empty if that capacity
* is all zero. So a parameter left unassigned here means the name in the .dd
* does not match the name declared, and GAMS error 141 catches it at compile
* time rather than the capacity being silently fixed to zero.
*
* Do not zero these before the $INCLUDE. Includes and .dd data are
* compile-time, assignments are execution-time, so the zeroing always runs
* after the load and wipes the fleet.

parameters
par_fix_new_pcap_z(z,g)            fixed new non-VRE capacity by zone
par_fix_exist_pcap_z(z,g)          fixed existing non-VRE capacity by zone
par_fix_new_vre_pcap_r(z,vre,r)    fixed new VRE capacity by grid cell
par_fix_exist_vre_pcap_r(z,vre,r)  fixed existing VRE capacity by grid cell
$IF "%storage%" == ON par_fix_new_store_pcap_z(z,s)
$IF "%storage%" == ON par_fix_exist_store_pcap_z(z,s)
$IF "%storage%" == ON par_fix_new_store_ecap_z(z,s)
$IF "%storage%" == ON par_fix_exist_store_ecap_z(z,s)
$IF "%hydrores%" == ON par_fix_new_hydro_ecap_z(z,hydro_res)
$IF "%hydrores%" == ON par_fix_exist_hydro_ecap_z(z,hydro_res)
par_fix_new_trans_pcap(z,z_alias,trans)
par_fix_exist_trans_pcap(z,z_alias,trans)
;

* Zones the fleet file speaks for. caps2dd.py and ledger2dd.py always write
* this set; empty means the whole model, which is the production case. A
* non-empty set exists for tests that treat a few countries as an island
* inside the full 28-zone input set: without it an expansion builds generation
* in a zero-demand neighbour and a line to import from it, because that is
* genuinely cheaper, and the island silently stops being one.

set fleet_zones(z)   zones this fleet file covers;

$INCLUDE %datafolderpath%/%fleet_dd%.dd
;

* Non-VRE generation: zonal

* Existing capacity is fixed in both modes: what the fleet already has is not
* a decision. New capacity is fixed for a dispatch and lower bounded for an
* expansion, which is the whole difference between the two switches.
*
* A floor must never exceed the variable's own upper bound. A solved level can
* sit marginally ABOVE its bound -- CPLEX returned
* var_new_trans_pcap(AT,CZ,HVAC_OHL) = 1.50000042 against a TYNDP limit of 1.5,
* inside its feasibility tolerance -- and flooring there gives .LO > .UP, which
* GAMS refuses as "Matrix error - lower bound > upper bound" before solving.
* Any variable that lands on a bound does this.
*
* So every floor is the carried value MINUS the solver's feasibility tolerance,
* which is the exact size of the problem: CPLEX may violate a bound by up to
* eprhs, so a level can exceed its bound by at most that, and subtracting it
* puts the floor back under the bound. Absolute, not relative: eprhs is an
* absolute tolerance, and a relative shave would be far too small for a small
* capacity -- 1e-6 relative on 0.0005 GW is 5e-10, a thousand times less than
* the overshoot it has to absorb.
*
* A floor is a LOWER bound, so giving up a tolerance-sized sliver costs nothing:
* the expansion may still build exactly what it built before, and in the test
* seven of eighteen assets sat back down on their floor.
*
* floor_tol must follow eprhs in cplex.opt. It is the default there, so both are
* 1e-6; loosening eprhs without raising this reopens the bug.
*
* Two alternatives were tried and rejected. min(..., .UP) reads a variable
* attribute before anything has assigned it, which trips GAMS error 141, and
* suppressing that check is what was removed on 2026-10-02. Truncating the
* values in caps2dd.py broke eq_store_ecap_max, because a dispatch pins storage
* power and energy and Li-ion-8 ties one to eight times the other.

scalar floor_tol   CPLEX feasibility tolerance - see eprhs in cplex.opt / 1e-6 /;

$ifThen.floor "%fleet_floor%" == ""
var_new_pcap_z.FX(z,non_vre)   = par_fix_new_pcap_z(z,non_vre);
$else.floor
var_new_pcap_z.LO(z,non_vre)   = max(0., par_fix_new_pcap_z(z,non_vre)-floor_tol);
$endIf.floor
var_exist_pcap_z.FX(z,non_vre) = par_fix_exist_pcap_z(z,non_vre);

* VRE: grid cell level, restricted to the cells a technology can exist in.
* Note vre_lim is declared (vre,z,r) while the variable is (z,vre,r), so the
* set cannot be used as the controlling index directly, because it would bind
* positionally and put vre in z's slot. The dollar condition is the form the
* model already uses for transmission at var_exist_trans_pcap.FX above.

var_exist_pcap_z.LO(z,vre) = 0.;
var_exist_pcap_z.UP(z,vre) = inf;
var_new_pcap_z.LO(z,vre)   = 0.;
var_new_pcap_z.UP(z,vre)   = inf;

$ifThen.floorvre "%fleet_floor%" == ""
var_new_vre_pcap_r.FX(z,vre,r)$(vre_lim(vre,z,r))
    = par_fix_new_vre_pcap_r(z,vre,r);
$else.floorvre
var_new_vre_pcap_r.LO(z,vre,r)$(vre_lim(vre,z,r))
    = max(0., par_fix_new_vre_pcap_r(z,vre,r)-floor_tol);
$endIf.floorvre
var_exist_vre_pcap_r.FX(z,vre,r)$(vre_lim(vre,z,r))
    = par_fix_exist_vre_pcap_r(z,vre,r);

$ifThen.fxstore "%storage%" == ON

* Note EV storage is not special-cased here; with EV OFF its capacities are
* already zero and the fixing is consistent. Revisit if EV is ever turned on.

$ifThen.floorstore "%fleet_floor%" == ""
var_new_store_pcap_z.FX(z,s)   = par_fix_new_store_pcap_z(z,s);
var_new_store_ecap_z.FX(z,s)   = par_fix_new_store_ecap_z(z,s);
$else.floorstore
var_new_store_pcap_z.LO(z,s)   = max(0., par_fix_new_store_pcap_z(z,s)-floor_tol);
var_new_store_ecap_z.LO(z,s)   = max(0., par_fix_new_store_ecap_z(z,s)-floor_tol);
$endIf.floorstore
var_exist_store_pcap_z.FX(z,s) = par_fix_exist_store_pcap_z(z,s);
var_exist_store_ecap_z.FX(z,s) = par_fix_exist_store_ecap_z(z,s);

$endIf.fxstore

$ifThen.fxhydro "%hydrores%" == ON

$ifThen.floorhydro "%fleet_floor%" == ""
var_new_hydro_ecap_z.FX(z,hydro_res)   = par_fix_new_hydro_ecap_z(z,hydro_res);
$else.floorhydro
var_new_hydro_ecap_z.LO(z,hydro_res)   = max(0., par_fix_new_hydro_ecap_z(z,hydro_res)-floor_tol);
$endIf.floorhydro
var_exist_hydro_ecap_z.FX(z,hydro_res) = par_fix_exist_hydro_ecap_z(z,hydro_res);

$endIf.fxhydro

* Outside the fleet's own zones nothing new may be built, and no line may be
* built unless BOTH ends are in scope. Only meaningful for fleet_floor: a
* fix_fleet dispatch already pins every capacity in the system.

$ifThen.scope NOT "%fleet_floor%" == ""

if(card(fleet_zones) > 0,
    var_new_pcap_z.FX(z,g)$(not fleet_zones(z)) = 0.;
    var_new_vre_pcap_r.FX(z,vre,r)$((not fleet_zones(z)) and vre_lim(vre,z,r)) = 0.;
$IF "%storage%" == ON     var_new_store_pcap_z.FX(z,s)$(not fleet_zones(z)) = 0.;
$IF "%storage%" == ON     var_new_store_ecap_z.FX(z,s)$(not fleet_zones(z)) = 0.;
$IF "%hydrores%" == ON     var_new_hydro_ecap_z.FX(z,hydro_res)$(not fleet_zones(z)) = 0.;
    var_new_trans_pcap.FX(z,z_alias,trans)$(trans_links(z,z_alias,trans)
        and (not (fleet_zones(z) and fleet_zones(z_alias)))) = 0.;
);

$endIf.scope

* Transmission. This overrides whatever trans_inv set above, deliberately: with
* a fixed fleet the lines are part of the fleet.

$ifThen.floortrans "%fleet_floor%" == ""
var_new_trans_pcap.FX(z,z_alias,trans)$(trans_links(z,z_alias,trans))
    = par_fix_new_trans_pcap(z,z_alias,trans);
$else.floortrans
var_new_trans_pcap.LO(z,z_alias,trans)$(trans_links(z,z_alias,trans))
    = max(0., par_fix_new_trans_pcap(z,z_alias,trans)-floor_tol);
$endIf.floortrans
var_exist_trans_pcap.FX(z,z_alias,trans)$(trans_links(z,z_alias,trans))
    = par_fix_exist_trans_pcap(z,z_alias,trans);

$endIf.fxfleet


*********************************************************
*** CLIMATE-ROBUST PATHWAYS: a milestone's starting fleet
* pathways
*********************************************************

* Reads every capacity off the bounds the data above has just set, writes it
* and stops before any equation is generated. Done here rather than by parsing
* the .dd files in Python so that the fleet is exactly what this model sees:
* the same unit conversions, the same handling of zonal and per-cell VRE, of
* hydro and of link direction. pathway_step.py turns the gdx into a fleet .dd
* with caps2dd.py.
*
* Existing capacity takes its upper bound if it has one, its lower bound
* otherwise. Where the data lets the optimiser keep or retire an existing plant
* (an UP bound only), it is counted as kept: the most the fleet can have.
*
* New capacity is only what the limits force: max(0, total.LO - existing).
* That is plant under construction, which the inputs step writes as a lower
* bound on TOTAL capacity. Nothing in the data bounds new capacity itself from
* below, and reading a bound nothing has assigned is GAMS error 141, so the
* new variables' own .LO are not read. For VRE the zonal shortfall is spread over the
* zone's cells in proportion to the area still free in each. At country level
* there is one cell per zone and the split does nothing.

$ifThen.fromin "%fleet_from_inputs%" == ON

$if NOT "%fleet_dd%" == "" $abort fleet_from_inputs reads the fleet from the inputs, so it cannot be combined with fix_fleet or fleet_floor

var_exist_pcap_z.L(z,g) = var_exist_pcap_z.LO(z,g);
var_exist_pcap_z.L(z,g)$(var_exist_pcap_z.UP(z,g) < inf) = var_exist_pcap_z.UP(z,g);
var_exist_vre_pcap_r.L(z,vre,r)$(vre_lim(vre,z,r)) = var_exist_vre_pcap_r.LO(z,vre,r);
var_exist_vre_pcap_r.L(z,vre,r)$(vre_lim(vre,z,r) and var_exist_vre_pcap_r.UP(z,vre,r) < inf)
    = var_exist_vre_pcap_r.UP(z,vre,r);
var_exist_trans_pcap.L(z,z_alias,trans)$(trans_links(z,z_alias,trans))
    = var_exist_trans_pcap.LO(z,z_alias,trans);

var_new_pcap_z.L(z,g)$(not vre(g)) = max(0.,
    var_tot_pcap_z.LO(z,g) - var_exist_pcap_z.L(z,g));

* Some cells have unlimited free area (inf), where a proportional split is
* undefined, so those zones split equally between their cells.

parameter fleet_vre_short(z,vre)   VRE under construction not covered by existing capacity
          fleet_vre_area(z,vre)    free area summed over the zone's cells
          fleet_vre_cells(z,vre)   number of cells the technology can use in the zone;
fleet_vre_short(z,vre) = max(0., var_tot_pcap_z.LO(z,vre)
    - sum(r$(vre_lim(vre,z,r)), var_exist_vre_pcap_r.L(z,vre,r)));
fleet_vre_area(z,vre) = sum(r$(vre_lim(vre,z,r)), area(vre,z,r));
fleet_vre_cells(z,vre) = sum(r$(vre_lim(vre,z,r)), 1);
var_new_vre_pcap_r.L(z,vre,r) = 0.;
var_new_vre_pcap_r.L(z,vre,r)$(vre_lim(vre,z,r) and fleet_vre_short(z,vre) > 0.
    and fleet_vre_area(z,vre) > 0. and fleet_vre_area(z,vre) < inf)
    = fleet_vre_short(z,vre)*area(vre,z,r)/fleet_vre_area(z,vre);
var_new_vre_pcap_r.L(z,vre,r)$(vre_lim(vre,z,r) and fleet_vre_short(z,vre) > 0.
    and fleet_vre_area(z,vre) = inf)
    = fleet_vre_short(z,vre)/fleet_vre_cells(z,vre);
var_new_pcap_z.L(z,vre) = sum(r$(vre_lim(vre,z,r)), var_new_vre_pcap_r.L(z,vre,r));

* VRE that must exist but has no free area to go in cannot be placed. Say so
* rather than write a fleet that misses it.
abort$(sum((z,vre)$(fleet_vre_short(z,vre) > 1e-6 and fleet_vre_area(z,vre) <= 0.), 1))
    "VRE under construction in a zone with no free area", fleet_vre_short;

var_new_trans_pcap.L(z,z_alias,trans) = 0.;

$ifThen.fromstore "%storage%" == ON
var_exist_store_pcap_z.L(z,s) = var_exist_store_pcap_z.LO(z,s);
var_exist_store_pcap_z.L(z,s)$(var_exist_store_pcap_z.UP(z,s) < inf) = var_exist_store_pcap_z.UP(z,s);
var_exist_store_ecap_z.L(z,s) = var_exist_store_ecap_z.LO(z,s);
var_exist_store_ecap_z.L(z,s)$(var_exist_store_ecap_z.UP(z,s) < inf) = var_exist_store_ecap_z.UP(z,s);
var_new_store_pcap_z.L(z,s) = max(0.,
    var_tot_store_pcap_z.LO(z,s) - var_exist_store_pcap_z.L(z,s));
var_new_store_ecap_z.L(z,s) = max(0.,
    var_tot_store_ecap_z.LO(z,s) - var_exist_store_ecap_z.L(z,s));
$endIf.fromstore

$ifThen.fromhydro "%hydrores%" == ON
var_exist_hydro_ecap_z.L(z,hydro_res) = var_exist_hydro_ecap_z.LO(z,hydro_res);
var_exist_hydro_ecap_z.L(z,hydro_res)$(var_exist_hydro_ecap_z.UP(z,hydro_res) < inf)
    = var_exist_hydro_ecap_z.UP(z,hydro_res);
var_new_hydro_ecap_z.L(z,hydro_res) = max(0.,
    var_tot_hydro_ecap_z.LO(z,hydro_res) - var_exist_hydro_ecap_z.L(z,hydro_res));
$endIf.fromhydro

execute_unload "%outname%.gdx"
    var_exist_pcap_z, var_new_pcap_z, var_tot_pcap_z,
    var_exist_vre_pcap_r, var_new_vre_pcap_r,
    var_exist_trans_pcap, var_new_trans_pcap
$IF "%storage%" == ON     , var_exist_store_pcap_z, var_new_store_pcap_z, var_exist_store_ecap_z, var_new_store_ecap_z
$IF "%hydrores%" == ON    , var_exist_hydro_ecap_z, var_new_hydro_ecap_z
;

$exit

$endIf.fromin


Equations
eq_obj

eq_costs_gen_capex
eq_costs_gen_fom
eq_costs_gen_varom
eq_costs_gen_vreconnection
$IF "%UC%" == ON eq_costs_gen_start
eq_costs_store_capex
eq_costs_store_fom
eq_costs_store_varom
$IF "%store_uc%" == ON eq_costs_store_start
eq_costs_trans_capex
eq_costs_trans_fom

eq_elc_balance

eq_new_pcap
eq_exist_pcap
eq_tot_pcap
eq_tot_pcap_z

eq_gen_max
eq_gen_min
eq_ramp_up
eq_ramp_down
*eq_curtail_max_non_vre

eq_new_vre_pcap_z
eq_exist_vre_pcap_z
eq_gen_vre
eq_gen_vre_r

eq_area_max

eq_trans_tot_pcap
eq_trans_flow
eq_trans_bidirect_new
eq_trans_bidirect_exist
$IF "%pen_gen%" == ON eq_pen_gen

* pathways
$IF "%ens_obj%" == ON eq_ens_total

eq_co2_target

*eq_cap_margin

;

******************************************
* OBJECTIVE FUNCTION
******************************************

eq_obj .. costs =E= sum(z,

costs_gen_capex(z)
+costs_gen_fom(z)
+costs_gen_varom(z)
+costs_gen_vreconnection(z)
$IF "%UC%" == ON +costs_gen_start(z)
+costs_store_capex(z)
+costs_store_fom(z)
+costs_store_varom(z)
$IF "%store_uc%" == ON +costs_store_start(z)
$IF "%pen_gen%" == ON +costs_pgen(z)
+costs_trans_capex(z)
+costs_trans_fom(z));


eq_costs_gen_capex(z)..
    costs_gen_capex(z) =E= sum(g,var_new_pcap_z(z,g)*gen_capex(g));


eq_costs_gen_vreconnection(z)..
    costs_gen_vreconnection(z) =E= sum(vre_lim(vre,z,r)$(gen_vreconnection(vre,z,r) > 0.),
                                    gen_vreconnection(vre,z,r)*var_new_vre_pcap_r(z,vre,r));
                                

eq_costs_gen_fom(z)..
    costs_gen_fom(z) =E= sum(g,var_new_pcap_z(z,g)*gen_fom(g))
                            +sum(g,var_exist_pcap_z(z,g)*gen_fom(g));

eq_costs_gen_varom(z)..
    costs_gen_varom(z) =E= sum((h,gen_lim(z,g)),var_gen(h,z,g)*gen_varom(g));

$ifThen "%UC%" == ON
    eq_costs_gen_start(z)..
        costs_gen_start(z) =E= sum((h,non_vre)$(gen_uc_int(non_vre) and
            gen_lim(z,non_vre)),var_up_units(h,z,non_vre)
            *gen_startupcost(non_vre))
        +sum((h,non_vre)$(gen_uc_lin(non_vre) and gen_lim(z,non_vre)),
            var_up_units_lin(h,z,non_vre)*gen_startupcost(non_vre));
$endIf

$ifThen "%pen_gen%" == ON
    eq_pen_gen(z)..
        costs_pgen(z) =E= sum((h),var_pgen(h,z)*%pgen%);
$endIf

* pathways
$ifThen "%ens_obj%" == ON

$if "%fix_fleet%" == "" $abort ens_obj=ON requires fix_fleet: there is no fleet to dispatch (fleet_floor is for expansion solves, which minimise cost)

* Energy not served over the whole system and the whole horizon. Pathways

    eq_ens_total ..
        ens_total =E= sum((h,z),var_ens(h,z));

$endIf

eq_costs_store_capex(z)..
    costs_store_capex(z) =E= sum(s,var_new_store_pcap_z(z,s)*store_pcapex(s)
        +var_new_store_ecap_z(z,s)*store_ecapex(s));

eq_costs_store_fom(z)..
    costs_store_fom(z) =E= sum(s,var_exist_store_pcap_z(z,s)*store_fom(s))
        +sum(s,var_new_store_pcap_z(z,s)*store_fom(s));

eq_costs_store_varom(z)..
    costs_store_varom(z) =E= sum((h,s)$s_lim(z,s),var_store_gen(h,z,s)
        *store_varom(s));
        
$ifthen "%store_uc%" == ON
    eq_costs_store_start(z)..
        costs_store_start(z) =E= sum(
          (h,s_lim(z,store_uc_lin)),
         var_store_up_units_lin(h,z,store_uc_lin)*
         store_startupcost(store_uc_lin));
$endif

eq_costs_trans_capex(z)..
    costs_trans_capex(z) =E= sum(trans_links(z,z_alias,trans),
        var_new_trans_pcap(z,z_alias,trans)*trans_links_dist(z,z_alias,trans)
        *trans_line_capex(trans))
    +sum(trans_links(z,z_alias,trans),
        var_new_trans_pcap(z,z_alias,trans)$(trans_links_dist(z,z_alias,trans))
        *trans_sub_capex(trans)*2);

* assume 2% fom costs for transmission

eq_costs_trans_fom(z) ..
    costs_trans_fom(z) =E=
    
        costs_trans_capex(z)*0.02
        
* add on 2% fom costs for existing transmission
    
        +(sum(trans_links(z,z_alias,trans),
            var_exist_trans_pcap(z,z_alias,trans)*trans_links_dist(z,z_alias,trans)
            *trans_line_capex(trans))
        +sum(trans_links(z,z_alias,trans),
            var_exist_trans_pcap(z,z_alias,trans)$(trans_links_dist(z,z_alias,trans))
            *trans_sub_capex(trans)*2))*0.02;



******************************************
* SUPPLY-DEMAND BALANCE EQUATION (hourly)
******************************************

eq_elc_balance(h,z) ..

* Generation
sum(gen_lim(z,g),var_gen(h,z,g))

* NonVRE Curtailment due to ramp rates
*-sum(non_vre,var_non_vre_curtail(z,h,non_vre))

* Transmission, import-export
-sum(trans_links(z,z_alias,trans),var_trans_flow(h,z_alias,z,trans))
+sum(trans_links(z,z_alias,trans),var_trans_flow(h,z,z_alias,trans)*
    (1-(trans_links_dist_bidir(z,z_alias,trans)*trans_loss(trans))))

$ifThen "%storage%" == ON

* Storage, generated-stored
-sum(s_lim(z,s),var_store(h,z,s))
+sum(s_lim(z,s),var_store_gen(h,z,s))

$endIf

$IF "%pen_gen%" == ON +var_pgen(h,z)

* pathways
$IF "%ens_obj%" == ON +var_ens(h,z)

$IF "%EV%" == ON - (par_ev_charging(z,h)*(1-s_EV_flex))/store_eff_in("EV")

=E= demand(z,h);

* +sum(gen_lim(z,g)$(dem(g)),var_gen(h,z,g));


******************************************

*** Capacity balance ***

eq_new_pcap (g)..
    sum(gen_lim(z,g),var_new_pcap_z(z,g)) =E= var_new_pcap(g);

eq_exist_pcap(g)..
    sum(gen_lim(z,g),var_exist_pcap_z(z,g)) =E= var_exist_pcap(g);

eq_tot_pcap_z(z,g)..
    var_new_pcap_z(z,g) + var_exist_pcap_z(z,g) =E= var_tot_pcap_z(z,g);

eq_tot_pcap(g)..
    sum(z,var_tot_pcap_z(z,g)) =E= var_tot_pcap(g);

*********************
*** VRE equations ***
*********************

* VRE generation is input data x capacity in each region

eq_gen_vre_r(h,vre_lim(vre,z,r))..
    var_vre_gen_r(h,z,vre,r) =L= vre_gen(h,vre,r)*(var_new_vre_pcap_r(z,vre,r)
        +var_exist_vre_pcap_r(z,vre,r));

* VRE gen at regional level aggregated to zonal level

eq_gen_vre(h,z,vre)..
    var_gen(h,z,vre) =E= sum(vre_lim(vre,z,r),var_vre_gen_r(h,z,vre,r));

* VRE capacity across all regions in a zone must be equal to capacity in that
*   zone

eq_new_vre_pcap_z(z,vre)..
    sum(vre_lim(vre,z,r),var_new_vre_pcap_r(z,vre,r)) =E= var_new_pcap_z(z,vre);

eq_exist_vre_pcap_z(z,vre)..
    sum(vre_lim(vre,z,r),var_exist_vre_pcap_r(z,vre,r))
    =E= var_exist_pcap_z(z,vre);

* VRE capacity in each region must be less than or equal to buildable MW as
*   governed by buildable area for each technology in that region

eq_area_max(vre_lim(vre,z,r)) .. var_new_vre_pcap_r(z,vre,r) =L= area(vre,z,r);


*************************
*** NON VRE equations ***
*************************

* Maximum generation of Non VRE

eq_gen_max(gen_lim(z,non_vre),h)$(gen_lin(z,non_vre))..
    var_tot_pcap_z(z,non_vre)*gen_af(non_vre) =G= var_gen(h,z,non_vre);

* Minimum generation of Non VRE

eq_gen_min(mingen_on(z,non_vre),h)$(gen_lin(z,non_vre))..
    var_gen(h,z,non_vre) =G= var_tot_pcap_z(z,non_vre)*gen_mingen_lin(non_vre);

* Ramp equations applied to Non VRE generation, characterised as fraction of
*   total installed capacity per hour

eq_ramp_up(h,ramp_on(z,non_vre))$(gen_lin(z,non_vre))..
    var_gen(h,z,non_vre) =L= var_gen(h-1,z,non_vre)
    +(gen_maxramp(non_vre)*60./gen_unitsize(non_vre))*var_tot_pcap_z(z,non_vre);

eq_ramp_down(h,ramp_on(z,non_vre))$(gen_lin(z,non_vre))..
    var_gen(h,z,non_vre) =G= var_gen(h-1,z,non_vre)
    -(gen_maxramp(non_vre)*60./gen_unitsize(non_vre))*var_tot_pcap_z(z,non_vre);

* Non VRE curtailment due to ramping/min generation

*eq_curtail_max_non_vre(ramp_and_mingen(z,non_vre),h)..
*   var_non_vre_curtail(z,h,non_vre) =L= var_non_vre_gen(z,h,non_vre);


******************************
*** Transmission equations ***
******************************

* Transmission total power capacity

eq_trans_tot_pcap(trans_links(z,z_alias,trans)) ..

    var_tot_trans_pcap(z,z_alias,trans) =E=

    var_new_trans_pcap(z,z_alias,trans)
    + var_exist_trans_pcap(z,z_alias,trans);


* Transmitted electricity each hour must not exceed transmission capacity

eq_trans_flow(h,trans_links(z,z_alias,trans))..

    var_trans_flow(h,z,z_alias,trans) =L=
    
    (var_new_trans_pcap(z,z_alias,trans)
    +var_exist_trans_pcap(z,z_alias,trans));

* Bidirectionality equations is needed when investments into new links are made
*   ...I think :)

eq_trans_bidirect_new(trans_links(z,z_alias,trans))..
    var_new_trans_pcap(z,z_alias,trans) =E= var_new_trans_pcap(z_alias,z,trans);
    
eq_trans_bidirect_exist(trans_links(z,z_alias,trans))..
    var_exist_trans_pcap(z,z_alias,trans) =E= var_exist_trans_pcap(z_alias,z,trans);



***********************
*** Misc. equations ***
***********************

* Emissions limit - European average

$ifThen.a "%co2_target_extent%" == "all"

eq_co2_target(yr)..
    sum((gen_lim(z,non_vre),h)$(hr2yr_map(yr,h)),var_gen(h,z,non_vre)
        *gen_emisfac(non_vre))
        
$ifThen.b "%co2_target_type%" == "intensity"

    =L= sum((z,h)$(hr2yr_map(yr,h)),demand(z,h))*co2_target/1E3;
    
$elseif.b "%co2_target_type%" == "budget"

    =L= co2_target;
    
$endif.b

$elseif.a "%co2_target_extent%" == "zonal"

eq_co2_target(yr,z)..
    sum((gen_lim(z,non_vre),h)$(hr2yr_map(yr,h)),var_gen(h,z,non_vre)
        *gen_emisfac(non_vre))
        
$ifThen.b "%co2_target_type%" == "intensity"

    =L= sum(h$(hr2yr_map(yr,h)),demand(z,h))*co2_target(z)/1E3;
    
$elseif.b "%co2_target_type%" == "budget"

    =L= co2_target(z);

$endif.b
$endif.a





* Capacity Margin

*scalar dem_max;
*dem_max=smax(h,sum(z,demand(z,h)));

*eq_cap_margin..
*   sum(non_vre,var_tot_pcap(non_vre)*gen_peakaf(non_vre))
*   +sum(vre,var_tot_pcap(vre)*gen_peakaf(vre)) =G= dem_max*1.1;

*eq_max_cap(z,g)..
*   var_cap_z(z,g)+sum(vre_lim(vre,z,r),exist_vre_cap_r(z,vre,r))
*   +gen_exist_pcap_z(z,non_vre) =L= max_cap(z,g)

* Equation for minimum renewable share of generation, set based on restricting
*   non VRE generation.

set flexgen(non_vre) / NaturalgasOCGTnew /;

$IF "%RPS%" == "optimal" $GOTO optimal
    scalar dem_tot;
    dem_tot=sum((z,h),demand(z,h));

    Equations eq_max_non_vre;
    eq_max_non_vre..
        sum((h,z,non_vre)$(gen_lim(z,non_vre) and not flexgen(non_vre)),
            var_gen(h,z,non_vre))
        =E= dem_tot*(1-RPS_scalar);
$label optimal



Model Dispatch /all/;

* don't usually use crossover but can be used to ensure
* a simplex optimal solution is found


Dispatch.OptFile = 1;


* pathways
$ifThen.obj "%ens_obj%" == ON

* Cost is still computed, since eq_obj and the cost components stay in the
* model. It is simply no longer what is optimised, and nothing constrains it:
* varom, the generation mix and curtailment from an ens_obj solve are not
* interpretable.

$ifThen.uc1 "%UC%" == ON

Solve Dispatch minimizing ens_total using MIP;

$else.uc1

Solve Dispatch minimizing ens_total using LP;

$endIf.uc1

$else.obj

$ifThen.uc2 "%UC%" == ON

Solve Dispatch minimizing costs using MIP;

$else.uc2

Solve Dispatch minimizing costs using LP;

$endIf.uc2

$endIf.obj


parameter trans_f(h,z,z_alias,trans);
trans_f(h,z,z_alias,trans)=var_trans_flow.l(h,z_alias,z,trans)
    $(var_trans_flow.l(h,z,z_alias,trans)>1.0);
*display trans_f;

parameter max_bidir_trans;
max_bidir_trans=smax((h,z,z_alias,trans),trans_f(h,z,z_alias,trans));
*display maxtrans;

*parameter pgen_tot;
*pgen_tot=sum((z,h),var_non_vre_gen.l(z,h,"pgen"));

$IF "%log%" == "" $GOTO nolog
scalar now,year,month,day,hour,minute;
now=jnow;
year=gyear(now);
month=gmonth(now);
day=gday(now);
hour=ghour(now);
minute=gminute(now);

scalars  cplex_absgap    absolute gap
         cplex_relgap    relative gap;

cplex_absgap = abs(Dispatch.objest - Dispatch.objval);
cplex_relgap=100*cplex_absgap/abs(Dispatch.objval);

file fname /"%log%"/;
fname.ap=1;
putclose fname "%outname%"","
day:0:0"/"month:0:0"/"year:0:0" "hour:0:0":"minute:0:0","
Dispatch.modelStat:1:0","
Dispatch.resUsd:0
$IF "%UC%" == ON ","cplex_relgap:0
;
$LABEL nolog

* write result parameters

$INCLUDE %codefolderpath%/highres_results.gms

* dump data to GDX
$setEnv GDXCOMPRESS 1
execute_unload "%outname%"

* convert GDX to SQLite


$ifThen "%gdx2sql%" == ON
execute "gdx2sqlite -i %outname%.gdx -o %outname%.db -fast"
$endIf

