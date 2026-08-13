# PV Lightning and Surge Protection

This is the canonical MATLAB/Simulink implementation of the low-voltage PV surge-protection study.

## Run

Open this directory in MATLAB and execute:

```matlab
main
```

`main` cleans only known generated output folders, builds `model/PV_Lightning_Protection.slx`, executes the complete verification suite, replaces and reads back all result tables, regenerates figures, renders HTML and PDF reports, checks repeatability, and leaves one definitive output set under `results`.

With Simscape and Simscape Electrical installed, run `build_simscape_component_model` to regenerate the final physical-component model `model/PV_Lightning_Protection_Simscape.slx`. It uses Solar Cell, averaged boost interfaces, physical R/L/C components, two coordinated Varistors, Supercapacitor, contactor, controlled AC source/load, sensors, and Scope blocks from the installed libraries. See `docs/Simscape_Component_Model.md`.

The physical model follows the protection-priority order with six numbered Scopes: PV/MPPT, SPD1 direct lightning, SPD2 indirect lightning, supercapacitor buffer, automated disconnection, and inverter/load. Run the model first, then open Scopes `01` through `06` after it finishes.

Run `verify_simscape_against_coded` to compare the final Simscape T05 outputs with the verified coded model.

## Implementation

The model visibly separates scenario inputs, PV source, MPPT controller, averaged boost converter, cable/source impedance, surge generator, DC-bus dynamics, SPD/MOV, supercapacitor interface, protection controller, physical contactor, averaged microinverter/load, and measurements.

The installed environment contains MATLAB and Simulink but not Simscape or Simscape Electrical. Component equations are therefore implemented with focused Level-2 MATLAB S-functions. The same single-diode PV and MOV functions are reused across plant, curves, MPP, system transients and fast component tests.

The selected SPD ratings are documented engineering assumptions with margins against executed design cases. One separate scenario intentionally exceeds the SPD envelope to verify capability detection; it is not used to support safe-design conclusions.

## Outputs

- `results/raw`: logged histories and scenario metrics
- `results/tables`: the 17 definitive XLSX/CSV evidence tables
- `results/figures`: PNG, FIG and PDF figures from the current run
- `results/reports`: browser-rendered HTML and A4 PDF evaluation report
- `results/logs/main_execution_log.txt`: one non-appended execution transcript

## Limitations

This is a low-voltage averaged laboratory study. It is not direct-strike reproduction, certified SPD testing, insulation coordination, full-system EMT validation, grid-compliance testing, or hardware qualification. Commercial component selection requires supplied manufacturer data and applicable standards.
