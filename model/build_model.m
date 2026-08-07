function modelPath = build_model(P)
%BUILD_MODEL Build the canonical visibly modular executable Simulink model.
root=fileparts(fileparts(mfilename('fullpath'))); name=char(P.project.modelName);
modelPath=fullfile(root,'model',[name '.slx']);
if bdIsLoaded(name), close_system(name,0); end
if isfile(modelPath), delete(modelPath); end
new_system(name); open_system(name);
modelWorkspace=get_param(name,'ModelWorkspace'); assignin(modelWorkspace,'P',P);
set_param(name,'Solver','FixedStepDiscrete','FixedStep',num2str(P.sim.Ts,16), ...
 'StopTime',num2str(P.sim.stopTime),'SaveTime','on','TimeSaveName','tout', ...
 'ReturnWorkspaceOutputs','on','SignalLogging','off','ModelVersionFormat','%<AutoIncrement:1.0>');

add_block('simulink/Sources/From Workspace',[name '/Scenario_Profile'], ...
 'VariableName','scenario_input','Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[20 40 145 75]);
addScenarioSubsystem([name '/Scenario Inputs'],[190 20 330 155]);
addSFunctionSubsystem([name '/PV Source'],'pv_source_sfunc',3,{'PV Voltage','PV Current','PV Power','Available MPP'},[410 20 570 140]);
addSFunctionSubsystem([name '/MPPT Controller'],'mppt_sfunc',2,{'Duty'},[650 20 800 100]);
addSFunctionSubsystem([name '/Averaged Boost Converter'],'boost_converter_sfunc',3,{'Inductor Current','Boost Output Current'},[880 20 1060 115]);
add_block('simulink/Math Operations/Gain',[name '/Surge Generator'],'Gain','1','Position',[390 210 520 245]);
set_param([name '/Surge Generator'],'AttributesFormatString','Normalized double-exponential or sustained scenario waveform');
addSFunctionSubsystem([name '/Cable and Source Impedance'],'cable_source_sfunc',2,{'Injected Current'},[600 185 790 270]);
addSFunctionSubsystem([name '/SPD MOV'],'spd_mov_sfunc',2,{'Demanded Current','Actual Current','Saturation Flag','Saturation Duration','Cumulative Energy','Overstress State','SPD Voltage'},[600 330 790 520]);
addSFunctionSubsystem([name '/Supercapacitor Interface'],'supercapacitor_interface_sfunc',2,{'Internal Voltage','Terminal Voltage','Raw Current Command','Limited Current Command','Actual Current','Bus Current','ESR Voltage','ESR Power','ESR Energy','Converter Enabled','Current Limit Flag','Current Limit Duration','Overvoltage Flag','Undervoltage Flag'},[855 285 1070 565]);
addSFunctionSubsystem([name '/Protection Controller'],'protection_controller_sfunc',5,{'Relay Command','Controller State','Overvoltage Timer','Warning Flag','Emergency Flag','Threshold Crossing Time','Trip Command Time','Safe Interval Start','Reconnect Command Time','Automatic Reset','Manual Reset','Protection Armed','Safe Interval Interruptions'},[1135 285 1355 565]);
addSFunctionSubsystem([name '/Relay Contactor'],'relay_contactor_sfunc',1,{'Physical State','Opening Time','Closing Time'},[1420 330 1580 450]);
addSFunctionSubsystem([name '/Averaged Microinverter Protected Load'],'microinverter_averaged_sfunc',3,{'DC Input Current','AC Output Power','Requested AC Power','UVLO','OV Shutdown','Soft Start','DC Input Power'},[1640 270 1865 480]);
addSFunctionSubsystem([name '/DC Bus Dynamics'],'dc_bus_sfunc',5,{'DC Bus Voltage','DC Bus Current'},[1120 70 1310 210]);
add_block('simulink/Math Operations/Product',[name '/SC Power'],'Position',[1110 590 1150 625]);
add_block('simulink/Math Operations/Product',[name '/Protected Load Voltage'],'Position',[1640 515 1685 550]);

add_line(name,'Scenario_Profile/1','Scenario Inputs/1');
add_line(name,'Scenario Inputs/1','PV Source/1'); add_line(name,'Scenario Inputs/2','PV Source/2'); add_line(name,'Averaged Boost Converter/1','PV Source/3');
add_line(name,'PV Source/1','MPPT Controller/1'); add_line(name,'PV Source/2','MPPT Controller/2');
add_line(name,'PV Source/1','Averaged Boost Converter/1'); add_line(name,'DC Bus Dynamics/1','Averaged Boost Converter/2'); add_line(name,'MPPT Controller/1','Averaged Boost Converter/3');
add_line(name,'Scenario Inputs/3','Surge Generator/1'); add_line(name,'Surge Generator/1','Cable and Source Impedance/1'); add_line(name,'DC Bus Dynamics/1','Cable and Source Impedance/2');
add_line(name,'DC Bus Dynamics/1','SPD MOV/1'); add_line(name,'Scenario Inputs/6','SPD MOV/2');
add_line(name,'DC Bus Dynamics/1','Supercapacitor Interface/1'); add_line(name,'Scenario Inputs/6','Supercapacitor Interface/2');
add_line(name,'DC Bus Dynamics/1','Protection Controller/1'); add_line(name,'Scenario Inputs/4','Protection Controller/2'); add_line(name,'Scenario Inputs/5','Protection Controller/3'); add_line(name,'Scenario Inputs/6','Protection Controller/4'); add_line(name,'Scenario Inputs/7','Protection Controller/5');
add_line(name,'Protection Controller/1','Relay Contactor/1');
add_line(name,'DC Bus Dynamics/1','Averaged Microinverter Protected Load/1'); add_line(name,'Relay Contactor/1','Averaged Microinverter Protected Load/2'); add_line(name,'Scenario Inputs/9','Averaged Microinverter Protected Load/3');
add_line(name,'Averaged Boost Converter/2','DC Bus Dynamics/1'); add_line(name,'Cable and Source Impedance/1','DC Bus Dynamics/2'); add_line(name,'SPD MOV/2','DC Bus Dynamics/3'); add_line(name,'Supercapacitor Interface/6','DC Bus Dynamics/4'); add_line(name,'Averaged Microinverter Protected Load/1','DC Bus Dynamics/5');
add_line(name,'Supercapacitor Interface/2','SC Power/1'); add_line(name,'Supercapacitor Interface/5','SC Power/2');
add_line(name,'DC Bus Dynamics/1','Protected Load Voltage/1'); add_line(name,'Relay Contactor/1','Protected Load Voltage/2');

names=required_signal_names(); sources={ ...
 'Scenario Inputs/1','Scenario Inputs/2','PV Source/1','PV Source/2','PV Source/3','PV Source/4','MPPT Controller/1','Averaged Boost Converter/1','DC Bus Dynamics/1','DC Bus Dynamics/2', ...
 'Surge Generator/1','SPD MOV/7','SPD MOV/2','Supercapacitor Interface/2','Supercapacitor Interface/5','Supercapacitor Interface/6','SC Power/1','Protection Controller/1','Relay Contactor/1','Protection Controller/2', ...
 'Protection Controller/3','Protection Controller/4','Protection Controller/5','Protection Controller/10','Protection Controller/11','Protected Load Voltage/1','Averaged Microinverter Protected Load/1','Averaged Microinverter Protected Load/2','Supercapacitor Interface/10', ...
 'SPD MOV/1','SPD MOV/3','SPD MOV/4','SPD MOV/5','SPD MOV/6', ...
 'Supercapacitor Interface/1','Supercapacitor Interface/2','Supercapacitor Interface/3','Supercapacitor Interface/4','Supercapacitor Interface/5','Supercapacitor Interface/7','Supercapacitor Interface/8','Supercapacitor Interface/9','Supercapacitor Interface/11','Supercapacitor Interface/12','Supercapacitor Interface/13','Supercapacitor Interface/14', ...
 'Protection Controller/6','Protection Controller/7','Relay Contactor/2','Protection Controller/8','Protection Controller/9','Relay Contactor/3','Protection Controller/12','Protection Controller/13', ...
 'Averaged Microinverter Protected Load/3','Averaged Microinverter Protected Load/4','Averaged Microinverter Protected Load/5','Averaged Microinverter Protected Load/6','Averaged Microinverter Protected Load/7'};
assert(numel(names)==numel(sources),'Logging source/name mismatch.');
add_block('simulink/Signal Routing/Mux',[name '/Measurement Mux'],'Inputs',num2str(numel(names)),'Position',[1930 15 1935 15+12*numel(names)]);
for k=1:numel(sources), add_line(name,sources{k},sprintf('Measurement Mux/%d',k),'autorouting','on'); end
addLoggingSubsystem([name '/Measurements and Logging'],names,[2010 180 2200 500]); add_line(name,'Measurement Mux/1','Measurements and Logging/1');
set_param(name,'Description',sprintf('Canonical modular BuildVersion=%d; Simulink physical-equation fallback.',P.project.buildVersion));
set_param(name,'ZoomFactor','FitSystem'); save_system(name,modelPath); close_system(name,0);
end

function addScenarioSubsystem(path,pos)
add_block('simulink/Ports & Subsystems/Subsystem',path,'Position',pos); Simulink.SubSystem.deleteContents(path);
add_block('simulink/Ports & Subsystems/In1',[path '/Scenario Vector'],'Position',[20 70 50 84]);
add_block('simulink/Signal Routing/Demux',[path '/Demux'],'Outputs','9','Position',[90 20 95 155]); add_line(path,'Scenario Vector/1','Demux/1');
labels={'Irradiance','Temperature','Surge Command','Manual Reset','Automatic Reset','Protection Mode','Sensor Noise','Load Scale','Detailed Enable'};
for k=1:9, add_block('simulink/Ports & Subsystems/Out1',[path '/' labels{k}],'Port',num2str(k),'Position',[170 10+18*k 200 24+18*k]); add_line(path,sprintf('Demux/%d',k),sprintf('%s/1',labels{k})); end
end

function addSFunctionSubsystem(path,functionName,nInputs,outputNames,pos)
add_block('simulink/Ports & Subsystems/Subsystem',path,'Position',pos); Simulink.SubSystem.deleteContents(path);
for k=1:nInputs, add_block('simulink/Ports & Subsystems/In1',[path sprintf('/In%d',k)],'Port',num2str(k),'Position',[15 20+28*k 45 34+28*k]); end
add_block('simulink/Signal Routing/Mux',[path '/Input Mux'],'Inputs',num2str(nInputs),'Position',[80 35 85 35+25*nInputs]);
for k=1:nInputs, add_line(path,sprintf('In%d/1',k),sprintf('Input Mux/%d',k)); end
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[path '/Executable Component'],'FunctionName',functionName,'Parameters','P','Position',[125 45 265 95]); add_line(path,'Input Mux/1','Executable Component/1');
if numel(outputNames)>1
 add_block('simulink/Signal Routing/Demux',[path '/Output Demux'],'Outputs',num2str(numel(outputNames)),'Position',[305 20 310 20+18*numel(outputNames)]); add_line(path,'Executable Component/1','Output Demux/1');
end
for k=1:numel(outputNames)
 safe=matlab.lang.makeValidName(outputNames{k}); add_block('simulink/Ports & Subsystems/Out1',[path '/' safe],'Port',num2str(k),'Position',[365 8+22*k 395 22+22*k]);
 if numel(outputNames)>1, add_line(path,sprintf('Output Demux/%d',k),sprintf('%s/1',safe)); else, add_line(path,'Executable Component/1',sprintf('%s/1',safe)); end
end
end

function addLoggingSubsystem(path,names,pos)
add_block('simulink/Ports & Subsystems/Subsystem',path,'Position',pos); Simulink.SubSystem.deleteContents(path);
add_block('simulink/Ports & Subsystems/In1',[path '/Measured Vector'],'Position',[15 80 45 94]);
add_block('simulink/Signal Routing/Demux',[path '/Named Demux'],'Outputs',num2str(numel(names)),'Position',[85 10 90 15+12*numel(names)]); add_line(path,'Measured Vector/1','Named Demux/1');
for k=1:numel(names)
 y=5+(k-1)*20; add_block('simulink/Sinks/To Workspace',[path '/' char(names{k})],'VariableName',char(names{k}),'SaveFormat','Timeseries','Position',[160 y 310 y+15]); add_line(path,sprintf('Named Demux/%d',k),sprintf('%s/1',names{k}));
end
end
