function profile = prepare_indirect_lightning_profile(P)
%PREPARE_INDIRECT_LIGHTNING_PROFILE Dense normalized 8/20 us profile.
% The waveform reaches its peak at frontTime_s and reaches 50 percent of
% peak at halfValueTime_s. Dense time hits are limited to the event window.

q = (0:P.lightning.fastStep_s:P.lightning.recordDuration_s)';
shape = zeros(size(q));
rise = q <= P.lightning.frontTime_s;
shape(rise) = sin(0.5*pi*q(rise)/P.lightning.frontTime_s).^2;
decayTimeConstant = (P.lightning.halfValueTime_s- ...
    P.lightning.frontTime_s)/log(2);
shape(~rise) = exp(-(q(~rise)-P.lightning.frontTime_s)/decayTimeConstant);

eventTime = P.lightning.eventTime_s;
preTime = max(0,eventTime-P.sim.Ts);
postTime = min(P.sim.stopTime,eventTime+P.lightning.recordDuration_s+P.sim.Ts);
t = [0; preTime; eventTime+q; postTime; P.sim.stopTime];
y = [0; 0; shape; 0; 0];
[t,uniqueIndex] = unique(t,'stable');
y = y(uniqueIndex);
profile = [t y];
end
