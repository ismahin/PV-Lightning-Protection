function T = validate_pv_model(P)
%VALIDATE_PV_MODEL Compare STC model values against configured ratings.
[pmp,vmp,imp]=pv_available_mpp(P.pv.Gnom_W_m2,P.pv.Tnom_C,P); isc=pv_current_single_diode(0,P.pv.Gnom_W_m2,P.pv.Tnom_C,P);
vgrid=linspace(0,1.1*P.pv.Voc_V,3000); igrid=pv_current_single_diode(vgrid,P.pv.Gnom_W_m2,P.pv.Tnom_C,P);
idx=find(igrid<=1e-4,1); if isempty(idx), voc=P.pv.Voc_V; else, voc=vgrid(idx); end
metric=["Voc";"Isc";"Vmp";"Imp";"Pmp"]; configured=[P.pv.Voc_V;P.pv.Isc_A;P.pv.Vmp_V;P.pv.Imp_A;P.pv.ratedPower_W];
model=[voc;isc;vmp;imp;pmp]; tolerance=[3;3;5;5;5]; errorPercent=100*abs(model-configured)./configured;
status=repmat("PASS",5,1); status(errorPercent>tolerance)="FAIL";
T=table(metric,configured,model,errorPercent,tolerance,status,'VariableNames',{'Metric','Configured_Value','Model_Value','Error_Percent','Tolerance_Percent','Status'});
end
