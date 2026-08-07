function M = calculate_transient_metrics(s,P,scenario)
%CALCULATE_TRANSIENT_METRICS Event magnitudes and elapsed settling/timing.
t=s.time; v=s.dc_bus_voltage.Data; nominal=P.bus.nominalVoltage_V; dt=median(diff(t));
event=t>=scenario.Event_Start & t<=scenario.Event_End;
analysis=t>=scenario.Startup_Exclusion_Time & t<=scenario.Analysis_End;
pre=t>=max(scenario.Startup_Exclusion_Time,scenario.Event_Start-0.03) & t<scenario.Event_Start;
baseline=t>=scenario.Startup_Exclusion_Time & t<scenario.Event_Start;
if any(baseline), M.nominalBus_V=median(v(baseline)); else, M.nominalBus_V=nominal; end
M.peakBus_V=max(v(event)); M.minBus_V=min(v(analysis)); M.overshoot_percent=100*(M.peakBus_V-nominal)/nominal;
q=event & s.spd_current.Data>max(0.01,10*P.spd.leakage_A);
if any(q), M.spdClamping_V=max(s.spd_voltage.Data(q)); else, M.spdClamping_V=NaN; end
M.peakSPDDemandedCurrent_A=max(s.spd_demanded_current.Data(event));
M.peakSPDCurrent_A=max(abs(s.spd_current.Data(event)));
M.spdCurrentUtilization_percent=100*M.peakSPDDemandedCurrent_A/P.spd.maxCurrent_A;
M.spdSaturationDuration_s=max(s.spd_saturation_duration.Data(event),[],'omitmissing');
M.peakSCCurrent_A=max(abs(s.sc_actual_current.Data(event)));
M.scInternalMin_V=min(s.sc_internal_voltage.Data(analysis)); M.scInternalMax_V=max(s.sc_internal_voltage.Data(analysis));
M.scTerminalMin_V=min(s.sc_terminal_voltage.Data(analysis)); M.scTerminalMax_V=max(s.sc_terminal_voltage.Data(analysis));
M.scOvervoltageObserved=any(s.sc_overvoltage_flag.Data>0.5); M.scUndervoltageObserved=any(s.sc_undervoltage_flag.Data>0.5);
outside=analysis & (v<0.95*nominal | v>1.05*nominal); M.timeOutsideSafeBand_s=sum(outside)*dt;
M.thresholdCrossingTime_s=firstFinite(s.threshold_crossing_time.Data);
M.tripCommandTime_s=firstFinite(s.trip_command_time.Data); M.relayOpeningTime_s=firstFinite(s.relay_opening_time.Data);
M.safeIntervalStartTime_s=lastFinite(s.safe_interval_start_time.Data);
M.safeIntervalInterruptionCount=max(s.safe_interval_interruption_count.Data);
M.reconnectCommandTime_s=firstFinite(s.reconnect_command_time.Data); M.relayClosingTime_s=lastFinite(s.relay_closing_time.Data);
M.faultClearTime_s=scenario.Fault_Clear_Time; M.relayTripTime_s=M.relayOpeningTime_s; M.reconnectionTime_s=M.relayClosingTime_s;
M.configuredRecoveryDelay_s=P.controller.recoveryDelay_s;
if isfinite(M.safeIntervalStartTime_s) && isfinite(M.reconnectCommandTime_s)
 M.actualSafeDwell_s=M.reconnectCommandTime_s-M.safeIntervalStartTime_s;
else
 M.actualSafeDwell_s=NaN;
end
if ismember(string(scenario.Test_ID),["T09","T10"]) && isfinite(M.relayClosingTime_s)
 settleStart=M.relayClosingTime_s;
elseif scenario.Test_ID=="T02"
 settleStart=scenario.Event_Start;
elseif scenario.Surge_Type=="sustained"
 settleStart=scenario.Fault_Clear_Time;
elseif scenario.Surge_Type=="disabled"
 settleStart=scenario.Startup_Exclusion_Time;
else
 settleStart=scenario.Event_End;
end
[M.settlingTime_s,M.settlingStableDwellContinuous,M.settlingMessage]=findSettling(t,v,settleStart,nominal,P.analysis.settlingDwell_s,dt);
M.settlingStartTime_s=settleStart;
M.relayTransitions=sum(abs(diff(s.relay_state.Data))>0.5); M.controllerTransitions=sum(abs(diff(s.controller_state.Data))>0.5);
M.falseTrips=sum(diff(s.relay_state.Data)<-0.5 & s.warning_flag.Data(2:end)<0.5 & s.emergency_flag.Data(2:end)<0.5);
if any(pre)
 M.preEventRelayClosed=all(s.relay_state.Data(pre)>0.5);
 M.preEventLoadCurrent_A=mean(s.downstream_current.Data(pre));
 M.preEventProtectionArmed=all(s.protection_armed.Data(pre)>0.5);
else
 M.preEventRelayClosed=false; M.preEventLoadCurrent_A=NaN; M.preEventProtectionArmed=false;
end
end

function value=firstFinite(x)
q=x(isfinite(x)); if isempty(q), value=NaN; else, value=q(1); end
end

function value=lastFinite(x)
q=x(isfinite(x)); if isempty(q), value=NaN; else, value=q(end); end
end

function [elapsed,continuous,message]=findSettling(t,v,startTime,nominal,dwell,dt)
elapsed=NaN; continuous=false; message="Signal did not settle for the required continuous dwell";
within=abs(v-nominal)<=0.05*nominal; n=max(1,ceil(dwell/dt)); candidates=find(t>=startTime);
for k=reshape(candidates,1,[])
 last=k+n-1;
 if last<=numel(t) && all(within(k:last))
  elapsed=max(0,t(k)-startTime); continuous=true; message="Continuous stable dwell verified"; return;
 end
end
end
