function protection_controller_sfunc(block)
%PROTECTION_CONTROLLER_SFUNC Qualified arming, protection and recovery log.
setup(block);
end

function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data;
block.NumInputPorts=1; block.InputPort(1).Dimensions=5; block.InputPort(1).DirectFeedthrough=true;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=13; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize);
block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end

function postSetup(block)
names={'state','tOver','tSafe','relayCommand','thresholdTime','tripTime', ...
 'safeIntervalStart','reconnectTime','previousWarning','armed','armStable','safeInterruptions','previousState'};
block.NumDworks=numel(names);
for k=1:numel(names)
 block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0;
 block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true;
end
end

function initialize(block)
init=[1 0 0 1 NaN NaN NaN NaN 0 0 0 0 1];
for k=1:numel(init), block.Dwork(k).Data=init(k); end
end

function outputs(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; sensed=u(1)+u(5);
armed=block.Dwork(10).Data>0.5;
warning=armed && sensed>P.controller.warning_pu*P.bus.nominalVoltage_V;
emergency=armed && sensed>P.controller.emergency_pu*P.bus.nominalVoltage_V;
block.OutputPort(1).Data=[block.Dwork(4).Data;block.Dwork(1).Data;block.Dwork(2).Data; ...
 double(warning);double(emergency);block.Dwork(5).Data;block.Dwork(6).Data; ...
 block.Dwork(7).Data;block.Dwork(8).Data;double(u(3)>0.5);double(u(2)>0.5); ...
 double(armed);block.Dwork(12).Data];
end

function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; v=u(1)+u(5);
manual=u(2)>0.5; autoReset=u(3)>0.5; mode=round(u(4));
state=block.Dwork(1).Data; previousState=block.Dwork(13).Data;
tOver=block.Dwork(2).Data; tSafe=block.Dwork(3).Data; oldCommand=block.Dwork(4).Data;
armed=block.Dwork(10).Data>0.5; armStable=block.Dwork(11).Data;
healthy=v>=P.protection.armVoltageLower_pu*P.bus.nominalVoltage_V && ...
 v<=P.protection.armVoltageUpper_pu*P.bus.nominalVoltage_V;
if ~armed
 if block.CurrentTime>=P.protection.startupBlanking_s && healthy
  armStable=armStable+P.sim.Ts;
 else
  armStable=0;
 end
 if armStable>=P.protection.armStableDuration_s, armed=true; end
end
warning=armed && v>P.controller.warning_pu*P.bus.nominalVoltage_V;
if warning && ~logical(block.Dwork(9).Data), block.Dwork(5).Data=block.CurrentTime; end
if ~armed
 command=true; state=1; tOver=0; tSafe=0;
elseif mode==3
 [state,command,tOver,tSafe]=protection_logic(v,state,tOver,tSafe,manual,autoReset,P,P.sim.Ts);
elseif mode==2
 % Conventional relay: startup-qualified, then immediate fixed threshold.
 command=~warning; if command, state=1; else, state=4; end; tOver=0; tSafe=0;
else
 command=true; state=1; tOver=0; tSafe=0;
end
if oldCommand>0.5 && ~command, block.Dwork(6).Data=block.CurrentTime; end
if state==5 && previousState~=5
 block.Dwork(7).Data=block.CurrentTime;
elseif state==4 && previousState==5 && oldCommand<0.5
 block.Dwork(12).Data=block.Dwork(12).Data+1;
 block.Dwork(7).Data=NaN;
end
if oldCommand<0.5 && command, block.Dwork(8).Data=block.CurrentTime; end
block.Dwork(1).Data=state; block.Dwork(2).Data=tOver; block.Dwork(3).Data=tSafe;
block.Dwork(4).Data=double(command); block.Dwork(9).Data=double(warning);
block.Dwork(10).Data=double(armed); block.Dwork(11).Data=armStable; block.Dwork(13).Data=state;
end
