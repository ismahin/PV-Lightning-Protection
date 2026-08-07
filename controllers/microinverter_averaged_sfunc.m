function microinverter_averaged_sfunc(block)
%MICROINVERTER_AVERAGED_SFUNC Power-based protected DC input model.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=3; block.InputPort(1).DirectFeedthrough=true;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=7; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block), block.NumDworks=1; block.Dwork(1).Name='softStart'; block.Dwork(1).Dimensions=1; block.Dwork(1).DatatypeID=0; block.Dwork(1).Complexity='Real'; block.Dwork(1).UsedAsDiscState=true; end
function initialize(block), block.Dwork(1).Data=0; end
function outputs(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; v=u(1); relay=u(2)>0.5; uvlo=v<P.load.undervoltageLockout_V; ov=v>P.load.overvoltageShutdown_V;
enabled=relay && ~uvlo && ~ov; requested=P.load.requestedACPower_W*block.Dwork(1).Data*double(enabled);
i=min(P.load.inputCurrentLimit_A,requested/max(P.load.inverterEfficiency*v,1)); dcP=v*i; acP=P.load.inverterEfficiency*dcP;
block.OutputPort(1).Data=[i;acP;requested;double(uvlo);double(ov);block.Dwork(1).Data;dcP];
end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; enabled=u(2)>0.5 && u(1)>=P.load.undervoltageLockout_V && u(1)<=P.load.overvoltageShutdown_V;
soft=block.Dwork(1).Data; if enabled, soft=min(1,soft+P.sim.Ts/P.load.softStart_s); else, soft=0; end; block.Dwork(1).Data=soft;
end
