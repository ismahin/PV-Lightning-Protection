function [actual_A,saturated] = mov_actual_current(demand_A,previous_A,P,dt)
%MOV_ACTUAL_CURRENT Shared finite-capability and branch-dynamics update.
target=min(max(demand_A,0),P.spd.maxCurrent_A);
tau=(P.spd.leadInductance_H+P.spd.groundInductance_H)/ ...
 max(P.spd.seriesResistance_Ohm+P.spd.groundResistance_Ohm,eps);
actual_A=target+(previous_A-target).*exp(-dt/max(tau,eps));
actual_A=max(0,min(actual_A,P.spd.maxCurrent_A));
saturated=demand_A>P.spd.maxCurrent_A;
end
