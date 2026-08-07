function E = calculate_energy_metrics(s,P,scenario)
%CALCULATE_ENERGY_METRICS Total, baseline and event-window energy metrics.
t=s.time; event=t>=scenario.Event_Start & t<=scenario.Event_End;
pre=t>=scenario.Startup_Exclusion_Time & t<scenario.Event_Start;
spdPower=abs(s.spd_voltage.Data.*s.spd_current.Data);
scPower=s.sc_terminal_voltage.Data.*s.sc_actual_current.Data;
esrPower=s.sc_esr_power.Data;
E.spdTotal_J=trapz(t,spdPower); E.spdEvent_J=integrateWindow(t,spdPower,event);
E.spdCumulative_J=s.spd_cumulative_energy.Data(end); E.spdUtilization_percent=100*E.spdCumulative_J/P.spd.energyRating_J;
E.scAbsorbedTotal_J=trapz(t,max(scPower,0)); E.scReleasedTotal_J=trapz(t,max(-scPower,0));
E.scAbsorbedEvent_J=integrateWindow(t,max(scPower,0),event); E.scReleasedEvent_J=integrateWindow(t,max(-scPower,0),event);
E.scBaselineAbsorbed_J=integrateWindow(t,max(scPower,0),pre); E.scBaselineReleased_J=integrateWindow(t,max(-scPower,0),pre);
if nnz(pre)>1
 baselinePower=mean(scPower(pre));
else
 baselinePower=0;
end
E.scIncrementalEvent_J=trapz(t(event),scPower(event)-baselinePower);
E.scESRLossTotal_J=trapz(t,esrPower); E.scESRLossEvent_J=integrateWindow(t,esrPower,event);
E.scStoredDelta_J=0.5*P.sc.capacitance_F*(s.sc_internal_voltage.Data(end)^2-s.sc_internal_voltage.Data(1)^2);
E.loadTotal_J=trapz(t,max(s.downstream_power.Data,0)); E.loadEvent_J=integrateWindow(t,max(s.downstream_power.Data,0),event);
E.pvTotal_J=trapz(t,max(s.pv_power.Data,0));
end
function value=integrateWindow(t,y,mask)
if nnz(mask)>1, value=trapz(t(mask),y(mask)); else, value=0; end
end
