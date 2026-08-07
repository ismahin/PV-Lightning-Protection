function validation = validate_results(result,metrics,P)
%VALIDATE_RESULTS Individual final-design and intentional-overstress checks.
s=result.signals; q=result.scenario; rows=cell(0,10); seq=0; id=char(q.Test_ID); nominal=P.bus.nominalVoltage_V;
add(metrics.nanInfCount==0,"PR-11","Finite critical signals","NaN/Inf count = 0",metrics.nanInfCount,0,"CRITICAL","Critical histories are finite");
add(metrics.peakSCCurrent_A<=P.sc.maximumCurrent_A*1.001,"PR-06","SC actual current","<= converter limit",metrics.peakSCCurrent_A,P.sc.maximumCurrent_A,"ERROR","Converter current is bounded");
add(~metrics.unexpectedSCVoltageViolation,"PR-05","SC internal voltage","inside permitted range",metrics.scInternalMax_V,P.sc.ratedVoltage_V,"ERROR","Internal voltage is bounded");
esrError=max(abs((s.sc_terminal_voltage.Data-s.sc_internal_voltage.Data)-s.sc_actual_current.Data*P.sc.ESR_Ohm));
add(esrError<1e-8,"PR-06","SC terminal-voltage equation","Vterminal = Vinternal + Isc*ESR",esrError,1e-8,"ERROR","Positive current is charging from bus into SC");
add(all(s.sc_esr_power.Data>=-eps),"PR-06","SC ESR loss sign","Isc^2*ESR >= 0",min(s.sc_esr_power.Data),0,"ERROR","ESR loss is nonnegative");
charge=s.sc_actual_current.Data>1e-6; discharge=s.sc_actual_current.Data<-1e-6; p=s.sc_terminal_voltage.Data.*s.sc_actual_current.Data;
add(~any(charge) || all(p(charge)>=0),"PR-05","Charging-energy sign","charging power positive",minOrNaN(p(charge)),0,"ERROR","Charging produces positive absorbed power");
add(~any(discharge) || all(-p(discharge)>=0),"PR-05","Released-energy sign","discharge magnitude positive",minOrNaN(-p(discharge)),0,"ERROR","Discharging produces positive released-energy magnitude");
add(~isequal(s.sc_converter_enabled.Data>0.5,s.sc_current_limit_flag.Data>0.5),"PR-06","SC enable/limit independence","logged signals not identical",double(isequal(s.sc_converter_enabled.Data,s.sc_current_limit_flag.Data)),0,"ERROR","Enable and current-limit ports are independent");
add(metrics.settlingStartTime_s>=expectedSettlingStart(q,metrics)-P.sim.Ts,"PR-15","Settling measurement start","at/after relevant event",metrics.settlingStartTime_s,expectedSettlingStart(q,metrics),"ERROR","No pre-event stable interval is accepted");
add(isnan(metrics.settlingTime_s) || metrics.settlingTime_s>=0,"PR-15","Elapsed settling time","nonnegative or NaN",metrics.settlingTime_s,0,"ERROR","Settling is elapsed duration");
add((isfinite(metrics.settlingTime_s) && metrics.settlingStableDwellContinuous) || (isnan(metrics.settlingTime_s) && strlength(metrics.settlingMessage)>0),"PR-15","Continuous settling dwell","continuous or explained NaN",double(metrics.settlingStableDwellContinuous),1,"ERROR","Settling result has continuous dwell or explanation");
if ~q.IsIntentionalOverstress && q.Protection_Mode>=1
 add(~metrics.spdCurrentCapabilityExceeded,"PR-03","Design SPD current rating","within selected capability",metrics.peakSPDDemandedCurrent_A,P.spd.maxCurrent_A,"CRITICAL","Design case remains within current rating");
 add(~metrics.spdEnergyCapabilityExceeded,"PR-03","Design SPD energy rating","within selected capability",metrics.spdCumulativeEnergy_J,P.spd.energyRating_J,"CRITICAL","Design case remains within energy rating");
end
switch id
 case 'T01'
  tail=s.time>q.Analysis_End-0.2;
  add(max(abs(s.dc_bus_voltage.Data(tail)-nominal))<=0.05*nominal,"PR-01","Steady bus voltage","within +/-5%",max(abs(s.dc_bus_voltage.Data(tail)-nominal)),0.05*nominal,"ERROR","Bus stable after startup");
  add(all(s.relay_state.Data>0.5),"PR-08","Relay state","closed",min(s.relay_state.Data),1,"ERROR","No false isolation");
  add(metrics.mpptEfficiency_percent>=P.validation.minimumMPPTPercent,"PR-02","Steady MPPT efficiency",">= configured threshold",metrics.mpptEfficiency_percent,P.validation.minimumMPPTPercent,"ERROR","Unified-model MPPT efficiency");
 case 'T02'
  add(metrics.irradianceStepConfirmed,"PR-02","Irradiance step","measured",double(metrics.irradianceStepConfirmed),1,"ERROR","Input step occurred");
  add(metrics.availableMPPChanged,"PR-02","Available MPP change","changed >10%",double(metrics.availableMPPChanged),1,"ERROR","Available MPP responded");
  add(isfinite(metrics.mpptRecoveryTime_s),"PR-02","MPPT recovery time","finite",metrics.mpptRecoveryTime_s,q.Event_End-q.Event_Start,"ERROR","Tracking recovered after step");
  add(metrics.mpptPostStepEfficiency_percent>=P.validation.minimumMPPTPercent,"PR-02","Post-step efficiency",">= threshold",metrics.mpptPostStepEfficiency_percent,P.validation.minimumMPPTPercent,"ERROR","Post-step efficiency passed");
  add(all(s.relay_state.Data>0.5),"PR-08","Irradiance relay state","closed",min(s.relay_state.Data),1,"ERROR","No false trip");
 case 'T03'
  add(max(s.surge_injected.Data)>nominal,"PR-04","Ripple injection","above nominal",max(s.surge_injected.Data),nominal,"ERROR","Ripple occurred");
  add(all(s.relay_state.Data>0.5),"PR-08","Brief-event relay","closed",min(s.relay_state.Data),1,"ERROR","Brief event retained load");
  add(any(s.controller_state.Data>1),"PR-07","Controller transition","recognized disturbance",max(s.controller_state.Data),2,"ERROR","Controller responded");
  add(s.controller_state.Data(end)==1,"PR-07","Final controller state","NORMAL",s.controller_state.Data(end),1,"ERROR","Controller returned to NORMAL");
 case 'T04'
  conductionCorrect=metrics.peakBus_V<=P.spd.kneeVoltage_V || metrics.peakSPDCurrent_A>10*P.spd.leakage_A;
  add(conductionCorrect,"PR-03","MOV conduction coordination","conducts when bus exceeds knee voltage",metrics.peakSPDCurrent_A,P.spd.kneeVoltage_V,"ERROR","MOV behavior matches its nonlinear knee");
  add(isfinite(metrics.scIncrementalEventEnergy_J),"PR-05","SC event energy","calculated",metrics.scIncrementalEventEnergy_J,NaN,"ERROR","Incremental event energy calculated");
  add(all(s.relay_state.Data>0.5),"PR-08","Moderate-event relay","closed",min(s.relay_state.Data),1,"ERROR","No unnecessary isolation");
 case {'T05','T08'}
  add(metrics.emergencyObserved,"PR-09","Emergency flag","asserted",double(metrics.emergencyObserved),1,"ERROR","Emergency magnitude detected");
  add(isfinite(metrics.relayOpeningTime_s),"PR-09","Physical isolation","relay opened",metrics.relayOpeningTime_s,q.Event_End,"ERROR","Emergency isolation completed");
 case 'T06'
  add(countPulses(s.surge_injected.Data)==q.Pulse_Count,"PR-04","Repeated pulse count","equals configured",countPulses(s.surge_injected.Data),q.Pulse_Count,"ERROR","All repeated pulses occurred");
  add(metrics.relayTransitions<=2,"PR-07","Repeated-event relay transitions","no chatter",metrics.relayTransitions,2,"ERROR","No relay chatter");
 case 'T07'
  add(isfinite(metrics.thresholdCrossingTime_s),"PR-07","Warning detection time","measured",metrics.thresholdCrossingTime_s,q.Event_Start,"ERROR","Threshold crossing logged");
  add(isfinite(metrics.tripCommandTime_s) && metrics.tripCommandTime_s-metrics.thresholdCrossingTime_s>=P.controller.allowedDuration_s-P.sim.Ts,"PR-09","Trip persistence","full allowed duration",metrics.tripCommandTime_s-metrics.thresholdCrossingTime_s,P.controller.allowedDuration_s,"ERROR","Magnitude-duration delay honored");
  add(isfinite(metrics.relayOpeningTime_s) && metrics.relayOpeningTime_s-metrics.tripCommandTime_s>=P.relay.openingDelay_s-P.sim.Ts,"PR-10","Physical opening delay","after command delay",metrics.relayOpeningTime_s-metrics.tripCommandTime_s,P.relay.openingDelay_s,"ERROR","Contactor opening delay honored");
 case 'T09'
  safeOpen=s.time>=metrics.safeIntervalStartTime_s & s.time<metrics.reconnectCommandTime_s;
  add(isfinite(metrics.safeIntervalStartTime_s),"PR-10","Safe interval start","measured",metrics.safeIntervalStartTime_s,q.Fault_Clear_Time,"ERROR","Continuous safe interval logged");
  add(metrics.actualSafeDwell_s>=P.controller.recoveryDelay_s-P.sim.Ts,"PR-10","Automatic recovery dwell","full uninterrupted dwell",metrics.actualSafeDwell_s,P.controller.recoveryDelay_s,"ERROR","Reconnect command is not early");
  add(any(safeOpen) && all(s.relay_state.Data(safeOpen)<0.5),"PR-10","Relay during safe dwell","physically open",maxOrNaN(s.relay_state.Data(safeOpen)),0,"ERROR","Relay remains open throughout dwell");
  add(any(safeOpen) && max(abs(s.downstream_current.Data(safeOpen)))<0.05,"PR-10","Isolated load current","near zero",maxOrNaN(abs(s.downstream_current.Data(safeOpen))),0.05,"ERROR","Downstream current is near zero while isolated");
  add(metrics.relayClosingTime_s-metrics.reconnectCommandTime_s>=P.relay.closingDelay_s-P.sim.Ts,"PR-10","Physical closing delay","after reconnect command",metrics.relayClosingTime_s-metrics.reconnectCommandTime_s,P.relay.closingDelay_s,"ERROR","Contactor closing delay honored");
  add(metrics.relayTransitions==2,"PR-10","Recovery relay transitions","one open, one close",metrics.relayTransitions,2,"ERROR","No reconnection chatter");
 case 'T10'
  hold=s.time>=q.Fault_Clear_Time & s.time<q.ManualResetTime;
  add(~q.AutoReset,"PR-10","Automatic reset","disabled",double(q.AutoReset),0,"ERROR","Manual reset configured");
  add(any(hold) && all(s.relay_state.Data(hold)<0.5),"PR-10","Manual hold","relay remains open",maxOrNaN(s.relay_state.Data(hold)),0,"ERROR","No automatic reconnect");
  add(isfinite(metrics.relayClosingTime_s) && metrics.relayClosingTime_s>=q.ManualResetTime,"PR-10","Manual reconnection","after reset",metrics.relayClosingTime_s,q.ManualResetTime,"ERROR","Manual reset controls closing");
 case 'T12'
  add(max(abs(s.sc_current_command_raw.Data))>=P.sc.maximumCurrent_A,"PR-06","SC current demand","reaches converter limit",max(abs(s.sc_current_command_raw.Data)),P.sc.maximumCurrent_A,"ERROR","Limit stimulus is adequate");
  add(metrics.currentLimitObserved && metrics.currentLimitDuration_s>0,"PR-06","SC current-limit flag","active with duration",metrics.currentLimitDuration_s,P.sim.Ts,"ERROR","Current limiting is logged");
  add(metrics.spdCapabilityStatus=="SAFE","PR-03","SC-test SPD status","SAFE",metrics.spdCapabilityStatus,"SAFE","ERROR","SC test is not an accidental SPD test");
 case 'T13'
  add(q.NoiseStd_V>0,"PR-07","Sensor noise","configured",q.NoiseStd_V,0,"ERROR","Noise stimulus active");
  add(metrics.relayTransitions==0,"PR-07","Noise false trips","none",metrics.relayTransitions,0,"ERROR","Noise does not trip relay");
 case 'T14'
  add(max(s.inverter_requested_power.Data)>0,"PR-12","Averaged inverter request","nonzero",max(s.inverter_requested_power.Data),P.load.requestedACPower_W,"ERROR","Power-based inverter ran");
  add(isfinite(metrics.relayOpeningTime_s),"PR-12","Inverter relay isolation","occurred",metrics.relayOpeningTime_s,q.Event_End,"ERROR","Protected inverter isolated");
 case 'T16'
  add(metrics.spdCurrentCapabilityExceeded || metrics.spdEnergyCapabilityExceeded,"PR-03","Intentional SPD overstress","capability exceeded",double(metrics.expectedOverstressDetection),1,"EXPECTED_OVERSTRESS","Dedicated out-of-envelope event detected");
  add(metrics.spdCapabilityStatus=="OVERSTRESSED" || metrics.spdCapabilityStatus=="FAILED","PR-03","Intentional component state","OVERSTRESSED or FAILED",metrics.spdCapabilityStatus,"OVERSTRESSED","EXPECTED_OVERSTRESS","Capability state is explicit");
end
A=cell2table(rows,'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
failed=A.Status=="FAIL" & ~ismember(A.Severity,["INFO","EXPECTED_OVERSTRESS"]); passed=~any(failed);
validation=struct('Status',string(localStatus(passed)),'Passed',passed,'Message',strjoin(A.Message(A.Status=="FAIL"),'; '),'Assertions',A);
 function add(condition,requirement,metric,expected,actual,tolerance,severity,message)
  seq=seq+1; st="PASS"; if ~condition, st="FAIL"; end
  rows(end+1,:)={sprintf('%s-A%02d',id,seq),string(q.Test_ID),string(requirement),string(metric),string(expected),valueString(actual),valueString(tolerance),st,string(severity),string(message)};
 end
end

function value=expectedSettlingStart(q,m)
if ismember(string(q.Test_ID),["T09","T10"]) && isfinite(m.relayClosingTime_s)
 value=m.relayClosingTime_s;
elseif q.Test_ID=="T02"
 value=q.Event_Start;
elseif q.Surge_Type=="sustained"
 value=q.Fault_Clear_Time;
elseif q.Surge_Type=="disabled"
 value=q.Startup_Exclusion_Time;
else
 value=q.Event_End;
end
end
function n=countPulses(y), threshold=0.4*max(y); n=sum(diff([false;y>threshold])==1); end
function v=minOrNaN(x), if isempty(x), v=NaN; else, v=min(x); end, end
function v=maxOrNaN(x), if isempty(x), v=NaN; else, v=max(x); end, end
function s=valueString(v), if isnumeric(v)&&isscalar(v), s=string(sprintf('%.9g',v)); else, s=string(v); end, end
function s=localStatus(tf), if tf, s='PASS'; else, s='FAIL'; end, end
