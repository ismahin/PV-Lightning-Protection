# Model architecture

The canonical executable plant is `model/PV_Lightning_Protection.slx`.

Its top level contains functional subsystems for Scenario Inputs, PV Source, MPPT Controller, Averaged Boost Converter, Cable and Source Impedance, Surge Generator, DC Bus Dynamics, SPD MOV, Supercapacitor Interface, Protection Controller, Relay Contactor, Averaged Microinverter Protected Load, and Measurements and Logging.

Protection modes share the same plant, input profiles, solver, initial states and load. Only protection configuration changes:

- mode 0: unprotected;
- mode 1: SPD only;
- mode 2: startup-qualified conventional fixed-threshold relay plus SPD;
- mode 3: integrated SPD, supercapacitor and magnitude-duration controller.

Paired comparisons are marked valid only after programmatic equality checks and pre-event relay/load/arming assertions. The switching low-voltage inverter is a separate focused model named `Microinverter_Switching_Demo.slx`.
