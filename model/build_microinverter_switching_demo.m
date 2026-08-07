function modelPath = build_microinverter_switching_demo(P)
%BUILD_MICROINVERTER_SWITCHING_DEMO Real PWM H-bridge and LC-load model.
root=fileparts(fileparts(mfilename('fullpath'))); name='Microinverter_Switching_Demo'; modelPath=fullfile(root,'model',[name '.slx']);
if bdIsLoaded(name), close_system(name,0); end
if isfile(modelPath), delete(modelPath); end
new_system(name); open_system(name); dt=P.inverter.demoStep_s;
set_param(name,'Solver','FixedStepDiscrete','FixedStep',num2str(dt,16),'StopTime','0.12','ReturnWorkspaceOutputs','on','SaveTime','on','TimeSaveName','tout');
m=P.inverter.demoRMSVoltage_V*sqrt(2)/P.inverter.demoDCVoltage_V;
add_block('simulink/Sources/Sine Wave',[name '/50 Hz Reference'],'Amplitude',num2str(m),'Frequency',num2str(2*pi*P.inverter.demoFrequency_Hz),'SampleTime',num2str(dt),'Position',[30 40 120 70]);
add_block('simulink/Sources/Repeating Sequence',[name '/10 kHz Triangle Carrier'],'rep_seq_t',mat2str([0 0.5/P.inverter.demoSwitchingFrequency_Hz 1/P.inverter.demoSwitchingFrequency_Hz]),'rep_seq_y',mat2str([-1 1 -1]),'Position',[30 125 140 160]);
add_block('simulink/Logic and Bit Operations/Relational Operator',[name '/Gate A'],'Operator','>=','Position',[200 40 240 70]);
add_block('simulink/Math Operations/Gain',[name '/Negative Reference'],'Gain','-1','Position',[145 85 180 115]);
add_block('simulink/Logic and Bit Operations/Relational Operator',[name '/Gate B'],'Operator','>=','Position',[200 90 240 120]);
add_block('simulink/Signal Attributes/Data Type Conversion',[name '/Gate A Double'],'OutDataTypeStr','double','Position',[250 35 280 65]);
add_block('simulink/Signal Attributes/Data Type Conversion',[name '/Gate B Double'],'OutDataTypeStr','double','Position',[250 95 280 125]);
add_block('simulink/Math Operations/Sum',[name '/H Bridge Pole Difference'],'Inputs','+-','Position',[285 55 315 105]);
add_block('simulink/Math Operations/Gain',[name '/DC Bus Voltage'],'Gain',num2str(P.inverter.demoDCVoltage_V),'Position',[350 65 420 95]);
add_block('simulink/Sources/Step',[name '/Relay Shutdown'],'Time','0.08','Before','1','After','0','SampleTime',num2str(dt),'Position',[350 130 420 160]);
add_block('simulink/Math Operations/Product',[name '/Relay Controlled Bridge'],'Position',[465 70 505 110]);
L=P.inverter.demoL_H; C=P.inverter.demoC_F; R=P.inverter.demoLoadResistance_Ohm; rL=P.inverter.demoInductorResistance_Ohm;
A=[-rL/L -1/L;1/C -1/(R*C)]; B=[1/L;0]; Cmat=[0 1;0 1/R;1 0]; D=zeros(3,1);
M=expm([A B;zeros(1,3)]*dt); Ad=M(1:2,1:2); Bd=M(1:2,3);
add_block('simulink/Discrete/Discrete State-Space',[name '/LC Filter and AC Load'],'A',mat2str(Ad,16),'B',mat2str(Bd,16),'C',mat2str(Cmat,16),'D',mat2str(D,16),'SampleTime',num2str(dt),'InitialCondition','[0;0]','Position',[555 55 690 125]);
add_block('simulink/Signal Routing/Demux',[name '/Filter Measurements'],'Outputs','3','Position',[735 45 740 140]);
add_block('simulink/Math Operations/Product',[name '/AC Output Power'],'Position',[800 65 840 100]);
add_block('simulink/Math Operations/Product',[name '/DC Input Power'],'Position',[800 145 840 180]);
add_line(name,'50 Hz Reference/1','Gate A/1'); add_line(name,'10 kHz Triangle Carrier/1','Gate A/2');
add_line(name,'50 Hz Reference/1','Negative Reference/1'); add_line(name,'Negative Reference/1','Gate B/1'); add_line(name,'10 kHz Triangle Carrier/1','Gate B/2');
add_line(name,'Gate A/1','Gate A Double/1'); add_line(name,'Gate B/1','Gate B Double/1'); add_line(name,'Gate A Double/1','H Bridge Pole Difference/1'); add_line(name,'Gate B Double/1','H Bridge Pole Difference/2'); add_line(name,'H Bridge Pole Difference/1','DC Bus Voltage/1');
add_line(name,'DC Bus Voltage/1','Relay Controlled Bridge/1'); add_line(name,'Relay Shutdown/1','Relay Controlled Bridge/2'); add_line(name,'Relay Controlled Bridge/1','LC Filter and AC Load/1');
add_line(name,'LC Filter and AC Load/1','Filter Measurements/1'); add_line(name,'Filter Measurements/1','AC Output Power/1'); add_line(name,'Filter Measurements/2','AC Output Power/2');
add_line(name,'Relay Controlled Bridge/1','DC Input Power/1'); add_line(name,'Filter Measurements/3','DC Input Power/2');
logs={{'bridge_voltage','Relay Controlled Bridge/1'},{'inverter_output_voltage','Filter Measurements/1'},{'inverter_output_current','Filter Measurements/2'},{'inverter_inductor_current','Filter Measurements/3'},{'inverter_ac_power','AC Output Power/1'},{'inverter_dc_power','DC Input Power/1'},{'inverter_relay_state','Relay Shutdown/1'}};
for k=1:numel(logs), item=logs{k}; add_block('simulink/Sinks/To Workspace',[name '/' item{1}],'VariableName',item{1},'SaveFormat','Timeseries','Position',[920 15+45*k 1060 32+45*k]); add_line(name,item{2},[item{1} '/1']); end
set_param(name,'Description','24 V RMS, 50 Hz, PWM H-bridge laboratory demonstration; not grid compliance.'); save_system(name,modelPath); close_system(name,0);
end
