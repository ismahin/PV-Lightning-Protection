function results = verify_simscape_settings_panel()
%VERIFY_SIMSCAPE_SETTINGS_PANEL Prove mask changes affect physical outputs.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(root));
modelName = 'PV_Lightning_Protection_Simscape';
modelPath = fullfile(root,'model',[modelName '.slx']);
load_system(modelPath);
blockPath = [modelName '/USER SETTINGS - DOUBLE CLICK'];
mask = Simulink.Mask.get(blockPath);
parameterNames = {mask.Parameters.Name};
originalValues = cellfun(@(name)get_param(blockPath,name), ...
    parameterNames,'UniformOutput',false);
cleanup = onCleanup(@()restoreModel(modelName,blockPath, ...
    parameterNames,originalValues));

assert(isempty(mask.Initialization), ...
    'The settings mask must not write to the workspace during compilation.');
assert(contains(mask.getParameter('InjectionMode').Callback, ...
    'apply_simscape_settings_mask'), ...
    'The settings Apply/OK callback is not connected.');

%% Changed current-mode inputs and supercapacitor limit
set_param(blockPath,'InjectionMode','Current injection', ...
    'PeakCurrent_A','6000','SCMaximumCurrent_A','10');
apply_simscape_settings_mask(blockPath);
set_param(modelName,'SimulationCommand','update');
currentOutput = runToEvent();
currentConfigured = peak(currentOutput,'Simscape_configured_lightning_current');
currentInjected = peak(currentOutput,'Simscape_injected_current');
currentInjectionVoltage = peak(currentOutput,'Simscape_injection_voltage');
currentSpd1 = peak(currentOutput,'Simscape_spd_current');
currentSc = absolutePeak(currentOutput,'Simscape_sc_current');

assert(abs(currentConfigured-6000) <= 0.01*6000, ...
    'The changed 6000 A mask value did not reach the source command.');
assert(abs(currentInjected-6000) <= 0.02*6000, ...
    'The measured physical injection did not follow the 6000 A mask value.');
assert(currentSc <= 10.01, ...
    'The changed 10 A supercapacitor limit was not enforced.');

%% Changed voltage-mode source
set_param(blockPath,'InjectionMode','Voltage injection', ...
    'PeakVoltage_V','1500','SCMaximumCurrent_A','18');
apply_simscape_settings_mask(blockPath);
set_param(modelName,'SimulationCommand','update');
voltageOutput = runToEvent();
voltageConfigured = peak(voltageOutput,'Simscape_configured_lightning_voltage');
voltageInjected = peak(voltageOutput,'Simscape_injected_current');
voltageInjectionVoltage = peak(voltageOutput,'Simscape_injection_voltage');
voltageSpd1 = peak(voltageOutput,'Simscape_spd_current');
voltageSc = absolutePeak(voltageOutput,'Simscape_sc_current');

assert(abs(voltageConfigured-1500) <= 0.01*1500, ...
    'The changed 1500 V mask value did not reach the source command.');
assert(voltageInjected > 10 && voltageInjected < 2000, ...
    'The voltage-mode Norton source produced an unexpected injected current.');
assert(abs(voltageInjected-currentInjected) > 1000, ...
    'Switching injection mode did not materially change the physical output.');
assert(abs(voltageInjectionVoltage-currentInjectionVoltage) > 10, ...
    'Changing the source mode did not change injection-node voltage.');

configuration = ["Changed current mode"; "Changed voltage mode"];
sourceCommandPeak = [currentConfigured; voltageConfigured];
measuredInjectedCurrent_A = [currentInjected; voltageInjected];
injectionNodePeak_V = [currentInjectionVoltage; voltageInjectionVoltage];
spd1DivertedPeak_A = [currentSpd1; voltageSpd1];
supercapacitorPeak_A = [currentSc; voltageSc];
results = table(configuration,sourceCommandPeak, ...
    measuredInjectedCurrent_A,injectionNodePeak_V,spd1DivertedPeak_A, ...
    supercapacitorPeak_A);
disp(results);

    function output = runToEvent()
        modelWorkspace = get_param(modelName,'ModelWorkspace');
        settings = modelWorkspace.getVariable('P');
        input = Simulink.SimulationInput(modelName);
        input = input.setModelParameter('StopTime', ...
            num2str(settings.lightning.eventTime_s+1e-3), ...
            'ReturnWorkspaceOutputs','on');
        output = sim(input);
    end

    function value = peak(output,name)
        data = output.get(name);
        value = max(data.Data);
    end

    function value = absolutePeak(output,name)
        data = output.get(name);
        value = max(abs(data.Data));
    end

end

function restoreModel(modelName,blockPath,parameterNames,originalValues)
if ~bdIsLoaded(modelName), return; end
for index = 1:numel(parameterNames)
    set_param(blockPath,parameterNames{index},originalValues{index});
end
apply_simscape_settings_mask(blockPath);
close_system(modelName,0);
end
