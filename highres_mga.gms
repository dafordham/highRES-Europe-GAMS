******************************************
* highres MGA module
******************************************

$ONEPS
$ONEMPTY

* Parameters such as slack and cost-optimal value.
$INCLUDE %mgapath%/mga_parameters.dd

* $setglobal mode minimizing/maximizing for Solve statement. 
$INCLUDE %mgapath%/mgaMode.gms

* Subsets for focus of MGA objective
Set
    focus_z(z)  "zones included in MGA objective"
    focus_g(g)  "technologies included in MGA objective"
;

focus_z(z) = yes$(par_focus_z(z));
focus_g(g) = yes$(par_focus_g(g));

Variables
mga_objective
;

Equations
eq_mga_obj
eq_max_costs
;

* Sum over the subsets 
eq_mga_obj..
    mga_objective =E=
        sum( (focus_z(z), focus_g(g)),
              var_exist_pcap_z(z,g)
            + var_new_pcap_z(z,g)
        );

eq_max_costs..
    costs =L= par_optimal_cost * (1+par_slack);
