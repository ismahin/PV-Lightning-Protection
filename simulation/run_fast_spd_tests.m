function [T,assertions] = run_fast_spd_tests(P,root)
%RUN_FAST_SPD_TESTS Shared-MOV standards-inspired numerical tests.
out=fullfile(root,'results','figures'); dt=2e-8; fineDt=dt/2;
vTest=voltageTest(dt,P); vFine=voltageTest(fineDt,P);
iTest=currentTest(dt,P); iFine=currentTest(fineDt,P);
vSensitivity=100*abs(vTest.energy_J-vFine.energy_J)/max(vFine.energy_J,eps);
iSensitivity=100*abs(iTest.energy_J-iFine.energy_J)/max(iFine.energy_J,eps);
qualification=repmat("Standards-inspired numerical component tests; not certified compliance tests",2,1);
T=table(["1.2/50 us voltage";"8/20 us current"],[1.2e-6;8e-6],[vTest.frontTime_s;iTest.frontTime_s], ...
 100*([vTest.frontTime_s;iTest.frontTime_s]-[1.2e-6;8e-6])./[1.2e-6;8e-6], ...
 [50e-6;20e-6],[vTest.halfValueTime_s;iTest.halfValueTime_s], ...
 100*([vTest.halfValueTime_s;iTest.halfValueTime_s]-[50e-6;20e-6])./[50e-6;20e-6], ...
 [vTest.sourcePeak_V;NaN],[NaN;iTest.sourcePeak_A],[vTest.demandedPeak_A;iTest.demandedPeak_A], ...
 [vTest.actualPeak_A;iTest.actualPeak_A],[vTest.clampingPeak_V;iTest.clampingPeak_V], ...
 [vTest.energy_J;iTest.energy_J],[vTest.capabilityStatus;iTest.capabilityStatus],[vSensitivity;iSensitivity],qualification, ...
 'VariableNames',{'Test','Requested_Front_Time_s','Measured_Front_Time_s','Front_Time_Error_Percent', ...
 'Requested_Half_Value_Time_s','Measured_Half_Value_Time_s','Half_Value_Error_Percent', ...
 'Peak_Source_Voltage_V','Peak_Source_Current_A','Peak_MOV_Demanded_Current_A','Peak_Actual_Current_A', ...
 'Clamping_Voltage_V','Event_Energy_J','Capability_Status','Time_Step_Sensitivity_Percent','Qualification'});
saveWave(vTest,'Fast_SPD_1p2_50us','1.2/50 us voltage impulse');
saveWave(iTest,'Fast_SPD_8_20us','8/20 us current impulse');
id=["FSPD-A01";"FSPD-A02";"FSPD-A03";"FSPD-A04";"FSPD-A05";"FSPD-A06"];
metric=["Voltage front time";"Voltage half-value time";"Current front time";"Current half-value time";"Voltage-step sensitivity";"Current-step sensitivity"];
actual=[abs(T.Front_Time_Error_Percent(1));abs(T.Half_Value_Error_Percent(1));abs(T.Front_Time_Error_Percent(2));abs(T.Half_Value_Error_Percent(2));vSensitivity;iSensitivity];
tolerance=[repmat(P.validation.fastWaveformTolerance_percent,4,1);0.5;0.5];
status=repmat("PASS",6,1); status(actual>tolerance)="FAIL";
assertions=table(id,repmat("FAST-SPD",6,1),repmat("PR-03",6,1),metric,repmat("absolute percentage error <= tolerance",6,1),string(actual),string(tolerance),status,repmat("ERROR",6,1),repmat("Shared MOV numerical component verification; not certification",6,1), ...
 'VariableNames',{'Assertion_ID','Test_ID','Requirement_ID','Metric','Expected_Condition','Actual_Value','Tolerance','Status','Severity','Message'});
 function saveWave(w,name,titleText)
  f=figure('Visible','off','Color','w'); tiledlayout(2,1);
  nexttile; plot(w.time_s*1e6,w.source,'LineWidth',1.3); grid on; ylabel('Applied source'); title({titleText;'Standards-inspired numerical component test; not certified compliance test'});
  nexttile; plot(w.time_s*1e6,w.demandedCurrent_A,'--',w.time_s*1e6,w.actualCurrent_A,'LineWidth',1.2); grid on; xlabel('Time (us)'); ylabel('MOV current (A)'); legend('Demanded','Actual','Location','best');
  exportgraphics(f,fullfile(out,[name '.png']),'Resolution',180); savefig(f,fullfile(out,[name '.fig'])); exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector'); close(f);
 end
end

function w=voltageTest(dt,P)
t=(0:dt:120e-6)'; source=piecewiseImpulse(t,1.2e-6,50e-6,1000); n=numel(t);
demand=zeros(n,1); actual=zeros(n,1); clamp=zeros(n,1); energy=zeros(n,1);
for k=2:n
 available=source(k)/P.fastSPD.voltageSourceResistance_Ohm;
 lo=0; hi=available;
 for j=1:32
  mid=(lo+hi)/2; node=max(0,source(k)-P.fastSPD.voltageSourceResistance_Ohm*mid);
  if mov_demanded_current(node,P)>mid, lo=mid; else, hi=mid; end
 end
 demand(k)=(lo+hi)/2; [actual(k),~]=mov_actual_current(demand(k),actual(k-1),P,dt);
 clamp(k)=max(0,source(k)-P.fastSPD.voltageSourceResistance_Ohm*actual(k));
 energy(k)=mov_energy_update(energy(k-1),clamp(k),actual(k),dt);
end
w=pack(t,source,demand,actual,clamp,energy,P); w.sourcePeak_V=max(source); w.sourcePeak_A=NaN;
end

function w=currentTest(dt,P)
t=(0:dt:80e-6)'; source=piecewiseImpulse(t,8e-6,20e-6,300); n=numel(t);
demand=source; actual=zeros(n,1); clamp=zeros(n,1); energy=zeros(n,1);
for k=2:n
 [actual(k),~]=mov_actual_current(demand(k),actual(k-1),P,dt);
 clamp(k)=mov_voltage_for_current(max(actual(k),P.spd.leakage_A),P);
 energy(k)=mov_energy_update(energy(k-1),clamp(k),actual(k),dt);
end
w=pack(t,source,demand,actual,clamp,energy,P); w.sourcePeak_A=max(source); w.sourcePeak_V=NaN;
end

function y=piecewiseImpulse(t,frontTime,halfValueTime,peak)
y=zeros(size(t)); rising=t<=frontTime; y(rising)=peak*(t(rising)/frontTime);
falling=~rising; y(falling)=peak*2.^(-(t(falling)-frontTime)/(halfValueTime-frontTime));
end

function w=pack(t,source,demand,actual,clamp,energy,P)
w=struct('time_s',t,'source',source,'demandedCurrent_A',demand,'actualCurrent_A',actual,'clampingVoltage_V',clamp);
[~,peakIndex]=max(source); w.frontTime_s=t(peakIndex); q=find(source(peakIndex:end)<=0.5*max(source),1)+peakIndex-1; w.halfValueTime_s=t(q);
w.demandedPeak_A=max(demand); w.actualPeak_A=max(actual); w.clampingPeak_V=max(clamp); w.energy_J=energy(end);
[state,~,~]=mov_capability_state(w.demandedPeak_A,w.energy_J,P); if state==0, w.capabilityStatus="SAFE"; elseif state==3, w.capabilityStatus="FAILED"; else, w.capabilityStatus="OVERSTRESSED"; end
end
