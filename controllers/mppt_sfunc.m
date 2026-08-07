function mppt_sfunc(block)
%MPPT_SFUNC Stateful bounded perturb-and-observe controller.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data;
block.NumInputPorts=1; block.InputPort(1).Dimensions=2; block.InputPort(1).DirectFeedthrough=false;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=1; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
names={'duty','prevV','prevP','clock'}; block.NumDworks=4;
for k=1:4, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block)
P=block.DialogPrm(1).Data; block.Dwork(1).Data=P.mppt.initialDuty; block.Dwork(2).Data=P.pv.Vmp_V; block.Dwork(3).Data=P.pv.Vmp_V*P.pv.Imp_A; block.Dwork(4).Data=0;
end
function outputs(block), block.OutputPort(1).Data=block.Dwork(1).Data; end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; clock=block.Dwork(4).Data+P.sim.Ts;
if clock>=P.mppt.sampleTime_s
 block.Dwork(1).Data=mppt_po_controller(u(1),u(2),block.Dwork(2).Data,block.Dwork(3).Data,block.Dwork(1).Data,P);
 block.Dwork(2).Data=u(1); block.Dwork(3).Data=u(1)*u(2); clock=0;
end
block.Dwork(4).Data=clock;
end
