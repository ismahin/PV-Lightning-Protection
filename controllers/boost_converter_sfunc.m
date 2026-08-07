function boost_converter_sfunc(block)
%BOOST_CONVERTER_SFUNC Averaged boost inductor and output-current model.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=3; block.InputPort(1).DirectFeedthrough=true;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=2; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block), block.NumDworks=1; block.Dwork(1).Name='iL'; block.Dwork(1).Dimensions=1; block.Dwork(1).DatatypeID=0; block.Dwork(1).Complexity='Real'; block.Dwork(1).UsedAsDiscState=true; end
function initialize(block), block.Dwork(1).Data=4; end
function outputs(block), P=block.DialogPrm(1).Data; d=block.InputPort(1).Data(3); iL=block.Dwork(1).Data; block.OutputPort(1).Data=[iL;max(0,(1-d)*iL*P.boost.efficiency)]; end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; iL=block.Dwork(1).Data;
iL=iL+P.sim.Ts*(u(1)-(1-u(3))*u(2)-P.boost.RL_Ohm*iL)/P.boost.L_H; block.Dwork(1).Data=max(0,iL);
end
