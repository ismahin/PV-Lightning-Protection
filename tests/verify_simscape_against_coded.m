function comparison = verify_simscape_against_coded
%VERIFY_SIMSCAPE_AGAINST_CODED Confirm pre-surge operation remains aligned.
% The 10 kA 8/20 us physical test has no equivalent in the original coded
% T05 model, so surge coordination is verified separately.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
codedP = project_parameters;
physicalP = simscape_user_settings(codedP);
scenarios = test_scenarios(codedP);
scenario = scenarios(find(string({scenarios.Test_ID}) == "T05",1));

coded = run_single_scenario(scenario,codedP, ...
    fullfile(root,'model','PV_Lightning_Protection.slx'));
physical = runPhysicalModel(root,physicalP,scenario);

preStart = scenario.Event_Start-0.03;
codedTime = coded.signals.time(:);
codedPre = codedTime >= preStart & codedTime < scenario.Event_Start;
busVoltage = physical.get('Simscape_bus_voltage');
physicalPre = busVoltage.Time >= preStart & ...
    busVoltage.Time < scenario.Event_Start;
acVoltage = physical.get('Simscape_ac_voltage');
acCurrent = physical.get('Simscape_ac_current');
acPre = acVoltage.Time >= preStart & acVoltage.Time < scenario.Event_Start;
pvVoltage = physical.get('Simscape_pv_voltage');
pvCurrent = physical.get('Simscape_pv_current');
scVoltage = physical.get('Simscape_sc_voltage');

metric = ["PV voltage before event (V)"; "PV current before event (A)"; ...
    "PV power before event (W)"; "DC bus before event (V)"; ...
    "Supercapacitor voltage before event (V)"; "Load power before event (W)"];
codedValue = [mean(coded.signals.pv_voltage.Data(codedPre)); ...
    mean(coded.signals.pv_current.Data(codedPre)); ...
    mean(coded.signals.pv_power.Data(codedPre)); ...
    mean(coded.signals.dc_bus_voltage.Data(codedPre)); ...
    mean(coded.signals.sc_voltage.Data(codedPre)); ...
    mean(coded.signals.downstream_power.Data(codedPre))];
physicalValue = [mean(pvVoltage.Data(physicalPre)); ...
    mean(pvCurrent.Data(physicalPre)); ...
    mean(pvVoltage.Data(physicalPre).*pvCurrent.Data(physicalPre)); ...
    mean(busVoltage.Data(physicalPre)); mean(scVoltage.Data(physicalPre)); ...
    mean(acVoltage.Data(acPre).*acCurrent.Data(acPre))];
tolerancePercent = [8; 10; 8; 8; 3; 8];
errorPercent = 100*(physicalValue-codedValue)./max(abs(codedValue),eps);
status = repmat("PASS",size(metric));
status(abs(errorPercent) > tolerancePercent) = "FAIL";
comparison = table(metric,codedValue,physicalValue,errorPercent, ...
    tolerancePercent,status);
disp(comparison);
assert(all(status == "PASS"), ...
    'Simscape pre-surge regression exceeded one or more tolerances.');
end

function output = runPhysicalModel(root,P,scenario)
scenarioInput = configure_scenario(scenario,P);
lightningProfile = prepare_indirect_lightning_profile(P);
modelName = 'PV_Lightning_Protection_Simscape';
load_system(fullfile(root,'model',[modelName '.slx']));
modelWorkspace = get_param(modelName,'ModelWorkspace');
assignin(modelWorkspace,'P',P);
assignin(modelWorkspace,'scenario_input',scenarioInput);
assignin(modelWorkspace,'lightning_profile',lightningProfile);
input = Simulink.SimulationInput(modelName);
input = input.setModelParameter('StopTime',num2str(scenario.StopTime), ...
    'ReturnWorkspaceOutputs','on');
output = sim(input);
close_system(modelName,0);
end
