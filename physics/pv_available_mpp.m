function [power_W,voltage_V,current_A] = pv_available_mpp(irradiance_W_m2,temperature_C,P)
%PV_AVAILABLE_MPP Numerically maximize the plant's unified PV equation.
persistent cacheKey cacheValue
key=[round(double(irradiance_W_m2),6) round(double(temperature_C),6) P.pv.Rs_Ohm P.pv.Rsh_Ohm];
if isempty(cacheKey) || ~isequal(key,cacheKey)
 objective=@(v)-v.*pv_current_single_diode(v,irradiance_W_m2,temperature_C,P);
 upper=max(0.1,P.pv.Voc_V+P.pv.betaV_V_per_C*(temperature_C-P.pv.Tnom_C));
 voltage_V=fminbnd(objective,0,upper,optimset('TolX',1e-7,'Display','off'));
 current_A=pv_current_single_diode(voltage_V,irradiance_W_m2,temperature_C,P); power_W=voltage_V*current_A;
 cacheKey=key; cacheValue=[power_W voltage_V current_A];
else
 power_W=cacheValue(1); voltage_V=cacheValue(2); current_A=cacheValue(3);
end
end
