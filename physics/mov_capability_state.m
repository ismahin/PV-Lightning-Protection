function [state,currentExceeded,energyExceeded] = mov_capability_state(demand_A,energy_J,P)
%MOV_CAPABILITY_STATE Return 0 SAFE, 1 current, 2 current/energy, 3 failed.
currentExceeded=any(demand_A>P.spd.maxCurrent_A);
energyExceeded=energy_J>P.spd.energyRating_J;
state=double(currentExceeded)+double(energyExceeded);
if P.spd.failureEnabled && state>0, state=3; end
end
