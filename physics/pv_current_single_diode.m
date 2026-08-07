function current_A = pv_current_single_diode(voltage_V,irradiance_W_m2,temperature_C,P)
%PV_CURRENT_SINGLE_DIODE Unified implicit single-diode PV current solver.
voltage_V=double(voltage_V); irradiance_W_m2=max(0,double(irradiance_W_m2)); temperature_C=double(temperature_C);
sz=size(voltage_V); voltage_V=voltage_V(:);
if isscalar(irradiance_W_m2), irradiance_W_m2=repmat(irradiance_W_m2,size(voltage_V)); else, irradiance_W_m2=irradiance_W_m2(:); end
if isscalar(temperature_C), temperature_C=repmat(temperature_C,size(voltage_V)); else, temperature_C=temperature_C(:); end
kB=1.380649e-23; q=1.602176634e-19; Vt0=kB*(P.pv.Tnom_C+273.15)/q;
i0nom=P.pv.Isc_A/(exp(P.pv.Voc_V/(P.pv.diodeIdeality*P.pv.cellsSeries*Vt0))-1);
current_A=max(0,P.pv.Isc_A.*(irradiance_W_m2/P.pv.Gnom_W_m2).*(1+P.pv.alphaI_A_per_C/P.pv.Isc_A.*(temperature_C-P.pv.Tnom_C)));
for iteration=1:8
 vt=kB*(temperature_C+273.15)/q; a=P.pv.diodeIdeality*P.pv.cellsSeries.*vt;
 i0=i0nom.*((temperature_C+273.15)/(P.pv.Tnom_C+273.15)).^3;
 exponent=min(80,(voltage_V+current_A*P.pv.Rs_Ohm)./max(a,eps)); e=exp(exponent);
 iph=P.pv.Isc_A.*(irradiance_W_m2/P.pv.Gnom_W_m2).*(1+P.pv.alphaI_A_per_C/P.pv.Isc_A.*(temperature_C-P.pv.Tnom_C));
 residual=current_A-iph+i0.*(e-1)+(voltage_V+current_A*P.pv.Rs_Ohm)/P.pv.Rsh_Ohm;
 derivative=1+i0.*e*P.pv.Rs_Ohm./max(a,eps)+P.pv.Rs_Ohm/P.pv.Rsh_Ohm;
 current_A=max(0,current_A-residual./derivative);
end
current_A=reshape(current_A,sz);
end
