function T = update_traceability(assertions)
%UPDATE_TRACEABILITY Map evidence strictly by matching Requirement_ID.
ids=("PR-"+compose('%02d',(1:15)'));
req=["Small-scale PV source";"Unified PV model and MPPT sensing";"DC-side SPD sizing and capability";"Transient injection";"Supercapacitor buffering and ESR";"Controlled dynamic SC interface";"Magnitude-duration controller";"Brief disturbance continuity";"Severe/prolonged isolation";"Relay arming, timing and resets";"Normal/fault validation";"Averaged and switching microinverter";"Safe laboratory interpretation";"Fair paired four-mode comparison";"Voltage stability and numerical convergence"];
sub=["PV Source";"PV Source; MPPT Controller";"SPD MOV";"Surge Generator; Cable and Source Impedance";"Supercapacitor Interface";"Supercapacitor Interface";"Protection Controller";"Protection Controller; Relay Contactor";"Protection Controller; Relay Contactor";"Protection Controller; Relay Contactor";"Measurements and Logging";"Averaged Microinverter Protected Load; Microinverter Switching Demo";"Documentation";"Paired comparison runs";"DC Bus Dynamics"];
impl=["physics/pv_current_single_diode.m";"physics/pv_available_mpp.m; controllers/mppt_sfunc.m";"physics/mov_demanded_current.m; controllers/spd_mov_sfunc.m";"simulation/prepare_surge_waveform.m";"controllers/supercapacitor_interface_sfunc.m";"controllers/supercapacitor_interface_sfunc.m";"controllers/protection_controller_sfunc.m";"controllers/protection_controller_sfunc.m";"controllers/relay_contactor_sfunc.m";"controllers/protection_controller_sfunc.m; controllers/relay_contactor_sfunc.m";"evaluation/validate_results.m";"controllers/microinverter_averaged_sfunc.m; model/Microinverter_Switching_Demo.slx";"docs/Design_Assumptions.md";"simulation/run_paired_protection_comparisons.m";"controllers/dc_bus_sfunc.m; evaluation/evaluate_solver_convergence.m"];
n=numel(ids); tests=strings(n,1); assertionIDs=strings(n,1); metrics=strings(n,1); values=strings(n,1); conditions=strings(n,1); evidenceStatus=strings(n,1); verification=strings(n,1);
for k=1:n
 evidence=assertions(assertions.Requirement_ID==ids(k),:);
 if isempty(evidence)
  verification(k)="NOT_VERIFIED"; continue;
 end
 passed=evidence(evidence.Status=="PASS",:); failed=evidence(evidence.Status=="FAIL" & evidence.Severity~="INFO",:);
 if ~isempty(passed) && isempty(failed), verification(k)="VERIFIED";
 elseif ~isempty(passed), verification(k)="PARTIALLY_VERIFIED";
 else, verification(k)="NOT_VERIFIED"; end
 tests(k)=strjoin(unique(evidence.Test_ID),', '); assertionIDs(k)=strjoin(evidence.Assertion_ID,', ');
 metrics(k)=strjoin(evidence.Metric,'; '); values(k)=strjoin(evidence.Actual_Value,'; ');
 conditions(k)=strjoin(evidence.Expected_Condition,'; '); evidenceStatus(k)=strjoin(unique(evidence.Status),', ');
end
T=table(ids,req,sub,impl,tests,assertionIDs,metrics,values,conditions,evidenceStatus,verification, ...
 'VariableNames',{'Requirement_ID','Proposal_Requirement','Implemented_Subsystem','Implementation_File','Test_ID','Assertion_ID','Measured_Metric','Actual_Value','Acceptance_Condition','Actual_Status','Verification_Status'});
verified=T.Verification_Status=="VERIFIED";
for k=find(verified)'
 assert(any(assertions.Requirement_ID==T.Requirement_ID(k) & assertions.Status=="PASS"), ...
  'VERIFIED requirement %s has no same-ID passing assertion.',T.Requirement_ID(k));
end
end
