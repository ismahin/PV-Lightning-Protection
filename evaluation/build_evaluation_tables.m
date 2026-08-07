function [summary,spdCapability,componentChecks,mpptValidation,scValidation] = build_evaluation_tables(results,metrics,validations,P,pairs)
%BUILD_EVALUATION_TABLES Final schemas derived only from executed histories.
n=numel(results); rows=cell(n,41); spdRows=cell(n,18); compRows=cell(n,13); mpptRows=cell(0,9); scRows=cell(n,15);
designMask=cellfun(@(r)~r.scenario.IsIntentionalOverstress,results);
worstDesignCurrent=max(cellfun(@(m)m.peakSPDDemandedCurrent_A,metrics(designMask)));
worstDesignEnergy=max(cellfun(@(m)m.spdEventEnergy_J,metrics(designMask)));
actualCurrentMargin=P.spd.maxCurrent_A/max(worstDesignCurrent,eps); actualEnergyMargin=P.spd.energyRating_J/max(worstDesignEnergy,eps);
for k=1:n
 r=results{k}; m=metrics{k}; v=validations{k}; q=r.scenario;
 reduction=NaN; relativeEnergy=NaN; improvement=NaN;
 pq=pairs(string(pairs.Event_ID)==string(q.Test_ID) & pairs.Protection_Mode==q.Protection_Mode,:);
 if height(pq)==1 && pq.Comparison_Status=="VALID"
  reduction=pq.Paired_Voltage_Reduction_Percent; relativeEnergy=pq.Relative_Event_Load_Energy_Percent; improvement=pq.Load_Energy_Improvement_Percent;
 end
 if m.unexpectedComponentViolations==0
  componentStatus="PASS";
 else
  componentStatus="FAIL";
 end
 if q.IsIntentionalOverstress && m.expectedOverstressDetection, componentStatus="EXPECTED_OVERSTRESS"; end
 rows(k,:)={q.Test_ID,q.Description,q.Protection_Mode,q.Surge_Type,q.Event_Start,q.Event_End,m.peakBus_V,m.minBus_V,m.overshoot_percent,reduction, ...
  m.settlingStartTime_s,m.settlingTime_s,m.peakSPDDemandedCurrent_A,m.peakSPDCurrent_A,m.spdEventEnergy_J,m.spdCurrentUtilization_percent,m.spdEnergyUtilization_percent,m.spdCapabilityStatus, ...
  m.scEventAbsorbed_J,m.scEventReleased_J,m.scIncrementalEventEnergy_J,m.scESREventLoss_J,m.currentLimitDuration_s,m.scInternalMin_V,m.scInternalMax_V,m.scTerminalMin_V,m.scTerminalMax_V, ...
  m.thresholdCrossingTime_s,m.tripCommandTime_s,m.relayOpeningTime_s,m.safeIntervalStartTime_s,m.reconnectCommandTime_s,m.relayClosingTime_s,m.loadEventEnergy_J,relativeEnergy,improvement, ...
  m.mpptEfficiency_percent,m.mpptRecoveryTime_s,componentStatus,v.Status,v.Message};
 spdRows(k,:)={q.Test_ID,q.Design_Class,q.IsIntentionalOverstress,m.peakSPDDemandedCurrent_A,m.peakSPDCurrent_A,P.spd.maxCurrent_A,m.spdCurrentUtilization_percent,m.spdSaturationDuration_s, ...
  m.spdEventEnergy_J,P.spd.energyRating_J,100*m.spdEventEnergy_J/P.spd.energyRating_J,actualCurrentMargin,actualEnergyMargin,string(currentStatus(m)),string(energyStatus(m)),m.peakBus_V,m.spdCapabilityStatus,string(localStatus(v.Passed))};
 compRows(k,:)={q.Test_ID,m.unexpectedSPDCurrentViolation,m.unexpectedSPDEnergyViolation,m.unexpectedSCCurrentViolation,m.unexpectedSCVoltageViolation,m.peakSCCurrent_A,m.scInternalMin_V,m.scInternalMax_V,m.scTerminalMin_V,m.scTerminalMax_V,m.scESREventLoss_J,m.spdCapabilityStatus,componentStatus};
 scRows(k,:)={q.Test_ID,max(abs(r.signals.sc_current_command_raw.Data)),m.peakSCCurrent_A,m.currentLimitObserved,m.currentLimitDuration_s,m.scInternalMin_V,m.scInternalMax_V,m.scTerminalMin_V,m.scTerminalMax_V,m.scEventAbsorbed_J,m.scEventReleased_J,m.scIncrementalEventEnergy_J,m.scESREventLoss_J,any(r.signals.sc_converter_enabled.Data>0.5),componentStatus};
 if ismember(string(q.Test_ID),["T01","T02"])
  mpptRows(end+1,:)={q.Test_ID,m.mpptStartupEfficiency_percent,m.mpptEfficiency_percent,m.mpptPostStepEfficiency_percent,m.mpptRecoveryTime_s,m.mpptTrackingError_percent,m.dutyCycleRipple,m.irradianceStepConfirmed,string(localStatus(v.Passed))};
 end
end
summary=cell2table(rows,'VariableNames',{'Test_ID','Scenario','Protection_Mode','Event_Type','Event_Start_Time_s','Event_End_Time_s','Peak_DC_Bus_V','Min_DC_Bus_V','Overshoot_Percent','Paired_Voltage_Reduction_Percent','Settling_Start_Time_s','Settling_Time_s','SPD_Demanded_Peak_Current_A','SPD_Actual_Peak_Current_A','SPD_Event_Energy_J','SPD_Current_Utilization_Percent','SPD_Energy_Utilization_Percent','SPD_Status','SC_Event_Absorbed_Energy_J','SC_Event_Released_Energy_J','SC_Incremental_Event_Energy_J','SC_ESR_Loss_J','SC_Current_Limit_Duration_s','SC_Min_Internal_V','SC_Max_Internal_V','SC_Min_Terminal_V','SC_Max_Terminal_V','Fault_Detection_Time_s','Trip_Command_Time_s','Physical_Relay_Open_Time_s','Safe_Interval_Start_Time_s','Reconnect_Command_Time_s','Physical_Relay_Close_Time_s','Event_Load_Energy_J','Relative_Event_Load_Energy_Percent','Load_Energy_Improvement_Percent','MPPT_Steady_Efficiency_Percent','MPPT_Recovery_Time_s','Component_Limit_Status','Validation_Status','Validation_Message'});
spdCapability=cell2table(spdRows,'VariableNames',{'Test_ID','Design_Class','Intentional_Overstress','Demanded_Peak_Current_A','Actual_Peak_Current_A','Selected_Current_Rating_A','Current_Utilization_Percent','Saturation_Duration_s','Event_Energy_J','Selected_Energy_Rating_J','Energy_Utilization_Percent','Actual_Current_Design_Margin','Actual_Energy_Design_Margin','Current_Rating_Status','Energy_Rating_Status','Residual_Bus_Peak_V','Final_Component_State','Validation_Status'});
componentChecks=cell2table(compRows,'VariableNames',{'Test_ID','Unexpected_SPD_Current_Violation','Unexpected_SPD_Energy_Violation','Unexpected_SC_Current_Violation','Unexpected_SC_Voltage_Violation','Peak_SC_Current_A','SC_Internal_Min_V','SC_Internal_Max_V','SC_Terminal_Min_V','SC_Terminal_Max_V','SC_Event_ESR_Loss_J','SPD_Status','Component_Limit_Status'});
mpptValidation=cell2table(mpptRows,'VariableNames',{'Test_ID','Startup_Efficiency_Percent','Steady_Efficiency_Percent','PostStep_Efficiency_Percent','Recovery_Time_s','Steady_Tracking_Error_Percent','Duty_Cycle_Ripple','Irradiance_Step_Confirmed','Status'});
scValidation=cell2table(scRows,'VariableNames',{'Test_ID','Peak_Raw_Command_A','Peak_Actual_Current_A','Current_Limit_Observed','Current_Limit_Duration_s','Min_Internal_V','Max_Internal_V','Min_Terminal_V','Max_Terminal_V','Event_Absorbed_Energy_J','Event_Released_Energy_J','Incremental_Event_Energy_J','Event_ESR_Loss_J','Converter_Enabled_Observed','Status'});
 function s=currentStatus(m), if m.spdCurrentCapabilityExceeded, s='EXCEEDED'; else, s='WITHIN'; end, end
 function s=energyStatus(m), if m.spdEnergyCapabilityExceeded, s='EXCEEDED'; else, s='WITHIN'; end, end
end
function s=localStatus(tf), if tf, s='PASS'; else, s='FAIL'; end, end
