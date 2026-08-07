function cable_source_sfunc(block)
%CABLE_SOURCE_SFUNC Surge-source, cable resistance and inductance.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=2; block.InputPort(1).DirectFeedthrough=false;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=1; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block), block.NumDworks=1; block.Dwork(1).Name='iSurge'; block.Dwork(1).Dimensions=1; block.Dwork(1).DatatypeID=0; block.Dwork(1).Complexity='Real'; block.Dwork(1).UsedAsDiscState=true; end
function initialize(block), block.Dwork(1).Data=0; end
function outputs(block), block.OutputPort(1).Data=block.Dwork(1).Data; end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; r=P.surge.sourceResistance_Ohm+P.cable.R_Ohm; tau=(P.surge.sourceInductance_H+P.cable.L_H)/r;
target=max(0,(u(1)-u(2))/r); block.Dwork(1).Data=max(0,target+(block.Dwork(1).Data-target)*exp(-P.sim.Ts/tau));
end
