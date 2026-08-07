function spd_mov_sfunc(block)
%SPD_MOV_SFUNC Nonlinear MOV demand, finite capability and overstress state.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=2; block.InputPort(1).DirectFeedthrough=true;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=7; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
names={'actualCurrent','energy','satDuration','state'}; block.NumDworks=4;
for k=1:4, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block), for k=1:4, block.Dwork(k).Data=0; end, end
function outputs(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; enabled=round(u(2))>=1; demand=mov_demanded_current(u(1),P)*enabled;
[actual,saturation]=mov_actual_current(demand,block.Dwork(1).Data,P,P.sim.Ts); energy=block.Dwork(2).Data; state=max(block.Dwork(4).Data,mov_capability_state(demand,energy,P));
block.OutputPort(1).Data=[demand;actual;double(saturation);block.Dwork(3).Data;energy;state;u(1)];
end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; enabled=round(u(2))>=1; demand=mov_demanded_current(u(1),P)*enabled;
[actual,saturated]=mov_actual_current(demand,block.Dwork(1).Data,P,P.sim.Ts);
energy=mov_energy_update(block.Dwork(2).Data,u(1),actual,P.sim.Ts); sat=block.Dwork(3).Data+P.sim.Ts*double(saturated);
state=max(block.Dwork(4).Data,mov_capability_state(demand,energy,P));
if P.spd.failureEnabled && state>=2, actual=P.spd.leakage_A; state=3; end
block.Dwork(1).Data=max(0,actual); block.Dwork(2).Data=energy; block.Dwork(3).Data=sat; block.Dwork(4).Data=state;
end
