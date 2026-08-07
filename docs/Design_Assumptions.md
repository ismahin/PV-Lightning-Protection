# Design assumptions and provenance

The proposal defines the protection concept but does not supply commercial component data. Panel, MOV, supercapacitor, converter, cable and timing values are therefore explicit engineering assumptions.

- PV module: 200 W nominal, Voc 43.2 V, Isc 6.15 A, Vmp 36 V and Imp 5.56 A.
- DC bus: 48 V nominal with a 20 mF bus capacitor.
- Production solver: fixed-step discrete at 0.25 ms; convergence uses 0.125 ms and a 3% maximum important-metric tolerance.
- Protection arming: 0.20 s startup blanking followed by 0.04 s continuously healthy voltage between 0.95 and 1.05 pu.
- Integrated protection: warning at 1.10 pu, emergency at 1.45 pu, allowed warning duration 45 ms, safe recovery at 0.85-1.07 pu for 350 ms, opening delay 8 ms and closing delay 12 ms.
- SPD: 58 V MCOV, 62 V knee, shared nonlinear power-law characteristic, 1000 A selected current rating and 2000 J selected energy rating. Both current and energy design margins must be at least 1.20 against the worst executed design case. These values are datasheet-style engineering assumptions, not a certified commercial-device claim.
- Supercapacitor: 15 F, 30 V initial, 20-38 V operating range, 55 mOhm ESR, 18 A converter limit, 1.5 mH path inductance and dynamic current controller.
- Positive SC current means charging from the DC bus into the supercapacitor.
- System impulses are laboratory-scale averaged disturbances. Separate 1.2/50 us and 8/20 us numerical component tests are standards-inspired and not compliance tests.
- The switching inverter is a safe 24 V RMS, 50 Hz demonstration and does not claim grid compliance.

All design scenarios must remain inside selected component ratings. `T16` alone is intentionally outside the SPD design envelope and must produce an explicit capability-exceeded state.
