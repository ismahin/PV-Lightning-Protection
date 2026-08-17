function P = simscape_user_settings(P)
%SIMSCAPE_USER_SETTINGS Defaults used when regenerating the Simscape model.
% Normal users change these values in the model's USER SETTINGS block.

%% Lightning input selection
% 1 = 8/20 us line-to-ground CURRENT injection.
% 2 = 8/20 us line-to-ground VOLTAGE injection (Norton equivalent).
P.lightning.mode = 1;
P.lightning.peakCurrent_A = 10000;
P.lightning.peakVoltage_V = 1200;
P.lightning.eventTime_s = 0.60;
P.lightning.frontTime_s = 8e-6;
P.lightning.halfValueTime_s = 20e-6;
P.lightning.fastStep_s = 0.25e-6;
P.lightning.localSolverStep_s = 4.0e-6;
P.lightning.recordDuration_s = 160e-6;
P.lightning.voltageSourceResistance_Ohm = 3.0;
P.lightning.currentSourceParallelResistance_Ohm = 1e9;
P.lightning.sourceInductance_H = 0.10e-6;

%% Coordinated Type-2 MOV assumptions
% SPD1 is the upstream/cable-entry device. SPD2 is inverter-side and has
% a lower protective level. Replace these assumptions with supplied
% commercial datasheet values when a specific device is selected.
P.spd1.lowerVoltage_V = 62;
P.spd1.upperVoltage_V = 72;
P.spd1.leakageResistance_Ohm = 3e6;
P.spd1.dynamicResistance_Ohm = 3e-3;
P.spd1.normalExponent = 25;
P.spd1.upturnResistance_Ohm = 3e-3;
P.spd1.seriesResistance_Ohm = 50e-6;
P.spd1.capacitance_F = 4.4e-9;
P.spd1.leadInductance_H = 0.10e-6;
P.spd1.groundResistance_Ohm = 3e-3;
P.spd1.groundInductance_H = 0.10e-6;
P.spd1.nominalCurrent_A = 10000;
P.spd1.maximumCurrent_A = 20000;
P.spd1.energyRating_J = 2000;

P.spd2.lowerVoltage_V = 55;
P.spd2.upperVoltage_V = 65;
P.spd2.leakageResistance_Ohm = 3e6;
P.spd2.dynamicResistance_Ohm = 2e-3;
P.spd2.normalExponent = 25;
P.spd2.upturnResistance_Ohm = 2e-3;
P.spd2.seriesResistance_Ohm = 50e-6;
P.spd2.capacitance_F = 4.4e-9;
P.spd2.leadInductance_H = 0.10e-6;
P.spd2.groundResistance_Ohm = 2e-3;
P.spd2.groundInductance_H = 0.10e-6;
P.spd2.coordinationResistance_Ohm = 0.05;
P.spd2.coordinationInductance_H = 2.0e-6;
P.spd2.nominalCurrent_A = 5000;
P.spd2.maximumCurrent_A = 10000;
P.spd2.energyRating_J = 1000;

%% Supercapacitor settings
P.sc.capacitance_F = 15;
P.sc.initialVoltage_V = 30;
P.sc.ratedVoltage_V = 38;
P.sc.minimumVoltage_V = 20;
P.sc.maximumCurrent_A = 18;
P.sc.maximumEnergy_J = 0.5*P.sc.capacitance_F*P.sc.ratedVoltage_V^2;

%% Editable relay/protection thresholds and operating times
P.threshold.warningVoltage_V = 52.8;
P.threshold.emergencyTripVoltage_V = 69.6;
P.threshold.safeRecoveryUpperVoltage_V = 51.36;
P.threshold.safeRecoveryLowerVoltage_V = 40.8;
P.threshold.warningDuration_s = 45e-3;
P.threshold.safeRecoveryDelay_s = 350e-3;
P.threshold.relayOpeningDelay_s = 8e-3;
P.threshold.relayClosingDelay_s = 12e-3;

P.controller.warning_pu = P.threshold.warningVoltage_V/P.bus.nominalVoltage_V;
P.controller.emergency_pu = P.threshold.emergencyTripVoltage_V/P.bus.nominalVoltage_V;
P.controller.safeRecovery_pu = P.threshold.safeRecoveryUpperVoltage_V/P.bus.nominalVoltage_V;
P.controller.lowSafe_pu = P.threshold.safeRecoveryLowerVoltage_V/P.bus.nominalVoltage_V;
P.controller.allowedDuration_s = P.threshold.warningDuration_s;
P.controller.recoveryDelay_s = P.threshold.safeRecoveryDelay_s;
P.relay.openingDelay_s = P.threshold.relayOpeningDelay_s;
P.relay.closingDelay_s = P.threshold.relayClosingDelay_s;

validateattributes(P.lightning.mode,{'numeric'},{'scalar','integer','>=',1,'<=',2});
validateattributes(P.lightning.peakCurrent_A,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(P.lightning.peakVoltage_V,{'numeric'},{'scalar','nonnegative','finite'});
assert(P.lightning.halfValueTime_s > P.lightning.frontTime_s, ...
    'The half-value time must be greater than the front time.');
assert(P.spd2.upperVoltage_V < P.spd1.upperVoltage_V, ...
    'SPD2 must have a lower protective voltage than SPD1.');
end
