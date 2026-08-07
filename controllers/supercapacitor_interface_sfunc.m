function supercapacitor_interface_sfunc(block)
%SUPERCAPACITOR_INTERFACE_SFUNC ESR and converter-current dynamics.
setup(block);
end
function setup(block)
block.NumDialogPrms=1; P=block.DialogPrm(1).Data; block.NumInputPorts=1; block.InputPort(1).Dimensions=2; block.InputPort(1).DirectFeedthrough=true;
block.NumOutputPorts=1; block.OutputPort(1).Dimensions=14; block.SampleTimes=[P.sim.Ts 0];
block.RegBlockMethod('PostPropagationSetup',@postSetup); block.RegBlockMethod('InitializeConditions',@initialize); block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function postSetup(block)
names={'internalV','actualCurrent','esrEnergy','limitDuration'}; block.NumDworks=4;
for k=1:4, block.Dwork(k).Name=names{k}; block.Dwork(k).Dimensions=1; block.Dwork(k).DatatypeID=0; block.Dwork(k).Complexity='Real'; block.Dwork(k).UsedAsDiscState=true; end
end
function initialize(block), P=block.DialogPrm(1).Data; block.Dwork(1).Data=P.sc.initialVoltage_V; block.Dwork(2).Data=0; block.Dwork(3).Data=0; block.Dwork(4).Data=0; end
function outputs(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; vi=block.Dwork(1).Data; actual=block.Dwork(2).Data;
[raw,cmd,enabled,limited,overvoltage,undervoltage]=command(u(1),vi,round(u(2)),P); vt=vi+actual*P.sc.ESR_Ohm; esrV=actual*P.sc.ESR_Ohm; esrP=actual^2*P.sc.ESR_Ohm;
if actual>=0, busCurrent=actual*max(vt,1)/(max(u(1),1)*P.sc.converterEfficiency); else, busCurrent=actual*max(vt,1)*P.sc.converterEfficiency/max(u(1),1); end
block.OutputPort(1).Data=[vi;vt;raw;cmd;actual;busCurrent;esrV;esrP;block.Dwork(3).Data; ...
 double(enabled);double(limited);block.Dwork(4).Data;double(overvoltage);double(undervoltage)];
end
function update(block)
P=block.DialogPrm(1).Data; u=block.InputPort(1).Data; vi=block.Dwork(1).Data; current=block.Dwork(2).Data;
[~,cmd,~,limited]=command(u(1),vi,round(u(2)),P);
di=(P.sc.currentControllerGain_Ohm*(cmd-current)-P.sc.converterPathResistance_Ohm*current)/P.sc.converterInductance_H;
current=current+P.sim.Ts*di; current=max(-P.sc.maximumCurrent_A,min(P.sc.maximumCurrent_A,current));
vi=vi+P.sim.Ts*(current-vi/P.sc.leakageResistance_Ohm)/P.sc.capacitance_F;
vi=max(0,min(P.sc.ratedVoltage_V,vi)); block.Dwork(1).Data=vi; block.Dwork(2).Data=current;
block.Dwork(3).Data=block.Dwork(3).Data+P.sim.Ts*(current^2*P.sc.ESR_Ohm);
block.Dwork(4).Data=block.Dwork(4).Data+P.sim.Ts*double(limited);
end
function [raw,cmd,enabled,limited,overvoltage,undervoltage]=command(vBus,vInternal,mode,P)
overvoltage=vInternal>=P.sc.ratedVoltage_V; undervoltage=vInternal<=P.sc.minimumVoltage_V;
enabled=mode==3 && ~overvoltage && ~undervoltage;
err=vBus-P.bus.nominalVoltage_V; raw=0;
if enabled && abs(err)>=P.sc.deadband_V, raw=P.sc.converterKp_A_per_V*err; end
if vInternal>=P.sc.ratedVoltage_V && raw>0, raw=0; end
if vInternal<=P.sc.minimumVoltage_V && raw<0, raw=0; end
limited=abs(raw)>P.sc.maximumCurrent_A; cmd=max(-P.sc.maximumCurrent_A,min(P.sc.maximumCurrent_A,raw));
end
