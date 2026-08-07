function dc_bus_sfunc(block)
%DC_BUS_SFUNC Protected bus capacitor energy-balance state.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=5; block.InputPort(1).DirectFeedthrough=false;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=2; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
block.NumDworks=2; names={'vBus','iBus'};
for k=1:2, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block), P=block.DialogPrm(1).Data; block.Dwork(1).Data=P.bus.prechargeVoltage_V; block.Dwork(2).Data=0; end
function outputs(block), block.OutputPort(1).Data=[block.Dwork(1).Data;block.Dwork(2).Data]; end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; iBus=u(1)+u(2)-u(3)-u(4)-u(5); v=block.Dwork(1).Data+P.sim.Ts*iBus/P.boost.Cout_F;
block.Dwork(1).Data=max(0,min(1200,v)); block.Dwork(2).Data=iBus;
end
