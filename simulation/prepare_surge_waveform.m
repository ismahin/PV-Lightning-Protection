function y = prepare_surge_waveform(t,scenario,P)
%PREPARE_SURGE_WAVEFORM Normalized double exponential or sustained lab disturbance.
y=zeros(size(t)); start=scenario.Surge_Start_Time;
switch lower(char(scenario.Surge_Type))
 case 'disabled'
 case 'ripple'
  active=t>=start & t<start+scenario.Surge_Duration;
  y(active)=P.bus.nominalVoltage_V*(1+scenario.Surge_Peak.*sin(pi*(t(active)-start)/scenario.Surge_Duration).^2);
 case 'sustained'
  active=t>=start & t<start+scenario.Surge_Duration;
  edge=min(0.005,scenario.Surge_Duration/5); q=t(active)-start;
  shape=min(1,q/edge).*min(1,(scenario.Surge_Duration-q)/edge);
  y(active)=P.bus.nominalVoltage_V*(1+scenario.Surge_Peak.*shape);
 case 'impulse'
  alpha=1/P.surge.defaultDecay_s; beta=1/P.surge.defaultRise_s;
  tp=log(beta/alpha)/(beta-alpha); normFactor=exp(-alpha*tp)-exp(-beta*tp);
  count=max(1,scenario.Pulse_Count);
  for k=1:count
   tk=start+(k-1)*0.085; q=t-tk; active=q>=0;
   pulse=zeros(size(t)); pulse(active)=scenario.Surge_Peak*(exp(-alpha*q(active))-exp(-beta*q(active)))/normFactor;
   y=y+pulse;
  end
 otherwise, error('Unknown surge type: %s',scenario.Surge_Type);
end
end
