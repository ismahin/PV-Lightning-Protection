function [pairResults,T,assertions] = run_paired_protection_comparisons(S,P,modelPath)
%RUN_PAIRED_PROTECTION_COMPARISONS Four fair event definitions x four modes.
eventIDs=["T04","T05","T06","T07"];
modeNames=["Unprotected","SPD only","SPD + conventional relay","Integrated proposed"];
pairResults=cell(numel(eventIDs),4); rows=cell(0,19); assertionRows=cell(0,10); aseq=0;
for e=1:numel(eventIDs)
 base=S(find(string({S.Test_ID})==eventIDs(e),1)); configs=cell(4,1); metrics=cell(4,1); comparable=true; reasons=strings(0,1);
 for mode=0:3
  q=base; q.Protection_Mode=mode; q.Test_ID=eventIDs(e)+"_M"+mode;
  configs{mode+1}=configure_scenario(q,P);
  pairResults{e,mode+1}=run_single_scenario(q,P,modelPath);
  metrics{mode+1}=evaluate_scenario(pairResults{e,mode+1},P);
 end
 checks=[sameColumn(configs,4),sameColumn(configs,2),sameColumn(configs,3),sameColumn(configs,9), ...
  sameColumn(configs,1),sameInitialConditions(P)];
 labels=["Identical surge profile","Identical irradiance profile","Identical temperature profile", ...
  "Identical load profile","Identical solver/time profile","Identical initial conditions"];
 for c=1:numel(checks)
  add(checks(c),eventIDs(e),"PR-14",labels(c),"identical in all four modes",double(checks(c)),1,"CRITICAL","Paired-condition verification");
  if ~checks(c), comparable=false; reasons(end+1)=labels(c); end
 end
 for mode=0:3
  m=metrics{mode+1}; preClosed=m.preEventRelayClosed; energized=m.preEventLoadCurrent_A>P.validation.preEventCurrentMinimum_A;
  add(preClosed,eventIDs(e),"PR-14",modeNames(mode+1)+" pre-event relay","CLOSED",double(preClosed),1,"CRITICAL","Relay closed immediately before event");
  add(energized,eventIDs(e),"PR-14",modeNames(mode+1)+" pre-event load current","nonzero",m.preEventLoadCurrent_A,P.validation.preEventCurrentMinimum_A,"CRITICAL","Load energized immediately before event");
  if mode>=2
   add(m.preEventProtectionArmed,eventIDs(e),"PR-07",modeNames(mode+1)+" protection arming","ARMED",double(m.preEventProtectionArmed),1,"CRITICAL","Protection qualified before event");
   if ~m.preEventProtectionArmed, comparable=false; reasons(end+1)=modeNames(mode+1)+" not armed"; end
  end
  if ~preClosed || ~energized, comparable=false; reasons(end+1)=modeNames(mode+1)+" unhealthy before event"; end
 end
 unprotectedPeak=metrics{1}.peakBus_V; unprotectedLoad=metrics{1}.loadEventEnergy_J;
 comparisonStatus="VALID"; comparisonMessage="All non-protection inputs and pre-event health checks passed";
 if ~comparable, comparisonStatus="INVALID"; comparisonMessage=strjoin(unique(reasons),'; '); end
 for mode=0:3
  m=metrics{mode+1}; reduction=NaN; relativeEnergy=NaN; improvement=NaN; energyNote="Unprotected reference";
  if comparable && mode>0, reduction=100*(unprotectedPeak-m.peakBus_V)/unprotectedPeak; end
  if comparable && unprotectedLoad>P.validation.percentageDenominatorEpsilon_J
   relativeEnergy=100*m.loadEventEnergy_J/unprotectedLoad;
   improvement=100*(m.loadEventEnergy_J-unprotectedLoad)/unprotectedLoad;
   energyNote="Defined from paired unprotected event energy";
  elseif comparable
   energyNote="Undefined: unprotected event energy is zero or near zero";
  end
  rows(end+1,:)={eventIDs(e),mode,modeNames(mode+1),m.peakBus_V,reduction,m.peakSPDDemandedCurrent_A, ...
   m.peakSPDCurrent_A,m.spdEventEnergy_J,m.scIncrementalEventEnergy_J,m.scESREventLoss_J, ...
   m.relayOpeningTime_s,m.loadEventEnergy_J,relativeEnergy,improvement,energyNote,m.spdCapabilityStatus, ...
   comparisonStatus,comparisonMessage,string(localStatus(comparable))};
 end
 if comparable
  add(metrics{2}.peakBus_V<unprotectedPeak,eventIDs(e),"PR-14","SPD peak reduction","SPD-only peak < unprotected",metrics{2}.peakBus_V,unprotectedPeak,"ERROR","SPD reduces paired peak");
  add(metrics{4}.peakBus_V<=1.05*metrics{2}.peakBus_V,eventIDs(e),"PR-14","Integrated peak trade-off","<=105% SPD-only peak",metrics{4}.peakBus_V,1.05*metrics{2}.peakBus_V,"ERROR","Integrated protection trade-off accepted");
  if eventIDs(e)=="T04", add(all(pairResults{e,4}.signals.relay_state.Data>0.5),eventIDs(e),"PR-08","Brief-event continuity","integrated relay closed",min(pairResults{e,4}.signals.relay_state.Data),1,"ERROR","No unnecessary isolation"); end
  if eventIDs(e)=="T07", add(isfinite(metrics{4}.relayOpeningTime_s),eventIDs(e),"PR-09","Prolonged-event isolation","integrated relay opens",metrics{4}.relayOpeningTime_s,base.Event_End,"ERROR","Prolonged event isolated"); end
 end
end
T=cell2table(rows,'VariableNames',{'Event_ID','Protection_Mode','Mode_Name','Peak_DC_Bus_V', ...
 'Paired_Voltage_Reduction_Percent','SPD_Demanded_Peak_Current_A','SPD_Actual_Peak_Current_A', ...
 'SPD_Event_Energy_J','SC_Incremental_Event_Energy_J','SC_ESR_Loss_J','Physical_Relay_Open_Time_s', ...
 'Event_Load_Energy_J','Relative_Event_Load_Energy_Percent','Load_Energy_Improvement_Percent', ...
 'Load_Energy_Comparison_Note','SPD_Status','Comparison_Status','Comparison_Message','Validation_Status'});
assertions=cell2table(assertionRows,'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
 function add(condition,testID,requirement,metric,expected,actual,tolerance,severity,message)
  aseq=aseq+1; st="PASS"; if ~condition, st="FAIL"; end
  assertionRows(end+1,:)={sprintf('PAIR-A%03d',aseq),string(testID),string(requirement),string(metric),string(expected),string(actual),string(tolerance),st,string(severity),string(message)};
 end
end

function tf=sameColumn(configs,column)
tf=true; reference=configs{1}(:,column);
for k=2:numel(configs), tf=tf && isequaln(reference,configs{k}(:,column)); end
end
function tf=sameInitialConditions(P)
values=[P.bus.prechargeVoltage_V P.pv.Vmp_V P.sc.initialVoltage_V P.mppt.initialDuty P.boost.Cout_F]; tf=all(isfinite(values));
end
function s=localStatus(tf), if tf, s='PASS'; else, s='FAIL'; end, end
