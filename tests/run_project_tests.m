function summary = run_project_tests(P,S)
%RUN_PROJECT_TESTS Fast parameter, waveform, and controller assertions.
tests=0; passed=0; messages=strings(0,1);
runcheck(P.pv.Voc_V>P.pv.Vmp_V && P.pv.Isc_A>P.pv.Imp_A,'PV ratings ordered');
runcheck(P.mppt.dutyMin<P.mppt.initialDuty && P.mppt.initialDuty<P.mppt.dutyMax,'MPPT duty bounds');
runcheck(P.sc.maximumEnergy_J>0 && P.sc.ratedVoltage_V>P.sc.initialVoltage_V,'SC finite rating');
runcheck(P.protection.startupBlanking_s+P.protection.armStableDuration_s<P.analysis.startupExclusion_s,'Protection arms before analysis window');
runcheck(P.spd.currentDesignMargin>=1.2 && P.spd.energyDesignMargin>=1.2,'SPD design margins configured');
runcheck(P.sim.Ts<=2.5e-4 && P.validation.solverTolerance_percent<=3,'Production solver and tolerance strengthened');
q=S(4); t=(0:P.sim.Ts:q.StopTime)'; y=prepare_surge_waveform(t,q,P);
runcheck(abs(max(y)-q.Surge_Peak)<0.01*q.Surge_Peak,'surge peak normalization');
runcheck(all(y(t<q.Surge_Start_Time)==0),'surge start time');
runcheck(abs(y(end))<0.01*q.Surge_Peak,'surge tail decay');
state=1; to=0; ts=0; relay=true;
for k=1:round((P.controller.allowedDuration_s+0.02)/P.sim.Ts)
 [state,relay,to,ts]=protection_logic(1.2*P.bus.nominalVoltage_V,state,to,ts,false,true,P,P.sim.Ts);
end
runcheck(~relay && state==4,'persistent warning isolates');
[state,relay]=protection_logic(1.6*P.bus.nominalVoltage_V,1,0,0,false,true,P,P.sim.Ts);
runcheck(~relay && state==4,'emergency isolates');
v=32; iCharge=5; vt=v+iCharge*P.sc.ESR_Ohm; runcheck(abs((vt-v)-iCharge*P.sc.ESR_Ohm)<1e-12,'SC charging sign and ESR equation');
runcheck(iCharge^2*P.sc.ESR_Ohm>=0,'SC ESR energy sign');
summary=struct('Total',tests,'Passed',passed,'Failed',tests-passed,'Messages',messages);
if summary.Failed>0, error('Project unit tests failed: %s',strjoin(messages(contains(messages,'FAIL')),'; ')); end
 function runcheck(condition,label)
  tests=tests+1;
  if condition, passed=passed+1; messages(end+1)=string(label)+": PASS"; else, messages(end+1)=string(label)+": FAIL"; end
 end
end
