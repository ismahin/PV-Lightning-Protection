# Simscape Electrical component model

`model/PV_Lightning_Protection_Simscape.slx` is the physical-component companion to the verified code-oriented model. It combines the previous PV, MPPT, boost, supercapacitor, relay and inverter implementation with the configurable indirect-lightning requirements.

The electrical plant uses Simscape and Simscape Electrical Solar Cell, R/L/C, Controlled Current Source, Varistor, Supercapacitor, Switch, sensor, electrical-reference and solver components. Code is retained only for MPPT, averaged converter state equations, supervisory protection, relay timing and supercapacitor control.

## User-editable settings

No code editing or rebuilding is required for a normal parameter change:

1. Open `model/PV_Lightning_Protection_Simscape.slx`.
2. Double-click the **USER SETTINGS - DOUBLE CLICK** block.
3. Change values under the **Lightning**, **SPD1**, **SPD2**, **Supercapacitor**, or **Relay** tab.
4. Press **Apply** or **OK**, then press **Run**.

The block contains 48 settings, including current/voltage injection selection, peak current and voltage, 8/20 us timing, source and cable impedance, both SPD models and ratings, supercapacitor values, voltage thresholds, and relay timing. In voltage mode, the physical current source and shunt resistor form the Norton equivalent of the requested voltage source and source resistance.

`config/simscape_user_settings.m` supplies only the defaults used when the model is regenerated. `simulation/apply_simscape_settings_mask.m` is the block's internal callback; users do not need to edit or run either file.

## Build and run

From the project root:

```matlab
startup_project
build_simscape_component_model
open_system('model/PV_Lightning_Protection_Simscape.slx')
```

Then use the settings block and the Simulink **Run** button. The selected values are stored in the `.slx` file when the model is saved.

The default is a 10 kA line-to-ground current injection. The normalized pulse reaches 100% at 8 us and 50% at 20 us. The physical DC network uses a 4 us local solver step; the commanded waveform is retained at 0.25 us resolution for accurate display and timing checks.

After the run, open the Scopes in order:

1. `01 - PV Array and MPPT`: PV voltage, current, power and MPPT duty cycle.
2. `02 - Indirect Lightning Injection`: configured current/voltage and measured injection current/voltage.
3. `03 - SPD1 Diversion and Output`: injected, diverted and residual currents plus SPD1 voltage.
4. `04 - SPD2 Diversion and Output`: SPD2 diverted current, physical residual current, protected bus and SPD2 voltage.
5. `05 - Supercapacitor Buffer`: voltage, current, power and cumulative absorbed energy.
6. `06 - Relay Thresholds and Timing`: bus voltage, warning/emergency/recovery thresholds, command and physical contact state.
7. `07 - Input versus Protected Output`: injection, SPD1, SPD2 and protected-output voltages.
8. `08 - Inverter and Load`: protected bus, contact state, AC voltage and AC current.

All Scopes stay closed during simulation and use separate axes with legends and automatic scaling.

## Physical interpretation

SPD1 is mounted at the cable entry and diverts most of the injected current. The residual passes through cable impedance to the SPD2 node. SPD2 has a lower protective level and a small coordination impedance separates its node from the existing 20 mF protected DC link. This lets the second diversion stage be measured without changing the normal DC-link capacitance.

The MOVs and DC-link capacitor handle the microsecond surge. The 15 F supercapacitor and its 18 A converter handle the slower post-surge bus-energy disturbance; they are not represented as a device capable of directly absorbing 10 kA. Its usable energy is evaluated from `0.5*C*(Vmax^2-Vmin^2)`.

The relay cannot mechanically open within an 8/20 us pulse. Its Scope therefore shows whether the protected bus crosses the editable thresholds and shows the configured 8 ms opening, 350 ms safe dwell and 12 ms closing behavior for disturbances that require isolation.

## Verification

Run:

```matlab
verify_indirect_lightning_simscape
verify_simscape_against_coded
verify_simscape_settings_panel
```

The first check verifies the 10 kA peak, 8/20 us timing, SPD1 diversion, SPD2 operation, residual reduction, protected-bus limit and supercapacitor current. The second verifies that PV, bus, supercapacitor and load behavior before the new event remain aligned with the coded model. The third changes the actual settings-mask values, executes current and voltage injection cases, checks that the measured physical outputs change, enforces a changed supercapacitor current limit, and restores the saved defaults automatically. The fast surge test is standards-inspired numerical evidence, not a certification test or a claim about a commercial SPD.
