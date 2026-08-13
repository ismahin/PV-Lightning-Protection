# Simscape Electrical component model

`model/PV_Lightning_Protection_Simscape.slx` is the physical-component companion to the verified code-oriented model.

The electrical plant uses Simscape and Simscape Electrical library components:

- Solar Cell PV source;
- averaged boost DC-DC converter;
- physical cable/source resistors and inductors;
- controlled lightning voltage source;
- DC-link capacitor;
- library Varistor with project clamp, leakage, and dynamic-resistance values, plus lead and earth impedance;
- Supercapacitor and controlled bidirectional current interface;
- physical protected-load contactor;
- physical protected DC inverter-equivalent load and an isolated controlled AC output source with resistor load;
- physical voltage/current sensors, electrical reference, and solver configuration.

The MPPT, magnitude-duration protection state machine, relay operating delay, and supercapacitor current command retain the existing MATLAB S-functions. These are control algorithms rather than electrical components.

## Build and run

From the project root in MATLAB:

```matlab
startup_project
build_simscape_component_model
open_system('model/PV_Lightning_Protection_Simscape.slx')
sim('PV_Lightning_Protection_Simscape')
```

The default scenario is `T05` (severe design transient), selected so both MOV stages and the isolation response are visible. Press **Run** once and wait for the simulation to finish (about 50 seconds on the development machine). The Scopes stay closed during the run. After completion, double-click them in this order:

1. `01 - PV Array and MPPT`: PV voltage, current, power, and MPPT duty cycle.
2. `02 - SPD1 Direct Lightning`: applied lightning voltage, SPD1 terminal voltage, incoming surge current, and SPD1 discharge current.
3. `03 - SPD2 Indirect Lightning`: voltage arriving from SPD1, protected-bus residual voltage, SPD2 discharge current, and SPD1 discharge current for coordination comparison.
4. `04 - Supercapacitor Buffer`: protected-bus voltage, supercapacitor voltage, current, and power.
5. `05 - Automated Disconnection`: monitored voltage, controller state, relay command, and physical relay state.
6. `06 - Inverter and Load`: inverter DC input voltage, inverter connection state, AC load voltage, and AC load current.

Each Scope uses four vertically separated axes, automatic scaling, grid lines, and signal legends. They do not open automatically, so the full simulation can complete before you inspect them one by one.

The corresponding workspace logs include `Simscape_spd1_voltage`, `Simscape_spd_current`, `Simscape_spd2_current`, `Simscape_bus_voltage`, `Simscape_sc_voltage`, `Simscape_sc_current`, `Simscape_ac_voltage`, `Simscape_ac_current`, `Simscape_relay_command`, `Simscape_controller_state`, and `Simscape_relay_state`.

To use another project scenario, generate `scenario_input` with `configure_scenario`, assign it to the model workspace, and set the model stop time to that scenario's `StopTime`.

## Comparison with the coded model

Run `verify_simscape_against_coded` to execute both T05 models and compare the source, protected bus, aggregate two-stage SPD discharge current, supercapacitor, load, and relay timing. The calibration tolerances are 3-10% for electrical values, 5 ms for trip/opening, and 30 ms for reconnection. These tolerances account for the physical component parasitics and the much smaller Simscape local-solver step.

The calibrated development run produced these principal results:

| Quantity | Coded model | Simscape model | Difference |
|---|---:|---:|---:|
| PV power before event | 202.33 W | 195.98 W | -3.14% |
| Peak protected DC bus | 69.83 V | 70.65 V | +1.17% |
| Peak aggregate SPD current | 344.87 A | 338.60 A | -1.82% |
| Peak supercapacitor voltage | 30.983 V | 30.901 V | -0.27% |
| Peak supercapacitor current | 16.364 A | 16.364 A | <0.01% |
| Load power before event | 178.00 W | 188.75 W | +6.04% |

The MPPT, boost state equations, protection state machine, relay timing, and supercapacitor command remain the project algorithms. Their electrical interfaces use controlled Simscape sources so the physical Solar Cell, capacitor, MOV, supercapacitor, contactor, sensors, grounding impedances, and loads remain actual library components.
