function scenario_input = configure_scenario(scenario,P,dt)
%CONFIGURE_SCENARIO Create deterministic time/value profile for Simulink.
if nargin<3, dt=P.sim.Ts; end
t=(0:dt:scenario.StopTime)'; n=numel(t);
G=P.pv.Gnom_W_m2*ones(n,1); T=P.pv.Tnom_C*ones(n,1);
if scenario.Irradiance_Profile=="step", G(t>=0.55)=650; G(t>=1.05)=900; end
surge=prepare_surge_waveform(t,scenario,P);
manual=zeros(n,1); if isfinite(scenario.ManualResetTime), manual(t>=scenario.ManualResetTime & t<scenario.ManualResetTime+0.04)=1; end
auto=double(scenario.AutoReset)*ones(n,1); mode=scenario.Protection_Mode*ones(n,1);
rng(P.sim.randomSeed+sum(double(char(scenario.Test_ID))),'twister'); noise=scenario.NoiseStd_V*randn(n,1);
loadScale=ones(n,1); detailed=double(scenario.Test_ID=="T14")*ones(n,1);
scenario_input=[t G T surge manual auto mode noise loadScale detailed];
end
