function modelPath = build_simscape_component_model()
%BUILD_SIMSCAPE_COMPONENT_MODEL Build the physical-component project model.
% The verified code-oriented model remains unchanged. This companion model
% uses Simscape and Simscape Electrical components for the electrical plant
% and retains code only for MPPT, protection, relay timing, and SC control.

root = fileparts(fileparts(mfilename('fullpath')));
P = simscape_user_settings(project_parameters());
S = test_scenarios(P);
defaultScenario = S(find(string({S.Test_ID}) == "T05",1));
scenario_input = configure_scenario(defaultScenario,P);
lightning_profile = prepare_indirect_lightning_profile(P);

name = 'PV_Lightning_Protection_Simscape';
modelPath = fullfile(root,'model',[name '.slx']);
if bdIsLoaded(name), close_system(name,0); end
if isfile(modelPath), delete(modelPath); end

new_system(name);
mw = get_param(name,'ModelWorkspace');
assignin(mw,'P',P);
assignin(mw,'scenario_input',scenario_input);
assignin(mw,'defaultScenario',defaultScenario);
assignin(mw,'lightning_profile',lightning_profile);

set_param(name, ...
    'SolverType','Variable-step', ...
    'Solver','ode23t', ...
    'MaxStep','P.sim.Ts', ...
    'RelTol','1e-4', ...
    'AbsTol','1e-6', ...
    'StopTime','defaultScenario.StopTime', ...
    'ReturnWorkspaceOutputs','on', ...
    'SaveTime','on', ...
    'TimeSaveName','tout', ...
    'SignalLogging','off', ...
    'Description',['Physical Simscape Electrical implementation of the PV lightning ' ...
    'protection project. Electrical plant uses library components; MPPT and ' ...
    'protection supervisory algorithms retain the verified project code.']);

%% Scenario and supervisory signals
add_block('simulink/Sources/From Workspace',[name '/Scenario Profile'], ...
    'VariableName','scenario_input','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','Position',[20 40 150 72]);
add_block('simulink/Signal Routing/Demux',[name '/Scenario Demux'], ...
    'Outputs','9','Position',[185 20 190 165]);
add_line(name,'Scenario Profile/1','Scenario Demux/1');
addUserSettingsMask(name,P);

add_block('nesl_utility/Simulink-PS Converter',[name '/Irradiance to PS'], ...
    'Unit','W/m^2','Position',[230 25 270 55]);
add_line(name,'Scenario Demux/1','Irradiance to PS/1');

%% Physical PV source and averaged boost stage
add_block('ee_lib/Sources/Solar Cell',[name '/PV Array - Solar Cell'], ...
    'Isc','P.pv.Isc_A','Voc','P.pv.Voc_V/P.pv.cellsSeries', ...
    'Rs','P.pv.Rs_Ohm/P.pv.cellsSeries', ...
    'Rp','P.pv.Rsh_Ohm/P.pv.cellsSeries', ...
    'N_series','P.pv.cellsSeries*P.pv.modulesSeries', ...
    'N_parallel','P.pv.stringsParallel','TFIXED','P.pv.Tnom_C', ...
    'Position',[315 35 415 130]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/PV Current Sensor'], ...
    'Position',[455 60 505 105]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[name '/PV Voltage Sensor'], ...
    'Position',[370 160 420 205]);
add_block('fl_lib/Electrical/Electrical Elements/Capacitor',[name '/PV Input Capacitor'], ...
    'C','P.boost.Cin_F','v_specify','off','v_priority','None', ...
    'v','P.pv.Vmp_V','Position',[500 110 555 145]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [name '/PV-side Converter Current Draw'], ...
    'Position',[585 35 645 95]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [name '/Bus-side Converter Current Injection'], ...
    'Position',[825 35 885 95]);

add_block('nesl_utility/PS-Simulink Converter',[name '/PV Voltage to Simulink'], ...
    'Unit','V','Position',[450 165 490 195]);
add_block('nesl_utility/PS-Simulink Converter',[name '/PV Current to Simulink'], ...
    'Unit','A','Position',[520 165 560 195]);
add_block('simulink/Signal Routing/Mux',[name '/MPPT Input'], ...
    'Inputs','2','Position',[595 190 600 230]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/MPPT P and O Controller'], ...
    'FunctionName','mppt_sfunc','Parameters','P','Position',[630 185 765 235]);
add_block('simulink/Signal Routing/Mux',[name '/Averaged Boost Input'], ...
    'Inputs','3','Position',[790 165 795 235]);
add_block('simulink/Discrete/Unit Delay',[name '/Averaged Boost Feedback Delay'], ...
    'InitialCondition','[P.pv.Vmp_V; P.bus.nominalVoltage_V; P.mppt.initialDuty]', ...
    'SampleTime','P.sim.Ts','Position',[805 175 840 225]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Averaged Boost Controller'], ...
    'FunctionName','boost_converter_sfunc','Parameters','P', ...
    'Position',[875 170 1020 225]);
add_block('simulink/Signal Routing/Demux',[name '/Averaged Boost Outputs'], ...
    'Outputs','2','Position',[1005 165 1010 225]);
add_block('nesl_utility/Simulink-PS Converter',[name '/PV Draw Current to PS'], ...
    'Unit','A','FilteringAndDerivatives','filter','InputFilterTimeConstant','P.sim.Ts', ...
    'Position',[1035 160 1075 190]);
add_block('nesl_utility/Simulink-PS Converter',[name '/Bus Injection Current to PS'], ...
    'Unit','A','FilteringAndDerivatives','filter','InputFilterTimeConstant','P.sim.Ts', ...
    'Position',[1035 205 1075 235]);
add_line(name,'PV Voltage to Simulink/1','MPPT Input/1');
add_line(name,'PV Current to Simulink/1','MPPT Input/2');
add_line(name,'MPPT Input/1','MPPT P and O Controller/1');
add_line(name,'PV Voltage to Simulink/1','Averaged Boost Input/1','autorouting','on');
add_line(name,'MPPT P and O Controller/1','Averaged Boost Input/3','autorouting','on');
add_line(name,'Averaged Boost Input/1','Averaged Boost Feedback Delay/1');
add_line(name,'Averaged Boost Feedback Delay/1','Averaged Boost Controller/1');
add_line(name,'Averaged Boost Controller/1','Averaged Boost Outputs/1');
add_line(name,'Averaged Boost Outputs/1','PV Draw Current to PS/1');
add_line(name,'Averaged Boost Outputs/2','Bus Injection Current to PS/1');

%% DC bus, physical surge path, and measurements
add_block('fl_lib/Electrical/Electrical Elements/Capacitor',[name '/DC Link Capacitor'], ...
    'C','P.boost.Cout_F','v_specify','off','v_priority','None', ...
    'v','0','Position',[955 165 1025 205]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[name '/DC Bus Voltage Sensor'], ...
    'Position',[1060 165 1110 205]);
add_block('nesl_utility/PS-Simulink Converter',[name '/Bus Voltage to Simulink'], ...
    'Unit','V','Position',[1135 165 1175 195]);
add_line(name,'Bus Voltage to Simulink/1','Averaged Boost Input/2','autorouting','on');

add_block('simulink/Sources/From Workspace',[name '/Indirect Lightning 8-20 us Profile'], ...
    'VariableName','lightning_profile','Interpolate','on', ...
    'OutputAfterFinalValue','Setting to zero','Position',[20 300 165 335]);
add_block('simulink/Math Operations/Gain',[name '/Configured Lightning Current'], ...
    'Gain','P.lightning.peakCurrent_A','Position',[190 270 270 300]);
add_block('simulink/Math Operations/Gain',[name '/Configured Lightning Voltage'], ...
    'Gain','P.lightning.peakVoltage_V','Position',[190 330 270 360]);
add_block('simulink/Math Operations/Gain',[name '/Selected Norton Current'], ...
    'Gain',['(P.lightning.mode==1)*P.lightning.peakCurrent_A+' ...
    '(P.lightning.mode==2)*P.lightning.peakVoltage_V/' ...
    'P.lightning.voltageSourceResistance_Ohm'], ...
    'Position',[300 285 410 325]);
add_block('nesl_utility/Simulink-PS Converter',[name '/Lightning Current to PS'], ...
    'Unit','A','Position',[430 290 470 320]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [name '/Selectable Lightning Injection Source'],'Position',[500 275 560 335]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor', ...
    [name '/Injection Source Shunt Resistance'], ...
    'R',['(P.lightning.mode==1)*P.lightning.currentSourceParallelResistance_Ohm+' ...
    '(P.lightning.mode==2)*P.lightning.voltageSourceResistance_Ohm'], ...
    'Position',[590 355 660 395]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    [name '/Injected Current Sensor'],'Position',[590 280 640 320]);
add_block('nesl_utility/PS-Simulink Converter',[name '/Injected Current to Simulink'], ...
    'Unit','A','Position',[585 230 625 260]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [name '/Injection Voltage Sensor'],'Position',[485 365 535 405]);
add_block('nesl_utility/PS-Simulink Converter',[name '/Injection Voltage to Simulink'], ...
    'Unit','V','Position',[555 410 595 440]);
add_line(name,'Indirect Lightning 8-20 us Profile/1','Configured Lightning Current/1');
add_line(name,'Indirect Lightning 8-20 us Profile/1','Configured Lightning Voltage/1');
add_line(name,'Indirect Lightning 8-20 us Profile/1','Selected Norton Current/1');
add_line(name,'Selected Norton Current/1','Lightning Current to PS/1');
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/Surge Source Inductance'], ...
    'L','P.lightning.sourceInductance_H','Position',[665 280 735 320]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/DC Cable Resistance'], ...
    'R','P.cable.R_Ohm','Position',[755 280 825 320]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/DC Cable Inductance'], ...
    'L','P.cable.L_H','Position',[845 280 915 320]);
add_block('fl_lib/Electrical/Electrical Elements/Diode',[name '/Surge Blocking Diode'], ...
    'Vf','0.8','Ron','0.01','Goff','1e-8','Position',[925 280 970 320]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/Surge Current Sensor'], ...
    'Position',[985 280 1035 320]);
add_block('nesl_utility/PS-Simulink Converter',[name '/Surge Current to Simulink'], ...
    'Unit','A','Position',[940 345 980 375]);

%% SPD1 indirect-lightning branch (upstream/cable-entry diversion)
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/SPD Current Sensor'], ...
    'Position',[750 400 800 440]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/SPD Lead Inductance'], ...
    'L','P.spd1.leadInductance_H','Position',[825 400 895 440]);
add_block('ee_lib/Passive/Varistor',[name '/SPD MOV Varistor'], ...
    'prm','ee.enum.passive.varistor.varistorParameterization.linear', ...
    'vclamp','P.spd1.lowerVoltage_V', ...
    'roff','P.spd1.leakageResistance_Ohm', ...
    'ron','P.spd1.dynamicResistance_Ohm', ...
    'Position',[920 400 990 440]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/SPD Ground Resistance'], ...
    'R','P.spd1.groundResistance_Ohm','Position',[1015 400 1085 440]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/SPD Ground Inductance'], ...
    'L','P.spd1.groundInductance_H','Position',[1110 400 1180 440]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SPD Current to Simulink'], ...
    'Unit','A','Position',[750 455 790 485]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[name '/SPD1 Voltage Sensor'], ...
    'Position',[665 455 715 495]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SPD1 Voltage to Simulink'], ...
    'Unit','V','Position',[665 510 705 540]);

%% SPD2 indirect/residual-surge branch (mounted at protected DC bus)
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/SPD2 Current Sensor'], ...
    'Position',[925 615 975 655]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/SPD2 Lead Inductance'], ...
    'L','P.spd2.leadInductance_H','Position',[1005 615 1075 655]);
add_block('ee_lib/Passive/Varistor',[name '/SPD2 MOV Varistor'], ...
    'prm','ee.enum.passive.varistor.varistorParameterization.linear', ...
    'vclamp','P.spd2.lowerVoltage_V', ...
    'roff','P.spd2.leakageResistance_Ohm', ...
    'ron','P.spd2.dynamicResistance_Ohm', ...
    'Position',[1105 615 1175 655]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/SPD2 Ground Resistance'], ...
    'R','P.spd2.groundResistance_Ohm','Position',[1205 615 1275 655]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/SPD2 Ground Inductance'], ...
    'L','P.spd2.groundInductance_H','Position',[1305 615 1375 655]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SPD2 Current to Simulink'], ...
    'Unit','A','Position',[925 670 965 700]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    [name '/SPD2 Output Current Sensor'],'Position',[1040 545 1090 585]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor', ...
    [name '/SPD2 Coordination Inductance'], ...
    'L','P.spd2.coordinationInductance_H','Position',[1115 545 1185 585]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor', ...
    [name '/SPD2 Coordination Resistance'], ...
    'R','P.spd2.coordinationResistance_Ohm','Position',[1210 545 1280 585]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SPD2 Output Current to Simulink'], ...
    'Unit','A','Position',[1040 500 1080 530]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [name '/SPD2 Voltage Sensor'],'Position',[875 545 925 585]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SPD2 Voltage to Simulink'], ...
    'Unit','V','Position',[940 545 980 575]);

%% Physical supercapacitor with controlled bidirectional interface
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source',[name '/SC Bidirectional Interface'], ...
    'Position',[930 465 990 525]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/SC Current Sensor'], ...
    'Position',[1020 470 1070 510]);
add_block('fl_lib/Electrical/Electrical Elements/Inductor',[name '/SC Converter Inductance'], ...
    'L','P.sc.converterInductance_H','Position',[1100 470 1170 510]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/SC Converter Path Resistance'], ...
    'R','P.sc.converterPathResistance_Ohm','Position',[1200 470 1270 510]);
add_block('ee_lib/Passive/Supercapacitor',[name '/Supercapacitor Bank'], ...
    'R','[P.sc.ESR_Ohm P.sc.leakageResistance_Ohm 1e9]', ...
    'C','[P.sc.capacitance_F 1e-6 1e-6]','Kv','1e-6', ...
    'R_discharge','P.sc.leakageResistance_Ohm', ...
    'vc1_specify','on','vc1_priority','High','vc1','P.sc.initialVoltage_V', ...
    'Position',[1310 445 1380 535]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[name '/SC Voltage Sensor'], ...
    'Position',[1315 570 1365 610]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SC Voltage to Simulink'], ...
    'Unit','V','Position',[1400 570 1440 600]);
add_block('nesl_utility/PS-Simulink Converter',[name '/SC Current to Simulink'], ...
    'Unit','A','Position',[1020 545 1060 575]);
add_block('simulink/Discrete/Memory',[name '/SC Bus Measurement Delay'], ...
    'X0','P.bus.prechargeVoltage_V','Position',[1190 415 1230 445]);
add_block('simulink/Signal Routing/Mux',[name '/SC Controller Input'], ...
    'Inputs','2','Position',[1260 390 1265 440]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/SC Supervisory Controller'], ...
    'FunctionName','supercapacitor_interface_sfunc','Parameters','P', ...
    'Position',[1300 365 1450 430]);
add_block('simulink/Signal Routing/Demux',[name '/SC Controller Outputs'], ...
    'Outputs','14','Position',[1480 345 1485 455]);
add_block('nesl_utility/Simulink-PS Converter',[name '/SC Command to PS'], ...
    'Unit','A','FilteringAndDerivatives','filter','InputFilterTimeConstant','P.sim.Ts', ...
    'Position',[1515 455 1555 485]);
add_block('simulink/Math Operations/Gain',[name '/SC Physical Direction'], ...
    'Gain','-1','Position',[1495 485 1535 515]);
add_line(name,'Bus Voltage to Simulink/1','SC Bus Measurement Delay/1');
add_line(name,'SC Bus Measurement Delay/1','SC Controller Input/1');
add_line(name,'Scenario Demux/6','SC Controller Input/2');
add_line(name,'SC Controller Input/1','SC Supervisory Controller/1');
add_line(name,'SC Supervisory Controller/1','SC Controller Outputs/1');
add_line(name,'SC Controller Outputs/5','SC Physical Direction/1');
add_line(name,'SC Physical Direction/1','SC Command to PS/1');

%% Protection controller and physical relay
add_block('simulink/Signal Routing/Mux',[name '/Protection Input'], ...
    'Inputs','5','Position',[1210 120 1215 220]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Protection State Machine'], ...
    'FunctionName','protection_controller_sfunc','Parameters','P', ...
    'Position',[1250 105 1415 225]);
add_block('simulink/Signal Routing/Demux',[name '/Protection Outputs'], ...
    'Outputs','13','Position',[1445 90 1450 240]);
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Relay Timing'], ...
    'FunctionName','relay_contactor_sfunc','Parameters','P', ...
    'Position',[1490 100 1595 140]);
add_block('simulink/Signal Routing/Demux',[name '/Relay Timing Outputs'], ...
    'Outputs','3','Position',[1620 90 1625 150]);
add_block('nesl_utility/Simulink-PS Converter',[name '/Relay State to PS'], ...
    'Unit','1','Position',[1655 105 1695 135]);
add_block('fl_lib/Electrical/Electrical Elements/Switch',[name '/Protected Load Contactor'], ...
    'R_closed','P.relay.closedResistance_Ohm', ...
    'G_open','1/P.relay.openResistance_Ohm','Threshold','0.5', ...
    'Position',[1480 275 1540 335]);
add_line(name,'Bus Voltage to Simulink/1','Protection Input/1');
add_line(name,'Scenario Demux/4','Protection Input/2');
add_line(name,'Scenario Demux/5','Protection Input/3');
add_line(name,'Scenario Demux/6','Protection Input/4');
add_line(name,'Scenario Demux/7','Protection Input/5');
add_line(name,'Protection Input/1','Protection State Machine/1');
add_line(name,'Protection State Machine/1','Protection Outputs/1');
add_line(name,'Protection Outputs/1','Relay Timing/1');
add_line(name,'Relay Timing/1','Relay Timing Outputs/1');
add_line(name,'Relay Timing Outputs/1','Relay State to PS/1');

%% Averaged protected DC load and isolated physical AC output stage
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/Protected DC Inverter Load'], ...
    'R','P.load.resistance_Ohm','Position',[1590 285 1660 325]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Voltage Source', ...
    [name '/Averaged Microinverter AC Source'], ...
    'Position',[1590 400 1650 460]);
add_block('simulink/Sources/Sine Wave',[name '/AC Modulation Reference'], ...
    'Amplitude','sqrt(2)*P.inverter.demoRMSVoltage_V/P.bus.nominalVoltage_V', ...
    'Frequency','2*pi*P.inverter.demoFrequency_Hz','SampleTime','0', ...
    'Position',[1510 215 1600 245]);
add_block('simulink/Sources/Ramp',[name '/Inverter Soft Start Ramp'], ...
    'slope','1/P.load.softStart_s','start','0','InitialOutput','0', ...
    'Position',[1480 175 1560 200]);
add_block('simulink/Discontinuities/Saturation',[name '/Soft Start Limit'], ...
    'UpperLimit','1','LowerLimit','0','Position',[1580 175 1620 200]);
add_block('simulink/Math Operations/Product',[name '/Soft Started Modulation'], ...
    'Position',[1625 205 1660 245]);
add_block('simulink/Math Operations/Product',[name '/AC Voltage Command'], ...
    'Position',[1680 205 1715 245]);
add_block('nesl_utility/Simulink-PS Converter',[name '/Modulation to PS'], ...
    'Unit','V','Position',[1740 215 1780 245]);
add_line(name,'Inverter Soft Start Ramp/1','Soft Start Limit/1');
add_line(name,'Soft Start Limit/1','Soft Started Modulation/1');
add_line(name,'AC Modulation Reference/1','Soft Started Modulation/2');
add_line(name,'Soft Started Modulation/1','AC Voltage Command/1');
add_line(name,'Bus Voltage to Simulink/1','AC Voltage Command/2','autorouting','on');
add_line(name,'AC Voltage Command/1','Modulation to PS/1');
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[name '/AC Current Sensor'], ...
    'Position',[1770 280 1820 320]);
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[name '/Microinverter AC Load'], ...
    'R','P.inverter.demoRMSVoltage_V^2/P.load.requestedACPower_W', ...
    'Position',[1850 280 1920 320]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[name '/AC Voltage Sensor'], ...
    'Position',[1770 365 1820 405]);
add_block('nesl_utility/PS-Simulink Converter',[name '/AC Voltage to Simulink'], ...
    'Unit','V','Position',[1860 365 1900 395]);
add_block('nesl_utility/PS-Simulink Converter',[name '/AC Current to Simulink'], ...
    'Unit','A','Position',[1770 420 1810 450]);

%% References and physical solver
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference',[name '/Electrical Reference'], ...
    'Position',[835 650 875 690]);
for k = 2:8
    add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
        [name '/Electrical Reference ' num2str(k)], ...
        'Position',[835 + 55*(k-1) 650 875 + 55*(k-1) 690]);
end
add_block('nesl_utility/Solver Configuration',[name '/Solver Configuration'], ...
    'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER', ...
    'LocalSolverSampleTime','P.lightning.localSolverStep_s', ...
    'Position',[745 635 815 695]);
add_block('nesl_utility/Solver Configuration',[name '/PV Solver Configuration'], ...
    'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER', ...
    'LocalSolverSampleTime','P.sim.Ts/50','Position',[660 105 730 165]);
add_block('nesl_utility/Solver Configuration',[name '/AC Solver Configuration'], ...
    'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER', ...
    'LocalSolverSampleTime','P.sim.Ts/25','Position',[1510 635 1580 695]);

%% Physical connections
connect(name,'Irradiance to PS','RConn',1,'PV Array - Solar Cell','LConn',1);
connect(name,'PV Array - Solar Cell','LConn',2,'PV Current Sensor','LConn',1);
connect(name,'PV Current Sensor','RConn',2,'PV-side Converter Current Draw','RConn',2);
connect(name,'PV Array - Solar Cell','RConn',1,'PV-side Converter Current Draw','LConn',1);
connect(name,'PV Draw Current to PS','RConn',1,'PV-side Converter Current Draw','RConn',1);
connect(name,'PV Voltage Sensor','LConn',1,'PV Array - Solar Cell','LConn',2);
connect(name,'PV Voltage Sensor','RConn',2,'PV Array - Solar Cell','RConn',1);
connect(name,'PV Voltage Sensor','RConn',1,'PV Voltage to Simulink','LConn',1);
connect(name,'PV Current Sensor','RConn',1,'PV Current to Simulink','LConn',1);
connect(name,'PV Input Capacitor','LConn',1,'PV Array - Solar Cell','LConn',2);
connect(name,'PV Input Capacitor','RConn',1,'PV Array - Solar Cell','RConn',1);

connect(name,'Bus-side Converter Current Injection','LConn',1,'DC Link Capacitor','LConn',1);
connect(name,'DC Link Capacitor','LConn',1,'DC Bus Voltage Sensor','LConn',1);
connect(name,'DC Bus Voltage Sensor','RConn',1,'Bus Voltage to Simulink','LConn',1);
connect(name,'Bus-side Converter Current Injection','RConn',2,'DC Link Capacitor','RConn',1);
connect(name,'Bus Injection Current to PS','RConn',1,'Bus-side Converter Current Injection','RConn',1);
connect(name,'DC Bus Voltage Sensor','RConn',2,'DC Link Capacitor','RConn',1);

connect(name,'Lightning Current to PS','RConn',1,'Selectable Lightning Injection Source','RConn',1);
connect(name,'Selectable Lightning Injection Source','LConn',1,'Injected Current Sensor','LConn',1);
connect(name,'Injected Current Sensor','RConn',2,'Surge Source Inductance','LConn',1);
connect(name,'Injected Current Sensor','RConn',1,'Injected Current to Simulink','LConn',1);
connect(name,'Injection Source Shunt Resistance','LConn',1,'Selectable Lightning Injection Source','LConn',1);
connect(name,'Injection Source Shunt Resistance','RConn',1,'Selectable Lightning Injection Source','RConn',2);
connect(name,'Injection Voltage Sensor','LConn',1,'Selectable Lightning Injection Source','LConn',1);
connect(name,'Injection Voltage Sensor','RConn',2,'Selectable Lightning Injection Source','RConn',2);
connect(name,'Injection Voltage Sensor','RConn',1,'Injection Voltage to Simulink','LConn',1);
connect(name,'Surge Source Inductance','RConn',1,'DC Cable Resistance','LConn',1);
connect(name,'DC Cable Resistance','RConn',1,'DC Cable Inductance','LConn',1);
connect(name,'DC Cable Inductance','RConn',1,'Surge Blocking Diode','LConn',1);
connect(name,'Surge Blocking Diode','RConn',1,'Surge Current Sensor','LConn',1);
connect(name,'Surge Current Sensor','RConn',1,'Surge Current to Simulink','LConn',1);

connect(name,'Surge Source Inductance','RConn',1,'SPD Current Sensor','LConn',1);
connect(name,'SPD Current Sensor','RConn',2,'SPD Lead Inductance','LConn',1);
connect(name,'SPD Lead Inductance','RConn',1,'SPD MOV Varistor','LConn',1);
connect(name,'SPD MOV Varistor','RConn',1,'SPD Ground Resistance','LConn',1);
connect(name,'SPD Ground Resistance','RConn',1,'SPD Ground Inductance','LConn',1);
connect(name,'SPD Current Sensor','RConn',1,'SPD Current to Simulink','LConn',1);
connect(name,'SPD1 Voltage Sensor','LConn',1,'Surge Source Inductance','RConn',1);
connect(name,'SPD1 Voltage Sensor','RConn',2,'Selectable Lightning Injection Source','RConn',2);
connect(name,'SPD1 Voltage Sensor','RConn',1,'SPD1 Voltage to Simulink','LConn',1);

connect(name,'Surge Current Sensor','RConn',2,'SPD2 Current Sensor','LConn',1);
connect(name,'SPD2 Current Sensor','RConn',2,'SPD2 Lead Inductance','LConn',1);
connect(name,'SPD2 Lead Inductance','RConn',1,'SPD2 MOV Varistor','LConn',1);
connect(name,'SPD2 MOV Varistor','RConn',1,'SPD2 Ground Resistance','LConn',1);
connect(name,'SPD2 Ground Resistance','RConn',1,'SPD2 Ground Inductance','LConn',1);
connect(name,'SPD2 Current Sensor','RConn',1,'SPD2 Current to Simulink','LConn',1);
connect(name,'Surge Current Sensor','RConn',2,'SPD2 Output Current Sensor','LConn',1);
connect(name,'SPD2 Output Current Sensor','RConn',2,'SPD2 Coordination Inductance','LConn',1);
connect(name,'SPD2 Coordination Inductance','RConn',1,'SPD2 Coordination Resistance','LConn',1);
connect(name,'SPD2 Coordination Resistance','RConn',1,'DC Link Capacitor','LConn',1);
connect(name,'SPD2 Output Current Sensor','RConn',1,'SPD2 Output Current to Simulink','LConn',1);
connect(name,'SPD2 Voltage Sensor','LConn',1,'Surge Current Sensor','RConn',2);
connect(name,'SPD2 Voltage Sensor','RConn',2,'DC Link Capacitor','RConn',1);
connect(name,'SPD2 Voltage Sensor','RConn',1,'SPD2 Voltage to Simulink','LConn',1);

connect(name,'DC Link Capacitor','LConn',1,'SC Bidirectional Interface','LConn',1);
connect(name,'SC Command to PS','RConn',1,'SC Bidirectional Interface','RConn',1);
connect(name,'SC Bidirectional Interface','RConn',2,'SC Current Sensor','LConn',1);
connect(name,'SC Current Sensor','RConn',2,'SC Converter Inductance','LConn',1);
connect(name,'SC Converter Inductance','RConn',1,'SC Converter Path Resistance','LConn',1);
connect(name,'SC Converter Path Resistance','RConn',1,'Supercapacitor Bank','LConn',1);
connect(name,'SC Current Sensor','RConn',1,'SC Current to Simulink','LConn',1);
connect(name,'SC Voltage Sensor','LConn',1,'Supercapacitor Bank','LConn',1);
connect(name,'SC Voltage Sensor','RConn',2,'Supercapacitor Bank','RConn',1);
connect(name,'SC Voltage Sensor','RConn',1,'SC Voltage to Simulink','LConn',1);

connect(name,'DC Link Capacitor','LConn',1,'Protected Load Contactor','LConn',1);
connect(name,'Relay State to PS','RConn',1,'Protected Load Contactor','RConn',1);
connect(name,'Protected Load Contactor','RConn',2,'Protected DC Inverter Load','LConn',1);
connect(name,'Protected DC Inverter Load','RConn',1,'DC Link Capacitor','RConn',1);
connect(name,'Modulation to PS','RConn',1,'Averaged Microinverter AC Source','RConn',1);
connect(name,'Averaged Microinverter AC Source','LConn',1,'AC Current Sensor','LConn',1);
connect(name,'AC Current Sensor','RConn',2,'Microinverter AC Load','LConn',1);
connect(name,'Microinverter AC Load','RConn',1,'Averaged Microinverter AC Source','RConn',2);
connect(name,'AC Current Sensor','RConn',1,'AC Current to Simulink','LConn',1);
connect(name,'AC Voltage Sensor','LConn',1,'Averaged Microinverter AC Source','LConn',1);
connect(name,'AC Voltage Sensor','RConn',2,'Averaged Microinverter AC Source','RConn',2);
connect(name,'AC Voltage Sensor','RConn',1,'AC Voltage to Simulink','LConn',1);
connect(name,'Averaged Microinverter AC Source','RConn',2,'Electrical Reference 8','LConn',1);
connect(name,'Averaged Microinverter AC Source','RConn',2,'AC Solver Configuration','RConn',1);

% Common electrical reference node and solver connection.
grounds = { ...
    {'PV Array - Solar Cell','RConn',1}, {'DC Link Capacitor','RConn',1}, ...
    {'Selectable Lightning Injection Source','RConn',2}, ...
    {'SPD Ground Inductance','RConn',1}, {'Supercapacitor Bank','RConn',1}, ...
    {'SPD2 Ground Inductance','RConn',1}};
for k = 1:numel(grounds)
    g = grounds{k};
    referenceName = 'Electrical Reference';
    if k > 1, referenceName = ['Electrical Reference ' num2str(k)]; end
    connect(name,g{1},g{2},g{3},referenceName,'LConn',1);
end
connect(name,'Solver Configuration','RConn',1,'DC Link Capacitor','RConn',1);
connect(name,'PV Solver Configuration','RConn',1,'PV Array - Solar Cell','RConn',1);

%% Scopes and workspace logs
add_block('simulink/Math Operations/Product',[name '/PV Power'], ...
    'Position',[540 245 575 280]);
add_line(name,'PV Voltage to Simulink/1','PV Power/1','autorouting','on');
add_line(name,'PV Current to Simulink/1','PV Power/2','autorouting','on');
add_block('simulink/Math Operations/Product',[name '/SC Physical Power'], ...
    'Position',[1130 585 1165 620]);
add_line(name,'SC Voltage to Simulink/1','SC Physical Power/1','autorouting','on');
add_line(name,'SC Current to Simulink/1','SC Physical Power/2','autorouting','on');
add_block('simulink/Discontinuities/Saturation',[name '/SC Absorbed Power'], ...
    'UpperLimit','inf','LowerLimit','0','Position',[1190 590 1235 620]);
add_block('simulink/Continuous/Integrator',[name '/SC Absorbed Energy'], ...
    'InitialCondition','0','Position',[1260 590 1295 620]);
add_line(name,'SC Physical Power/1','SC Absorbed Power/1');
add_line(name,'SC Absorbed Power/1','SC Absorbed Energy/1');
add_block('simulink/Math Operations/Product',[name '/Protected Residual Power'], ...
    'Position',[1170 675 1205 710]);
add_line(name,'Bus Voltage to Simulink/1','Protected Residual Power/1','autorouting','on');
add_line(name,'SPD2 Output Current to Simulink/1','Protected Residual Power/2');
add_block('simulink/Math Operations/Sum',[name '/Protection Voltage Reduction'], ...
    'Inputs','+-','Position',[1215 640 1245 670]);
add_line(name,'Injection Voltage to Simulink/1','Protection Voltage Reduction/1','autorouting','on');
add_line(name,'Bus Voltage to Simulink/1','Protection Voltage Reduction/2','autorouting','on');

add_block('simulink/Sources/Constant',[name '/Warning Voltage Threshold'], ...
    'Value','P.threshold.warningVoltage_V','Position',[1330 705 1395 735]);
add_block('simulink/Sources/Constant',[name '/Emergency Trip Voltage Threshold'], ...
    'Value','P.threshold.emergencyTripVoltage_V','Position',[1330 740 1395 770]);
add_block('simulink/Sources/Constant',[name '/Safe Recovery Voltage Threshold'], ...
    'Value','P.threshold.safeRecoveryUpperVoltage_V','Position',[1330 775 1395 805]);

% Numbered Scopes follow the priority document from source to protected load.
addScope(name,'01 - PV Array and MPPT',4,[330 735 390 775]);
addNamedScopeLine(name,'PV Voltage to Simulink/1','01 - PV Array and MPPT/1','PV voltage (V)');
addNamedScopeLine(name,'PV Current to Simulink/1','01 - PV Array and MPPT/2','PV current (A)');
addNamedScopeLine(name,'PV Power/1','01 - PV Array and MPPT/3','PV power (W)');
addNamedScopeLine(name,'MPPT P and O Controller/1','01 - PV Array and MPPT/4','MPPT duty cycle');

addScope(name,'02 - Indirect Lightning Injection',4,[520 735 580 775]);
addNamedScopeLine(name,'Configured Lightning Current/1','02 - Indirect Lightning Injection/1','Configured 8-20 us current (A)');
addNamedScopeLine(name,'Configured Lightning Voltage/1','02 - Indirect Lightning Injection/2','Configured 8-20 us voltage (V)');
addNamedScopeLine(name,'Injected Current to Simulink/1','02 - Indirect Lightning Injection/3','Measured injected current (A)');
addNamedScopeLine(name,'Injection Voltage to Simulink/1','02 - Indirect Lightning Injection/4','Measured injection voltage (V)');

addScope(name,'03 - SPD1 Diversion and Output',4,[710 735 770 775]);
addNamedScopeLine(name,'Injected Current to Simulink/1','03 - SPD1 Diversion and Output/1','Injected current (A)');
addNamedScopeLine(name,'SPD Current to Simulink/1','03 - SPD1 Diversion and Output/2','SPD1 diverted current (A)');
addNamedScopeLine(name,'Surge Current to Simulink/1','03 - SPD1 Diversion and Output/3','Residual current after SPD1 (A)');
addNamedScopeLine(name,'SPD1 Voltage to Simulink/1','03 - SPD1 Diversion and Output/4','SPD1 terminal voltage (V)');

addScope(name,'04 - SPD2 Diversion and Output',4,[900 735 960 775]);
addNamedScopeLine(name,'SPD2 Current to Simulink/1','04 - SPD2 Diversion and Output/1','SPD2 diverted current (A)');
addNamedScopeLine(name,'SPD2 Output Current to Simulink/1','04 - SPD2 Diversion and Output/2','Residual current after SPD2 (A)');
addNamedScopeLine(name,'Bus Voltage to Simulink/1','04 - SPD2 Diversion and Output/3','Protected DC bus voltage (V)');
addNamedScopeLine(name,'SPD2 Voltage to Simulink/1','04 - SPD2 Diversion and Output/4','SPD2 terminal voltage (V)');

addScope(name,'05 - Supercapacitor Buffer',4,[1090 735 1150 775]);
addNamedScopeLine(name,'SC Voltage to Simulink/1','05 - Supercapacitor Buffer/1','Supercapacitor voltage (V)');
addNamedScopeLine(name,'SC Current to Simulink/1','05 - Supercapacitor Buffer/2','Supercapacitor current (A)');
addNamedScopeLine(name,'SC Physical Power/1','05 - Supercapacitor Buffer/3','Supercapacitor power (W)');
addNamedScopeLine(name,'SC Absorbed Energy/1','05 - Supercapacitor Buffer/4','Cumulative absorbed energy (J)');

addScope(name,'06 - Relay Thresholds and Timing',6,[1280 735 1340 775]);
addNamedScopeLine(name,'Bus Voltage to Simulink/1','06 - Relay Thresholds and Timing/1','Monitored bus voltage (V)');
addNamedScopeLine(name,'Warning Voltage Threshold/1','06 - Relay Thresholds and Timing/2','Warning threshold (V)');
addNamedScopeLine(name,'Emergency Trip Voltage Threshold/1','06 - Relay Thresholds and Timing/3','Emergency trip threshold (V)');
addNamedScopeLine(name,'Safe Recovery Voltage Threshold/1','06 - Relay Thresholds and Timing/4','Safe recovery threshold (V)');
addNamedScopeLine(name,'Protection Outputs/1','06 - Relay Thresholds and Timing/5','Relay command');
addNamedScopeLine(name,'Relay Timing Outputs/1','06 - Relay Thresholds and Timing/6','Physical relay state');

addScope(name,'07 - Input versus Protected Output',4,[1470 735 1530 775]);
addNamedScopeLine(name,'Injection Voltage to Simulink/1','07 - Input versus Protected Output/1','Injection node voltage (V)');
addNamedScopeLine(name,'SPD1 Voltage to Simulink/1','07 - Input versus Protected Output/2','Voltage at SPD1 (V)');
addNamedScopeLine(name,'SPD2 Voltage to Simulink/1','07 - Input versus Protected Output/3','Voltage at SPD2 (V)');
addNamedScopeLine(name,'Bus Voltage to Simulink/1','07 - Input versus Protected Output/4','Protected output voltage (V)');

addScope(name,'08 - Inverter and Load',4,[1660 735 1720 775]);
addNamedScopeLine(name,'Bus Voltage to Simulink/1','08 - Inverter and Load/1','Protected DC bus voltage (V)');
addNamedScopeLine(name,'Relay Timing Outputs/1','08 - Inverter and Load/2','Physical relay state');
addNamedScopeLine(name,'AC Voltage to Simulink/1','08 - Inverter and Load/3','AC load voltage (V)');
addNamedScopeLine(name,'AC Current to Simulink/1','08 - Inverter and Load/4','AC load current (A)');

addLog(name,'Log Bus Voltage','Simscape_bus_voltage','Bus Voltage to Simulink/1',[1220 260 1355 290]);
addLog(name,'Log PV Voltage','Simscape_pv_voltage','PV Voltage to Simulink/1',[500 200 625 230]);
addLog(name,'Log PV Current','Simscape_pv_current','PV Current to Simulink/1',[500 235 625 265]);
addLog(name,'Log SPD Current','Simscape_spd_current','SPD Current to Simulink/1',[1010 390 1135 420]);
addLog(name,'Log SPD1 Voltage','Simscape_spd1_voltage','SPD1 Voltage to Simulink/1',[720 355 845 385]);
addLog(name,'Log SPD2 Current','Simscape_spd2_current','SPD2 Current to Simulink/1',[990 670 1115 700]);
addLog(name,'Log Surge Current','Simscape_surge_current','Surge Current to Simulink/1',[815 395 940 425]);
addLog(name,'Log SC Voltage','Simscape_sc_voltage','SC Voltage to Simulink/1',[1470 570 1595 600]);
addLog(name,'Log SC Current','Simscape_sc_current','SC Current to Simulink/1',[1090 545 1215 575]);
addLog(name,'Log AC Voltage','Simscape_ac_voltage','AC Voltage to Simulink/1',[1940 365 2060 395]);
addLog(name,'Log AC Current','Simscape_ac_current','AC Current to Simulink/1',[1840 420 1960 450]);
addLog(name,'Log Relay Command','Simscape_relay_command','Protection Outputs/1',[1470 35 1600 65]);
addLog(name,'Log Controller State','Simscape_controller_state','Protection Outputs/2',[1470 65 1600 95]);
addLog(name,'Log Relay State','Simscape_relay_state','Relay Timing Outputs/1',[1650 65 1775 95]);
addLog(name,'Log Configured Lightning Current','Simscape_configured_lightning_current','Configured Lightning Current/1',[300 530 445 560]);
addLog(name,'Log Configured Lightning Voltage','Simscape_configured_lightning_voltage','Configured Lightning Voltage/1',[300 565 445 595]);
addLog(name,'Log Injected Current','Simscape_injected_current','Injected Current to Simulink/1',[455 530 585 560]);
addLog(name,'Log Injection Voltage','Simscape_injection_voltage','Injection Voltage to Simulink/1',[455 565 585 595]);
addLog(name,'Log SPD2 Residual Current','Simscape_spd2_residual_current','SPD2 Output Current to Simulink/1',[1135 715 1275 745]);
addLog(name,'Log SPD2 Voltage','Simscape_spd2_voltage','SPD2 Voltage to Simulink/1',[985 545 1105 575]);
addLog(name,'Log SC Absorbed Energy','Simscape_sc_absorbed_energy','SC Absorbed Energy/1',[1305 590 1445 620]);
addLog(name,'Log Protection Voltage Reduction','Simscape_voltage_reduction','Protection Voltage Reduction/1',[1255 640 1400 670]);

note = Simulink.Annotation(name,sprintf([ ...
    'PHYSICAL SIMSCAPE ELECTRICAL MODEL\n' ...
    'Default: configurable 8/20 us indirect-lightning injection\n' ...
    'Edit config/simscape_user_settings.m, rebuild, then Run.\n' ...
    'Mode 1=current, Mode 2=voltage. Open Scopes 01 to 08.\n' ...
    'Algorithms retained as code: MPPT, protection state machine, relay timing, SC command']));
note.Position = [20 700 320 810];

set_param(name,'ZoomFactor','FitSystem');
save_system(name,modelPath);
close_system(name,0);
end

function connect(model,a,aField,aIndex,b,bField,bIndex)
% Connect Simscape conserving or physical-signal ports by handle.
pa = get_param([model '/' a],'PortHandles');
pb = get_param([model '/' b],'PortHandles');
add_line(model,pa.(aField)(aIndex),pb.(bField)(bIndex),'autorouting','on');
end

function addScope(model,label,nPorts,position)
add_block('simulink/Sinks/Scope',[model '/' label], ...
    'NumInputPorts',num2str(nPorts), ...
    'LayoutDimensionsString',sprintf('[%d 1]',nPorts), ...
    'OpenAtSimulationStart','off', ...
    'ShowLegend','on', ...
    'ShowGrid','on', ...
    'AxesScaling','Auto', ...
    'TimeSpan','auto', ...
    'Position',position);
end

function addNamedScopeLine(model,source,destination,signalName)
lineHandle = add_line(model,source,destination,'autorouting','on');
set_param(lineHandle,'Name',signalName);
end

function addLog(model,label,variable,source,position)
add_block('simulink/Sinks/To Workspace',[model '/' label], ...
    'VariableName',variable,'SaveFormat','Timeseries', ...
    'MaxDataPoints','inf','Position',position);
add_line(model,source,[label '/1'],'autorouting','on');
end

function addUserSettingsMask(model,P)
% Add a single user-facing block for all editable physical-model settings.
block = [model '/USER SETTINGS - DOUBLE CLICK'];
add_block('simulink/Ports & Subsystems/Subsystem',block, ...
    'Position',[20 180 205 260], ...
    'BackgroundColor','white','ForegroundColor','black', ...
    'FontWeight','bold','FontSize','12', ...
    'AttributesFormatString','Current/Voltage | SPDs | SC | Relay');
mask = Simulink.Mask.create(block);
mask.Type = 'PV Lightning Protection User Settings';
mask.Description = ['Change the lightning source, coordinated SPD values, ' ...
    'supercapacitor and relay thresholds here. Press Apply or OK, then Run.'];
mask.Initialization = '';
mask.Display = sprintf(['color(''black'');\n' ...
    'disp(''USER SETTINGS\\nDOUBLE-CLICK TO EDIT'');']);
mask.IconFrame = 'on';
mask.addDialogControl('Type','tabcontainer','Name','SettingsTabs');
addTab(mask,'LightningTab','Lightning input and cable');
addTab(mask,'SPD1Tab','SPD1 upstream');
addTab(mask,'SPD2Tab','SPD2 inverter-side');
addTab(mask,'SCTab','Supercapacitor');
addTab(mask,'RelayTab','Relay and thresholds');

mode = 'Current injection';
if P.lightning.mode == 2, mode = 'Voltage injection'; end
mask.addParameter('Type','popup','TypeOptions', ...
    {'Current injection','Voltage injection'},'Name','InjectionMode', ...
    'Prompt','Injection mode','Value',mode,'Evaluate','off', ...
    'Container','LightningTab','Callback',settingsCallback());
addEdit(mask,'LightningTab','PeakCurrent_A','Peak current (A)',P.lightning.peakCurrent_A);
addEdit(mask,'LightningTab','PeakVoltage_V','Peak voltage (V)',P.lightning.peakVoltage_V);
addEdit(mask,'LightningTab','EventTime_s','Event time (s)',P.lightning.eventTime_s);
addEdit(mask,'LightningTab','FrontTime_us','Front/peak time (us)',P.lightning.frontTime_s*1e6);
addEdit(mask,'LightningTab','HalfValueTime_us','Half-value time (us)',P.lightning.halfValueTime_s*1e6);
addEdit(mask,'LightningTab','WaveformStep_us','Command waveform step (us)',P.lightning.fastStep_s*1e6);
addEdit(mask,'LightningTab','ElectricalStep_us','Electrical solver step (us)',P.lightning.localSolverStep_s*1e6);
addEdit(mask,'LightningTab','VoltageSourceResistance_Ohm','Voltage-source resistance (ohm)',P.lightning.voltageSourceResistance_Ohm);
addEdit(mask,'LightningTab','SourceInductance_uH','Source inductance (uH)',P.lightning.sourceInductance_H*1e6);
addEdit(mask,'LightningTab','CableResistance_Ohm','Cable resistance (ohm)',P.cable.R_Ohm);
addEdit(mask,'LightningTab','CableInductance_uH','Cable inductance (uH)',P.cable.L_H*1e6);

addEdit(mask,'SPD1Tab','SPD1ClampVoltage_V','Clamp voltage (V)',P.spd1.lowerVoltage_V);
addEdit(mask,'SPD1Tab','SPD1DynamicResistance_Ohm','Dynamic resistance (ohm)',P.spd1.dynamicResistance_Ohm);
addEdit(mask,'SPD1Tab','SPD1LeakageResistance_Ohm','Off/leakage resistance (ohm)',P.spd1.leakageResistance_Ohm);
addEdit(mask,'SPD1Tab','SPD1LeadInductance_uH','Lead inductance (uH)',P.spd1.leadInductance_H*1e6);
addEdit(mask,'SPD1Tab','SPD1GroundResistance_Ohm','Ground resistance (ohm)',P.spd1.groundResistance_Ohm);
addEdit(mask,'SPD1Tab','SPD1GroundInductance_uH','Ground inductance (uH)',P.spd1.groundInductance_H*1e6);
addEdit(mask,'SPD1Tab','SPD1NominalCurrent_A','Nominal current (A)',P.spd1.nominalCurrent_A);
addEdit(mask,'SPD1Tab','SPD1MaximumCurrent_A','Maximum current (A)',P.spd1.maximumCurrent_A);
addEdit(mask,'SPD1Tab','SPD1EnergyRating_J','Energy rating (J)',P.spd1.energyRating_J);

addEdit(mask,'SPD2Tab','SPD2ClampVoltage_V','Clamp voltage (V)',P.spd2.lowerVoltage_V);
addEdit(mask,'SPD2Tab','SPD2DynamicResistance_Ohm','Dynamic resistance (ohm)',P.spd2.dynamicResistance_Ohm);
addEdit(mask,'SPD2Tab','SPD2LeakageResistance_Ohm','Off/leakage resistance (ohm)',P.spd2.leakageResistance_Ohm);
addEdit(mask,'SPD2Tab','SPD2LeadInductance_uH','Lead inductance (uH)',P.spd2.leadInductance_H*1e6);
addEdit(mask,'SPD2Tab','SPD2GroundResistance_Ohm','Ground resistance (ohm)',P.spd2.groundResistance_Ohm);
addEdit(mask,'SPD2Tab','SPD2GroundInductance_uH','Ground inductance (uH)',P.spd2.groundInductance_H*1e6);
addEdit(mask,'SPD2Tab','SPD2CoordinationResistance_Ohm','Output coordination resistance (ohm)',P.spd2.coordinationResistance_Ohm);
addEdit(mask,'SPD2Tab','SPD2CoordinationInductance_uH','Output coordination inductance (uH)',P.spd2.coordinationInductance_H*1e6);
addEdit(mask,'SPD2Tab','SPD2NominalCurrent_A','Nominal current (A)',P.spd2.nominalCurrent_A);
addEdit(mask,'SPD2Tab','SPD2MaximumCurrent_A','Maximum current (A)',P.spd2.maximumCurrent_A);
addEdit(mask,'SPD2Tab','SPD2EnergyRating_J','Energy rating (J)',P.spd2.energyRating_J);

addEdit(mask,'SCTab','SCCapacitance_F','Capacitance (F)',P.sc.capacitance_F);
addEdit(mask,'SCTab','SCInitialVoltage_V','Initial voltage (V)',P.sc.initialVoltage_V);
addEdit(mask,'SCTab','SCRatedVoltage_V','Rated voltage (V)',P.sc.ratedVoltage_V);
addEdit(mask,'SCTab','SCMinimumVoltage_V','Minimum voltage (V)',P.sc.minimumVoltage_V);
addEdit(mask,'SCTab','SCMaximumCurrent_A','Maximum current (A)',P.sc.maximumCurrent_A);
addEdit(mask,'SCTab','SCESR_Ohm','ESR (ohm)',P.sc.ESR_Ohm);
addEdit(mask,'SCTab','SCConverterInductance_mH','Converter inductance (mH)',P.sc.converterInductance_H*1e3);
addEdit(mask,'SCTab','SCConverterResistance_Ohm','Converter path resistance (ohm)',P.sc.converterPathResistance_Ohm);

addEdit(mask,'RelayTab','WarningVoltage_V','Warning voltage (V)',P.threshold.warningVoltage_V);
addEdit(mask,'RelayTab','EmergencyTripVoltage_V','Emergency trip voltage (V)',P.threshold.emergencyTripVoltage_V);
addEdit(mask,'RelayTab','SafeRecoveryUpperVoltage_V','Safe recovery upper voltage (V)',P.threshold.safeRecoveryUpperVoltage_V);
addEdit(mask,'RelayTab','SafeRecoveryLowerVoltage_V','Safe recovery lower voltage (V)',P.threshold.safeRecoveryLowerVoltage_V);
addEdit(mask,'RelayTab','WarningDuration_ms','Warning duration (ms)',P.threshold.warningDuration_s*1e3);
addEdit(mask,'RelayTab','OpeningDelay_ms','Physical opening delay (ms)',P.threshold.relayOpeningDelay_s*1e3);
addEdit(mask,'RelayTab','RecoveryDelay_ms','Safe recovery delay (ms)',P.threshold.safeRecoveryDelay_s*1e3);
addEdit(mask,'RelayTab','ClosingDelay_ms','Physical closing delay (ms)',P.threshold.relayClosingDelay_s*1e3);
end

function addTab(mask,name,prompt)
mask.addDialogControl('Type','tab','Name',name,'Prompt',prompt, ...
    'Container','SettingsTabs');
end

function addEdit(mask,container,name,prompt,value)
mask.addParameter('Type','edit','Name',name,'Prompt',prompt, ...
    'Value',sprintf('%.15g',value),'Evaluate','off','Container',container, ...
    'Callback',settingsCallback());
end

function callback = settingsCallback()
callback = [ ...
    'addpath(genpath(fileparts(fileparts(' ...
    'get_param(bdroot(gcb),''FileName''))))); ' ...
    'apply_simscape_settings_mask(gcb);'];
end
