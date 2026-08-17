function P = configure_simscape_run(options)
%CONFIGURE_SIMSCAPE_RUN Override physical-model settings for the next run.
% Examples:
%   configure_simscape_run(InjectionMode="current",PeakCurrent_A=15000)
%   configure_simscape_run(InjectionMode="voltage",PeakVoltage_V=1500)
%   configure_simscape_run(EmergencyTripVoltage_V=72,OpeningDelay_s=0.010)

arguments
    options.InjectionMode (1,1) string {mustBeMember(options.InjectionMode,["current","voltage"])} = "current"
    options.PeakCurrent_A (1,1) double {mustBeNonnegative} = 10000
    options.PeakVoltage_V (1,1) double {mustBeNonnegative} = 1200
    options.EventTime_s (1,1) double {mustBeNonnegative} = 0.60
    options.WarningVoltage_V (1,1) double {mustBePositive} = 52.8
    options.EmergencyTripVoltage_V (1,1) double {mustBePositive} = 69.6
    options.SafeRecoveryUpperVoltage_V (1,1) double {mustBePositive} = 51.36
    options.SafeRecoveryLowerVoltage_V (1,1) double {mustBeNonnegative} = 40.8
    options.WarningDuration_s (1,1) double {mustBeNonnegative} = 45e-3
    options.OpeningDelay_s (1,1) double {mustBeNonnegative} = 8e-3
    options.RecoveryDelay_s (1,1) double {mustBeNonnegative} = 350e-3
    options.ClosingDelay_s (1,1) double {mustBeNonnegative} = 12e-3
end

root = fileparts(fileparts(mfilename('fullpath')));
P = simscape_user_settings(project_parameters);
P.lightning.mode = 1 + double(options.InjectionMode == "voltage");
P.lightning.peakCurrent_A = options.PeakCurrent_A;
P.lightning.peakVoltage_V = options.PeakVoltage_V;
P.lightning.eventTime_s = options.EventTime_s;
P.threshold.warningVoltage_V = options.WarningVoltage_V;
P.threshold.emergencyTripVoltage_V = options.EmergencyTripVoltage_V;
P.threshold.safeRecoveryUpperVoltage_V = options.SafeRecoveryUpperVoltage_V;
P.threshold.safeRecoveryLowerVoltage_V = options.SafeRecoveryLowerVoltage_V;
P.threshold.warningDuration_s = options.WarningDuration_s;
P.threshold.relayOpeningDelay_s = options.OpeningDelay_s;
P.threshold.safeRecoveryDelay_s = options.RecoveryDelay_s;
P.threshold.relayClosingDelay_s = options.ClosingDelay_s;

assert(P.threshold.warningVoltage_V < P.threshold.emergencyTripVoltage_V, ...
    'WarningVoltage_V must be lower than EmergencyTripVoltage_V.');
assert(P.threshold.safeRecoveryLowerVoltage_V < ...
    P.threshold.safeRecoveryUpperVoltage_V, ...
    'The lower recovery threshold must be below the upper threshold.');

P.controller.warning_pu = P.threshold.warningVoltage_V/P.bus.nominalVoltage_V;
P.controller.emergency_pu = P.threshold.emergencyTripVoltage_V/P.bus.nominalVoltage_V;
P.controller.safeRecovery_pu = ...
    P.threshold.safeRecoveryUpperVoltage_V/P.bus.nominalVoltage_V;
P.controller.lowSafe_pu = ...
    P.threshold.safeRecoveryLowerVoltage_V/P.bus.nominalVoltage_V;
P.controller.allowedDuration_s = P.threshold.warningDuration_s;
P.controller.recoveryDelay_s = P.threshold.safeRecoveryDelay_s;
P.relay.openingDelay_s = P.threshold.relayOpeningDelay_s;
P.relay.closingDelay_s = P.threshold.relayClosingDelay_s;

modelName = 'PV_Lightning_Protection_Simscape';
modelPath = fullfile(root,'model',[modelName '.slx']);
load_system(modelPath);
modelWorkspace = get_param(modelName,'ModelWorkspace');
assignin(modelWorkspace,'P',P);
assignin(modelWorkspace,'lightning_profile', ...
    prepare_indirect_lightning_profile(P));
scenarios = test_scenarios(P);
scenario = scenarios(find(string({scenarios.Test_ID}) == "T05",1));
assignin(modelWorkspace,'scenario_input',configure_scenario(scenario,P));
set_param(modelName,'StopTime',num2str(P.sim.stopTime));
set_param(modelName,'SimulationCommand','update');
fprintf(['Configured %s injection: %.3f A current setting, %.3f V voltage ' ...
    'setting, emergency threshold %.3f V. Press Run.\n'], ...
    options.InjectionMode,P.lightning.peakCurrent_A, ...
    P.lightning.peakVoltage_V,P.threshold.emergencyTripVoltage_V);
end
