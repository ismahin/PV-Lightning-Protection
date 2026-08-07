function L = validation_limits(P)
%VALIDATION_LIMITS Acceptance limits derived from ratings/assumptions.
L.normalVoltageMin_V = 0.95*P.bus.nominalVoltage_V;
L.normalVoltageMax_V = 1.05*P.bus.nominalVoltage_V;
L.warningVoltage_V = P.controller.warning_pu*P.bus.nominalVoltage_V;
L.emergencyVoltage_V = P.controller.emergency_pu*P.bus.nominalVoltage_V;
L.maxSPDCurrent_A = P.spd.maxCurrent_A;
L.maxSPDEnergy_J = P.spd.energyRating_J;
L.maxSCVoltage_V = P.sc.ratedVoltage_V;
L.minSCVoltage_V = P.sc.minimumVoltage_V;
L.maxSCCurrent_A = P.sc.maximumCurrent_A*1.01;
L.minimumMPPTPercent = 90;
L.maxNaNInf = 0;
L.solverTolerance_percent = P.validation.solverTolerance_percent;
end
