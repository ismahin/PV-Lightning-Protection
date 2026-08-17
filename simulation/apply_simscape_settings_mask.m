function P = apply_simscape_settings_mask(blockPath)
%APPLY_SIMSCAPE_SETTINGS_MASK Apply values from the model's settings mask.
% This function is called automatically when the user presses Apply/OK.

P = simscape_user_settings(project_parameters);
modeText = string(get_param(blockPath,'InjectionMode'));
P.lightning.mode = 1 + double(startsWith(lower(modeText),"voltage"));
P.lightning.peakCurrent_A = number('PeakCurrent_A');
P.lightning.peakVoltage_V = number('PeakVoltage_V');
P.lightning.eventTime_s = number('EventTime_s');
P.lightning.frontTime_s = number('FrontTime_us')*1e-6;
P.lightning.halfValueTime_s = number('HalfValueTime_us')*1e-6;
P.lightning.fastStep_s = number('WaveformStep_us')*1e-6;
P.lightning.localSolverStep_s = number('ElectricalStep_us')*1e-6;
P.lightning.voltageSourceResistance_Ohm = number('VoltageSourceResistance_Ohm');
P.lightning.sourceInductance_H = number('SourceInductance_uH')*1e-6;
P.cable.R_Ohm = number('CableResistance_Ohm');
P.cable.L_H = number('CableInductance_uH')*1e-6;

P.spd1.lowerVoltage_V = number('SPD1ClampVoltage_V');
P.spd1.dynamicResistance_Ohm = number('SPD1DynamicResistance_Ohm');
P.spd1.leakageResistance_Ohm = number('SPD1LeakageResistance_Ohm');
P.spd1.leadInductance_H = number('SPD1LeadInductance_uH')*1e-6;
P.spd1.groundResistance_Ohm = number('SPD1GroundResistance_Ohm');
P.spd1.groundInductance_H = number('SPD1GroundInductance_uH')*1e-6;
P.spd1.nominalCurrent_A = number('SPD1NominalCurrent_A');
P.spd1.maximumCurrent_A = number('SPD1MaximumCurrent_A');
P.spd1.energyRating_J = number('SPD1EnergyRating_J');

P.spd2.lowerVoltage_V = number('SPD2ClampVoltage_V');
P.spd2.dynamicResistance_Ohm = number('SPD2DynamicResistance_Ohm');
P.spd2.leakageResistance_Ohm = number('SPD2LeakageResistance_Ohm');
P.spd2.leadInductance_H = number('SPD2LeadInductance_uH')*1e-6;
P.spd2.groundResistance_Ohm = number('SPD2GroundResistance_Ohm');
P.spd2.groundInductance_H = number('SPD2GroundInductance_uH')*1e-6;
P.spd2.coordinationResistance_Ohm = number('SPD2CoordinationResistance_Ohm');
P.spd2.coordinationInductance_H = number('SPD2CoordinationInductance_uH')*1e-6;
P.spd2.nominalCurrent_A = number('SPD2NominalCurrent_A');
P.spd2.maximumCurrent_A = number('SPD2MaximumCurrent_A');
P.spd2.energyRating_J = number('SPD2EnergyRating_J');

P.sc.capacitance_F = number('SCCapacitance_F');
P.sc.initialVoltage_V = number('SCInitialVoltage_V');
P.sc.ratedVoltage_V = number('SCRatedVoltage_V');
P.sc.minimumVoltage_V = number('SCMinimumVoltage_V');
P.sc.maximumCurrent_A = number('SCMaximumCurrent_A');
P.sc.ESR_Ohm = number('SCESR_Ohm');
P.sc.converterInductance_H = number('SCConverterInductance_mH')*1e-3;
P.sc.converterPathResistance_Ohm = number('SCConverterResistance_Ohm');
P.sc.maximumEnergy_J = 0.5*P.sc.capacitance_F*P.sc.ratedVoltage_V^2;

P.threshold.warningVoltage_V = number('WarningVoltage_V');
P.threshold.emergencyTripVoltage_V = number('EmergencyTripVoltage_V');
P.threshold.safeRecoveryUpperVoltage_V = number('SafeRecoveryUpperVoltage_V');
P.threshold.safeRecoveryLowerVoltage_V = number('SafeRecoveryLowerVoltage_V');
P.threshold.warningDuration_s = number('WarningDuration_ms')*1e-3;
P.threshold.relayOpeningDelay_s = number('OpeningDelay_ms')*1e-3;
P.threshold.safeRecoveryDelay_s = number('RecoveryDelay_ms')*1e-3;
P.threshold.relayClosingDelay_s = number('ClosingDelay_ms')*1e-3;

validateSettings(P);
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

modelName = bdroot(blockPath);
modelWorkspace = get_param(modelName,'ModelWorkspace');
assignin(modelWorkspace,'P',P);
assignin(modelWorkspace,'lightning_profile', ...
    prepare_indirect_lightning_profile(P));
scenarios = test_scenarios(P);
scenario = scenarios(find(string({scenarios.Test_ID}) == "T05",1));
assignin(modelWorkspace,'scenario_input',configure_scenario(scenario,P));
assignin(modelWorkspace,'defaultScenario',scenario);
set_param(modelName,'StopTime',num2str(P.sim.stopTime));

    function value = number(parameterName)
        value = str2double(get_param(blockPath,parameterName));
        assert(isfinite(value),'%s must contain a finite numeric value.',parameterName);
    end
end

function validateSettings(P)
assert(ismember(P.lightning.mode,[1 2]),'Select Current or Voltage injection.');
assert(P.lightning.peakCurrent_A >= 0 && P.lightning.peakVoltage_V >= 0, ...
    'Lightning amplitudes must be nonnegative.');
assert(P.lightning.frontTime_s > 0 && ...
    P.lightning.halfValueTime_s > P.lightning.frontTime_s, ...
    'Half-value time must be greater than the positive front time.');
assert(P.lightning.fastStep_s > 0 && P.lightning.localSolverStep_s > 0, ...
    'Solver and waveform steps must be positive.');
assert(P.spd2.lowerVoltage_V < P.spd1.lowerVoltage_V, ...
    'SPD2 clamp voltage must be lower than SPD1 clamp voltage.');
assert(P.threshold.warningVoltage_V < P.threshold.emergencyTripVoltage_V, ...
    'Warning voltage must be lower than emergency trip voltage.');
assert(P.threshold.safeRecoveryLowerVoltage_V < ...
    P.threshold.safeRecoveryUpperVoltage_V, ...
    'Lower recovery voltage must be below upper recovery voltage.');
assert(P.sc.minimumVoltage_V < P.sc.initialVoltage_V && ...
    P.sc.initialVoltage_V < P.sc.ratedVoltage_V, ...
    'Supercapacitor voltages must satisfy minimum < initial < rated.');
end
