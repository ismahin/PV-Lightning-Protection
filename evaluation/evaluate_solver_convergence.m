function [T,assertions] = evaluate_solver_convergence(convergence,P)
%EVALUATE_SOLVER_CONVERGENCE Production step versus half production step.
a=evaluate_scenario(convergence.coarse,P); b=evaluate_scenario(convergence.fine,P);
names=["Peak DC-bus voltage";"Minimum DC-bus voltage";"Peak demanded SPD current"; ...
 "Peak actual SPD current";"SPD event energy";"SC event absorbed energy"; ...
 "SC event ESR loss";"Relay trip-command time";"Physical relay-opening time";"Reconnect time"];
fields={'peakBus_V','minBus_V','peakSPDDemandedCurrent_A','peakSPDCurrent_A','spdEventEnergy_J', ...
 'scEventAbsorbed_J','scESREventLoss_J','tripCommandTime_s','relayOpeningTime_s','reconnectCommandTime_s'};
n=numel(fields); production=zeros(n,1); halfStep=zeros(n,1); relative=zeros(n,1);
for k=1:n
 production(k)=a.(fields{k}); halfStep(k)=b.(fields{k});
 if isnan(production(k)) && isnan(halfStep(k))
  relative(k)=0;
 elseif xor(isnan(production(k)),isnan(halfStep(k)))
  relative(k)=Inf;
 else
  relative(k)=100*abs(production(k)-halfStep(k))/max(abs(halfStep(k)),1e-9);
 end
end
status=repmat("PASS",n,1); status(relative>P.validation.solverTolerance_percent)="FAIL";
T=table(names,repmat(P.sim.Ts,n,1),repmat(P.sim.Ts/2,n,1),production,halfStep,relative, ...
 repmat(P.validation.solverTolerance_percent,n,1),status, ...
 'VariableNames',{'Metric','Production_Step_s','Half_Production_Step_s','Production_Value','Half_Step_Value','Relative_Difference_Percent','Tolerance_Percent','Status'});
assertions=table("SOLVER-A"+compose('%02d',(1:n)'),repmat("T15",n,1),repmat("PR-15",n,1),names, ...
 repmat("relative difference <= 3%",n,1),string(relative),string(P.validation.solverTolerance_percent*ones(n,1)),status,repmat("ERROR",n,1),repmat("Final production-step convergence",n,1), ...
 'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
end
