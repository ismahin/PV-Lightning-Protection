function [metrics,assertions] = run_inverter_tests(P,root)
%RUN_INVERTER_TESTS Execute and validate the switching inverter demo.
modelPath=build_microinverter_switching_demo(P); [~,name]=fileparts(modelPath); load_system(modelPath); out=sim(name); close_system(name,0);
fields={'bridge_voltage','inverter_output_voltage','inverter_output_current','inverter_inductor_current','inverter_ac_power','inverter_dc_power','inverter_relay_state'}; s=struct;
for k=1:numel(fields), ts=out.get(fields{k}); s.(fields{k})=struct('Time',ts.Time(:),'Data',ts.Data(:)); end
t=s.inverter_output_voltage.Time; v=s.inverter_output_voltage.Data; i=s.inverter_output_current.Data; pdc=s.inverter_dc_power.Data; pac=s.inverter_ac_power.Data;
window=t>=0.04 & t<0.075; metrics.RMS_V=sqrt(mean(v(window).^2));
cross=t(find(diff(v>0)==1)+1); cross=cross(cross>=0.02 & cross<0.08); metrics.Frequency_Hz=1/mean(diff(cross));
metrics.OutputCurrentRMS_A=sqrt(mean(i(window).^2)); metrics.DCInputPower_W=mean(pdc(window)); metrics.ACOutputPower_W=mean(pac(window)); metrics.PowerBalanceError_percent=100*abs(metrics.DCInputPower_W-metrics.ACOutputPower_W)/max(abs(metrics.DCInputPower_W),eps);
after=t>0.095; metrics.PostShutdownRMS_V=sqrt(mean(v(after).^2)); metrics.ShutdownTime_s=0.08;
metrics.modelPath=string(modelPath); metrics.signals=s;
id=["INV-A01";"INV-A02";"INV-A03";"INV-A04";"INV-A05"];
metric=["Output RMS voltage";"Output frequency";"Power balance error";"Relay shutdown";"AC output power"];
actual=[metrics.RMS_V;metrics.Frequency_Hz;metrics.PowerBalanceError_percent;metrics.PostShutdownRMS_V;metrics.ACOutputPower_W];
tolerance=[2.4;1;10;2;1]; pass=[abs(metrics.RMS_V-P.inverter.demoRMSVoltage_V)<=2.4;abs(metrics.Frequency_Hz-P.inverter.demoFrequency_Hz)<=1;metrics.PowerBalanceError_percent<=10;metrics.PostShutdownRMS_V<=2;metrics.ACOutputPower_W>1];
status=repmat("PASS",5,1); status(~pass)="FAIL";
assertions=table(id,repmat("T14",5,1),repmat("PR-12",5,1),metric,["24 V RMS +/-10%";"50 Hz +/-1 Hz";"<=10%";"post-shutdown RMS <=2 V";">1 W"],string(actual),string(tolerance),status,repmat("ERROR",5,1),repmat("Switching inverter numerical validation",5,1), ...
 'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
save(fullfile(root,'results','raw','Microinverter_Switching_Demo.mat'),'metrics');
end
