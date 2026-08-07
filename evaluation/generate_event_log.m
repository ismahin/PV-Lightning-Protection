function T = generate_event_log(results,metrics)
%GENERATE_EVENT_LOG State transitions plus explicit protection timestamps.
rows=cell(0,13);
for k=1:numel(results)
 r=results{k}; s=r.signals; m=metrics{k}; state=s.controller_state.Data; relay=s.relay_state.Data;
 idx=unique([find(diff(state)~=0)+1;find(diff(relay)~=0)+1]);
 for q=reshape(idx,1,[])
  from=state(max(1,q-1)); to=state(q); typ="CONTROLLER_STATE";
  if relay(q)~=relay(max(1,q-1)), typ="PHYSICAL_RELAY"; end
  append(s.time(q),typ,from,to,s.dc_bus_voltage.Data(q),s.relay_command.Data(q),relay(q),"Measured transition");
 end
 appendMetric(m.thresholdCrossingTime_s,"FAULT_DETECTION","Warning/emergency threshold crossing");
 appendMetric(m.tripCommandTime_s,"TRIP_COMMAND","Controller trip command");
 appendMetric(m.relayOpeningTime_s,"PHYSICAL_OPEN","Contactor physically open");
 appendMetric(m.safeIntervalStartTime_s,"SAFE_INTERVAL_START","Start of uninterrupted safe interval leading to reconnect");
 appendMetric(m.reconnectCommandTime_s,"RECONNECT_COMMAND","Reconnect command after safe dwell");
 appendMetric(m.relayClosingTime_s,"PHYSICAL_CLOSE","Contactor physically closed");
end
T=cell2table(rows,'VariableNames',{'Test_ID','Event_Time_s','Event_Type','Controller_State_From','Controller_State_To','DC_Bus_V','Relay_Command','Relay_State','Fault_Clear_Time_s','Safe_Interval_Start_Time_s','Safe_Interval_Interruptions','Configured_Recovery_Dwell_s','Message'});
 function appendMetric(timeValue,type,message)
  if isfinite(timeValue)
   [~,ix]=min(abs(s.time-timeValue)); append(timeValue,type,NaN,NaN,s.dc_bus_voltage.Data(ix),s.relay_command.Data(ix),s.relay_state.Data(ix),message);
  end
 end
 function append(timeValue,type,from,to,bus,command,relayState,message)
  rows(end+1,:)={r.scenario.Test_ID,timeValue,type,from,to,bus,command,relayState,r.scenario.Fault_Clear_Time,m.safeIntervalStartTime_s,m.safeIntervalInterruptionCount,m.configuredRecoveryDelay_s,message};
 end
end
