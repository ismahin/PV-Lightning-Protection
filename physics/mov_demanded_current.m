function demand_A = mov_demanded_current(voltage_V,P)
%MOV_DEMANDED_CURRENT Shared nonlinear MOV V-I characteristic.
demand_A=P.spd.leakage_A*ones(size(voltage_V));
active=voltage_V>P.spd.MCOV_V;
excess=max(0,voltage_V(active)-P.spd.kneeVoltage_V);
demand_A(active)=P.spd.leakage_A+(excess/max(P.spd.dynamicResistance_Ohm,eps)).^P.spd.exponent;
demand_A=max(0,min(demand_A,1e9));
end
