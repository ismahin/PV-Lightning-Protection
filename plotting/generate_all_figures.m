function generated = generate_all_figures(results,pairs,convergence,P,root,inverterMetrics,pvValidation,repeatability)
%GENERATE_ALL_FIGURES Regenerate the definitive final figure set.
out=fullfile(root,'results','figures'); generated=strings(0,1); curves=generate_pv_curves(P);
f=figure('Visible','off','Color','w'); hold on; for k=1:numel(curves), plot(curves(k).voltage_V,curves(k).current_A,'LineWidth',1.2); end; grid on; xlabel('PV voltage (V)'); ylabel('PV current (A)'); legend(conditionLabels(curves),'Location','best'); title('Unified single-diode PV I-V curves'); finish(f,'PV_IV_Curves');
f=figure('Visible','off','Color','w'); hold on; for k=1:numel(curves), plot(curves(k).voltage_V,curves(k).power_W,'LineWidth',1.2); end; grid on; xlabel('PV voltage (V)'); ylabel('PV power (W)'); legend(conditionLabels(curves),'Location','best'); title('Unified single-diode PV P-V curves'); finish(f,'PV_PV_Curves');
barplot('PV_Parameter_Validation',pvValidation.Metric,pvValidation.Error_Percent,'Model error (%)');
plotScenario('Nominal_MPPT_Operation',results{1},{'pv_power','theoretical_mpp_power','mppt_duty'});
plotScenario('Irradiance_Step_MPPT_Response',results{2},{'irradiance','pv_power','theoretical_mpp_power','mppt_duty'});
plotScenario('Laboratory_Surge_Waveform',results{5},{'surge_injected'});
plotScenario('SPD_Demanded_Versus_Actual_Current',results{5},{'spd_demanded_current','spd_current','spd_saturation_flag'});
plotScenario('SPD_Current_And_Energy_Utilization',results{5},{'spd_demanded_current','spd_current','spd_cumulative_energy'});
plotScenario('Intentional_SPD_Overstress_Response',results{16},{'surge_injected','dc_bus_voltage','spd_demanded_current','spd_current','spd_overstress_state'});
plotScenario('SC_Internal_Versus_Terminal_Voltage',results{12},{'sc_internal_voltage','sc_terminal_voltage','sc_esr_voltage'});
plotScenario('SC_Current_Command_Versus_Actual',results{12},{'sc_current_command_raw','sc_current_command','sc_actual_current'});
plotScenario('SC_Enable_And_Current_Limit',results{12},{'sc_converter_enabled','sc_current_limit_flag','sc_current_limit_duration'});
plotScenario('SC_ESR_Power_And_Cumulative_Loss',results{12},{'sc_esr_power','sc_esr_energy'});
plotScenario('Controller_State_Timeline',results{7},{'controller_state','warning_flag','emergency_flag','protection_armed'});
plotScenario('Relay_Detection_Command_And_Physical_State',results{7},{'dc_bus_voltage','relay_command','relay_state','downstream_current'});
plotScenario('Automatic_Recovery_Timing',results{9},{'dc_bus_voltage','controller_state','relay_command','relay_state','downstream_current'});
plotScenario('Manual_Reset_Timing',results{10},{'dc_bus_voltage','manual_reset','relay_command','relay_state'});
plotScenario('Averaged_Microinverter_Performance',results{14},{'dc_bus_voltage','inverter_requested_power','inverter_dc_input_power','downstream_power'});
events=["T04","T05","T06","T07"];
labels=["Moderate_Transient","Severe_Design_Transient","Repeated_Surge","Sustained_Overvoltage"];
for e=1:numel(events)
 q=pairs(pairs.Event_ID==events(e),:); barplot('Fair_Paired_'+labels(e),q.Mode_Name,q.Peak_DC_Bus_V,'Peak DC-bus voltage (V)');
end
q=pairs(pairs.Event_ID=="T05",:); barplot('Relative_Event_Load_Energy_Comparison',q.Mode_Name,q.Relative_Event_Load_Energy_Percent,'Relative event load energy (%)');
barplot('Load_Energy_Improvement_Comparison',q.Mode_Name,q.Load_Energy_Improvement_Percent,'Load-energy improvement (%)');
peakRow=convergence(convergence.Metric=="Peak DC-bus voltage",:); barplot('Solver_Convergence_Comparison',["Production","Half step"],[peakRow.Production_Value,peakRow.Half_Step_Value],'Peak DC-bus voltage (V)');
f=figure('Visible','off','Color','w'); bar(categorical(convergence.Metric),convergence.Relative_Difference_Percent); grid on; ylabel('Relative difference (%)'); yline(P.validation.solverTolerance_percent,'r--','3% limit'); title('Solver convergence by important metric'); finish(f,'Solver_Convergence_All_Metrics');
s=inverterMetrics.signals;
f=figure('Visible','off','Color','w'); tiledlayout(3,1); nexttile; plot(s.inverter_output_voltage.Time,s.inverter_output_voltage.Data); grid on; ylabel('Output V'); nexttile; plot(s.inverter_output_current.Time,s.inverter_output_current.Data); grid on; ylabel('Output A'); nexttile; plot(s.inverter_relay_state.Time,s.inverter_relay_state.Data); grid on; ylabel('Relay'); xlabel('Time (s)'); finish(f,'Switching_Inverter_Output_Voltage_And_Current');
f=figure('Visible','off','Color','w'); tiledlayout(2,1); nexttile; plot(s.inverter_dc_power.Time,s.inverter_dc_power.Data,s.inverter_ac_power.Time,s.inverter_ac_power.Data,'LineWidth',1); grid on; ylabel('Power (W)'); legend('DC input','AC output'); nexttile; plot(s.inverter_relay_state.Time,s.inverter_relay_state.Data,'LineWidth',1.2); grid on; ylabel('Relay'); xlabel('Time (s)'); finish(f,'Switching_Inverter_Shutdown_Response');
f=figure('Visible','off','Color','w'); bar(repeatability.Absolute_Difference); grid on; ylabel('Absolute difference'); xlabel('Repeated key metric index'); title('Repeated final-run key-metric differences'); finish(f,'Repeatability_Comparison');
 function plotScenario(name,r,fields)
  f=figure('Visible','off','Color','w'); tiledlayout(numel(fields),1);
  for z=1:numel(fields), nexttile; x=r.signals.(fields{z}); plot(x.Time,x.Data,'LineWidth',1.05); grid on; xlabel('Time (s)'); ylabel(strrep(fields{z},'_',' '),'Interpreter','none'); end
  finish(f,name);
 end
 function barplot(name,cats,vals,ylab)
  f=figure('Visible','off','Color','w'); bar(categorical(cats),vals); grid on; ylabel(ylab); title(strrep(char(name),'_',' ')); finish(f,char(name));
 end
 function finish(f,name)
  drawnow; base=fullfile(out,char(name)); savefig(f,[base '.fig']); exportgraphics(f,[base '.png'],'Resolution',180); exportgraphics(f,[base '.pdf'],'ContentType','vector'); close(f); generated(end+1)=string([base '.png']);
 end
end
function labels=conditionLabels(curves), labels=arrayfun(@(c)sprintf('%g W/m^2, %g C',c.irradiance_W_m2,c.temperature_C),curves,'UniformOutput',false); end
