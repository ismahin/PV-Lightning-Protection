function voltage_V = mov_voltage_for_current(current_A,P)
%MOV_VOLTAGE_FOR_CURRENT Inverse of the shared nonlinear MOV equation.
current_A=max(current_A,P.spd.leakage_A);
voltage_V=P.spd.kneeVoltage_V+P.spd.dynamicResistance_Ohm* ...
 max(current_A-P.spd.leakage_A,0).^(1/P.spd.exponent);
voltage_V(current_A<=P.spd.leakage_A)=P.spd.MCOV_V;
end
