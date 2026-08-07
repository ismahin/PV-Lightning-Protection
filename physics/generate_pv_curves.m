function curves = generate_pv_curves(P)
%GENERATE_PV_CURVES Multi-condition curves from the unified equation.
conditions=[1000 25;650 25;1000 45]; template=struct('irradiance_W_m2',0,'temperature_C',0,'voltage_V',[],'current_A',[],'power_W',[],'Pmp_W',0,'Vmp_V',0,'Imp_A',0); curves=repmat(template,size(conditions,1),1);
for k=1:size(conditions,1)
 G=conditions(k,1); T=conditions(k,2); voc=max(0.1,P.pv.Voc_V+P.pv.betaV_V_per_C*(T-P.pv.Tnom_C));
 v=linspace(0,1.04*voc,500)'; i=pv_current_single_diode(v,G,T,P); [pmp,vmp,imp]=pv_available_mpp(G,T,P);
 curves(k)=struct('irradiance_W_m2',G,'temperature_C',T,'voltage_V',v,'current_A',i,'power_W',v.*i,'Pmp_W',pmp,'Vmp_V',vmp,'Imp_A',imp);
end
end
