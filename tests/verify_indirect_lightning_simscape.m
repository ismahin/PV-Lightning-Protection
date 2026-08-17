function results = verify_indirect_lightning_simscape
%VERIFY_INDIRECT_LIGHTNING_SIMSCAPE Verify the configurable 8/20 us path.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
P = simscape_user_settings(project_parameters);
P.lightning.mode = 1;
profile = prepare_indirect_lightning_profile(P);
modelName = 'PV_Lightning_Protection_Simscape';
load_system(fullfile(root,'model',[modelName '.slx']));
modelWorkspace = get_param(modelName,'ModelWorkspace');
assignin(modelWorkspace,'P',P);
assignin(modelWorkspace,'lightning_profile',profile);
input = Simulink.SimulationInput(modelName);
input = input.setModelParameter('StopTime', ...
    num2str(P.lightning.eventTime_s+1e-3),'ReturnWorkspaceOutputs','on');
output = sim(input);

configured = output.get('Simscape_configured_lightning_current');
injected = output.get('Simscape_injected_current');
spd1 = output.get('Simscape_spd_current');
afterSpd1 = output.get('Simscape_surge_current');
spd2 = output.get('Simscape_spd2_current');
afterSpd2 = output.get('Simscape_spd2_residual_current');
bus = output.get('Simscape_bus_voltage');
scCurrent = output.get('Simscape_sc_current');

[configuredPeak,peakIndex] = max(configured.Data);
peakTime = configured.Time(peakIndex)-P.lightning.eventTime_s;
[~,halfIndex] = min(abs(configured.Time- ...
    (P.lightning.eventTime_s+P.lightning.halfValueTime_s)));
halfRatio = configured.Data(halfIndex)/configuredPeak;

metric = ["Configured current peak (A)"; "Measured injected peak (A)"; ...
    "Waveform front time (us)"; "Value at 20 us (pu)"; ...
    "SPD1 diverted fraction (pu)"; "SPD2 peak current (A)"; ...
    "Residual reduction across SPD2 (pu)"; "Protected bus peak (V)"; ...
    "Supercapacitor peak current (A)"];
actual = [configuredPeak; max(injected.Data); peakTime*1e6; halfRatio; ...
    max(spd1.Data)/max(injected.Data); max(spd2.Data); ...
    max(afterSpd2.Data)/max(afterSpd1.Data); max(bus.Data); ...
    max(abs(scCurrent.Data))];
limit = [P.lightning.peakCurrent_A; P.lightning.peakCurrent_A; 8; 0.5; ...
    0.90; 1; 1; P.threshold.emergencyTripVoltage_V; P.sc.maximumCurrent_A];
rule = ["within 1%"; "within 2%"; "within 0.5 us"; "within 0.03"; ...
    ">="; ">="; "<"; "<="; "<="];
pass = [abs(actual(1)-limit(1)) <= 0.01*limit(1); ...
    abs(actual(2)-limit(2)) <= 0.02*limit(2); ...
    abs(actual(3)-limit(3)) <= 0.5; abs(actual(4)-limit(4)) <= 0.03; ...
    actual(5) >= limit(5); actual(6) >= limit(6); actual(7) < limit(7); ...
    actual(8) <= limit(8); actual(9) <= limit(9)];
status = repmat("PASS",size(metric));
status(~pass) = "FAIL";
results = table(metric,actual,rule,limit,status);
disp(results);
close_system(modelName,0);
assert(all(pass),'Indirect-lightning Simscape verification failed.');
end
