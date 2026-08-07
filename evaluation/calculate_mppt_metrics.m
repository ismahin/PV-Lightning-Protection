function M = calculate_mppt_metrics(s,scenario,P)
%CALCULATE_MPPT_METRICS Same-model integral tracking metrics.
t=s.time; actual=max(s.pv_power.Data,0); available=max(s.theoretical_mpp_power.Data,eps);
startup=t>=0 & t<scenario.Startup_Exclusion_Time; steady=t>=max(scenario.Startup_Exclusion_Time,scenario.Event_Start-0.20) & t<scenario.Event_Start;
if scenario.Surge_Type=="disabled" && scenario.Test_ID~="T02", steady=t>=max(scenario.Startup_Exclusion_Time,scenario.Analysis_End-0.30) & t<=scenario.Analysis_End; end
M.startupEfficiency_percent=eff(startup); M.steadyEfficiency_percent=eff(steady);
M.steadyTrackingError_percent=100*mean(abs(actual(steady)-available(steady))./available(steady));
M.dutyCycleRipple=std(s.mppt_duty.Data(steady)); M.irradianceStepConfirmed=false; M.availableMPPChanged=false; M.recoveryTime_s=NaN; M.postStepEfficiency_percent=NaN;
if scenario.Test_ID=="T02"
 stepTime=scenario.Event_Start; pre=t>=stepTime-0.15 & t<stepTime; post=t>=stepTime+0.05 & t<min(scenario.Event_End,stepTime+0.40);
 M.irradianceStepConfirmed=abs(mean(s.irradiance.Data(post))-mean(s.irradiance.Data(pre)))>50;
 M.availableMPPChanged=abs(mean(available(post))-mean(available(pre)))>0.1*mean(available(pre));
 ratio=actual./available; dt=median(diff(t)); n=max(1,ceil(P.analysis.settlingDwell_s/dt)); good=ratio>=P.validation.minimumMPPTPercent/100; stable=movmin(double(good),[0 n-1])>=1;
 q=find(t>=stepTime & t<scenario.Event_End & stable,1); if ~isempty(q), M.recoveryTime_s=t(q)-stepTime; end
 M.postStepEfficiency_percent=eff(post);
end
 function value=eff(mask), if nnz(mask)>1, value=100*trapz(t(mask),actual(mask))/trapz(t(mask),available(mask)); else, value=NaN; end, end
end
