function metrics = evaluate_scenario(result,P)
%EVALUATE_SCENARIO Correct event-window and component-capability metrics.
s=result.signals; scenario=result.scenario; T=calculate_transient_metrics(s,P,scenario); E=calculate_energy_metrics(s,P,scenario); Q=calculate_mppt_metrics(s,scenario,P);
metrics=T;
metrics.spdEnergy_J=E.spdTotal_J; metrics.spdEventEnergy_J=E.spdEvent_J; metrics.spdCumulativeEnergy_J=E.spdCumulative_J; metrics.spdEnergyUtilization_percent=E.spdUtilization_percent;
metrics.scAbsorbed_J=E.scAbsorbedTotal_J; metrics.scReleased_J=E.scReleasedTotal_J; metrics.scEventAbsorbed_J=E.scAbsorbedEvent_J; metrics.scEventReleased_J=E.scReleasedEvent_J;
metrics.scBaselineEnergy_J=E.scBaselineAbsorbed_J-E.scBaselineReleased_J; metrics.scIncrementalEventEnergy_J=E.scIncrementalEvent_J; metrics.scESRLoss_J=E.scESRLossTotal_J; metrics.scESREventLoss_J=E.scESRLossEvent_J; metrics.scStoredDelta_J=E.scStoredDelta_J;
metrics.loadEnergy_J=E.loadTotal_J; metrics.loadEventEnergy_J=E.loadEvent_J; metrics.pvEnergy_J=E.pvTotal_J;
metrics.mpptStartupEfficiency_percent=Q.startupEfficiency_percent; metrics.mpptEfficiency_percent=Q.steadyEfficiency_percent; metrics.mpptRecoveryTime_s=Q.recoveryTime_s; metrics.mpptPostStepEfficiency_percent=Q.postStepEfficiency_percent; metrics.mpptTrackingError_percent=Q.steadyTrackingError_percent; metrics.dutyCycleRipple=Q.dutyCycleRipple; metrics.irradianceStepConfirmed=Q.irradianceStepConfirmed; metrics.availableMPPChanged=Q.availableMPPChanged;
metrics.emergencyObserved=any(s.emergency_flag.Data>0.5); metrics.currentLimitObserved=any(s.sc_current_limit_flag.Data>0.5); metrics.currentLimitDuration_s=max(s.sc_current_limit_duration.Data);
metrics.spdCurrentCapabilityExceeded=any(s.spd_saturation_flag.Data>0.5); metrics.spdEnergyCapabilityExceeded=E.spdCumulative_J>P.spd.energyRating_J;
if any(s.spd_overstress_state.Data>=3), metrics.spdCapabilityStatus="FAILED"; elseif metrics.spdCurrentCapabilityExceeded || metrics.spdEnergyCapabilityExceeded, metrics.spdCapabilityStatus="OVERSTRESSED"; else, metrics.spdCapabilityStatus="SAFE"; end
critical=[s.dc_bus_voltage.Data;s.spd_current.Data;s.spd_demanded_current.Data;s.sc_actual_current.Data;s.sc_internal_voltage.Data;s.pv_power.Data];
metrics.nanInfCount=sum(~isfinite(critical));
metrics.expectedOverstressDetection=logical(scenario.IsIntentionalOverstress) && (metrics.spdCurrentCapabilityExceeded || metrics.spdEnergyCapabilityExceeded);
metrics.unexpectedSPDCurrentViolation=~scenario.IsIntentionalOverstress && metrics.spdCurrentCapabilityExceeded;
metrics.unexpectedSPDEnergyViolation=~scenario.IsIntentionalOverstress && metrics.spdEnergyCapabilityExceeded;
metrics.unexpectedSCCurrentViolation=metrics.peakSCCurrent_A>P.sc.maximumCurrent_A*1.001;
metrics.unexpectedSCVoltageViolation=metrics.scInternalMax_V>P.sc.ratedVoltage_V+1e-6 || metrics.scInternalMin_V<P.sc.minimumVoltage_V-1e-6;
metrics.unexpectedComponentViolations=sum([metrics.unexpectedSPDCurrentViolation metrics.unexpectedSPDEnergyViolation metrics.unexpectedSCCurrentViolation metrics.unexpectedSCVoltageViolation]);
metrics.executionTime_s=result.executionTime_s;
end
