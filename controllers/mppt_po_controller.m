function duty = mppt_po_controller(v,i,previousV,previousP,previousDuty,P)
%MPPT_PO_CONTROLLER Bounded perturb-and-observe duty update.
p=v*i; dv=v-previousV; dp=p-previousP; duty=previousDuty;
if abs(dp)>1e-6 && abs(dv)>1e-6
    if dp/dv > 0, duty=duty-P.mppt.step; else, duty=duty+P.mppt.step; end
end
duty=min(P.mppt.dutyMax,max(P.mppt.dutyMin,duty));
if ~isfinite(duty), duty=P.mppt.initialDuty; end
end
