function relay_contactor_sfunc(block)
%RELAY_CONTACTOR_SFUNC Delayed physical relay state and transition times.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=1; block.InputPort(1).DirectFeedthrough=false;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=3; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
names={'state','target','timer','openTime','closeTime'}; block.NumDworks=5;
for k=1:5, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block), init=[1 1 0 NaN NaN]; for k=1:5, block.Dwork(k).Data=init(k); end, end
function outputs(block), block.OutputPort(1).Data=[block.Dwork(1).Data;block.Dwork(4).Data;block.Dwork(5).Data]; end
function update(block)
P=block.DialogPrm(1).Data; command=block.InputPort(1).Data>0.5; state=block.Dwork(1).Data>0.5; target=block.Dwork(2).Data>0.5; timer=block.Dwork(3).Data;
if command~=target, target=command; timer=0; else, timer=timer+P.sim.Ts; end
if state~=target
 delay=P.relay.closingDelay_s; if ~target, delay=P.relay.openingDelay_s; end
 if timer>=delay
  state=target; timer=0; if state, block.Dwork(5).Data=block.CurrentTime; else, block.Dwork(4).Data=block.CurrentTime; end
 end
end
block.Dwork(1).Data=double(state); block.Dwork(2).Data=double(target); block.Dwork(3).Data=timer;
end
