function [state,relayCommand,tOver,tSafe,warning,emergency] = protection_logic(v,state,tOver,tSafe,manualReset,autoReset,P,dt)
%PROTECTION_LOGIC Magnitude-duration supervisor after startup qualification.
% Positive state sequence: NORMAL, BUFFERING, WARNING, ISOLATED,
% RECOVERY_DELAY, RECONNECTED, LOCKOUT.
warning=v>P.controller.warning_pu*P.bus.nominalVoltage_V;
emergency=v>P.controller.emergency_pu*P.bus.nominalVoltage_V;
safe=v<=P.controller.safeRecovery_pu*P.bus.nominalVoltage_V && ...
 v>=P.controller.lowSafe_pu*P.bus.nominalVoltage_V;
buffering=v>P.bus.nominalVoltage_V+P.sc.deadband_V;
relayCommand=true;
switch state
 case {1,6}
  tSafe=0;
  if emergency
   state=4; relayCommand=false; tOver=0;
  elseif warning
   state=3; tOver=dt;
  elseif buffering
   state=2; tOver=0;
  else
   state=1; tOver=0;
  end
 case 2
  if emergency
   state=4; relayCommand=false; tOver=0;
  elseif warning
   state=3; tOver=dt;
  elseif buffering
   state=2; tOver=0;
  else
   state=1; tOver=0;
  end
 case 3
  if emergency
   state=4; relayCommand=false; tOver=0;
  elseif warning
   tOver=tOver+dt;
   if tOver>=P.controller.allowedDuration_s, state=4; relayCommand=false; end
  else
   if buffering, state=2; else, state=1; end; tOver=0;
  end
 case 4
  relayCommand=false; tOver=0; tSafe=0;
  if safe, state=5; tSafe=dt; end
 case 5
  relayCommand=false;
  if ~safe
   state=4; tSafe=0;
  else
   tSafe=tSafe+dt;
   dwellComplete=tSafe>=P.controller.recoveryDelay_s;
   if dwellComplete && (autoReset || manualReset)
    state=6; relayCommand=true; tOver=0;
   end
  end
 otherwise
  state=4; relayCommand=false; tOver=0; tSafe=0;
end
end
