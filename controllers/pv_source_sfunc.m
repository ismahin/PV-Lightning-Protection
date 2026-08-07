function pv_source_sfunc(block)
%PV_SOURCE_SFUNC Unified single-diode source plus input-capacitor state.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data;
block.NumInputPorts=1; block.InputPort(1).Dimensions=3; block.InputPort(1).DirectFeedthrough=false;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=4; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
names={'vPV','irradiance','temperature'}; block.NumDworks=3;
for k=1:3, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block), P=block.DialogPrm(1).Data; block.Dwork(1).Data=P.pv.Vmp_V; block.Dwork(2).Data=P.pv.Gnom_W_m2; block.Dwork(3).Data=P.pv.Tnom_C; end
function outputs(block)
P=block.DialogPrm(1).Data; v=block.Dwork(1).Data; G=block.Dwork(2).Data; T=block.Dwork(3).Data;
i=pv_current_single_diode(v,G,T,P); p=v*i; pMpp=pv_available_mpp(G,T,P);
block.OutputPort(1).Data=[v;i;p;pMpp];
end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; v=block.Dwork(1).Data;
i=pv_current_single_diode(v,u(1),u(2),P); v=v+P.sim.Ts*(i-u(3))/P.boost.Cin_F;
block.Dwork(1).Data=max(0,min(1.2*P.pv.Voc_V,v));
block.Dwork(2).Data=u(1); block.Dwork(3).Data=u(2);
end
