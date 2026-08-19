# PV Lightning and Surge Protection

This is the canonical MATLAB/Simulink implementation of the low-voltage PV surge-protection study.

## Run

Open this directory in MATLAB and execute:

```matlab
main
```

`main` cleans only known generated output folders, builds `model/PV_Lightning_Protection.slx`, executes the complete verification suite, replaces and reads back all result tables, regenerates figures, renders HTML and PDF reports, checks repeatability, and leaves one definitive output set under `results`.

With Simscape and Simscape Electrical installed, open the final physical-component model `model/PV_Lightning_Protection_Simscape.slx`. It uses Solar Cell, averaged boost interfaces, physical R/L/C components, two coordinated Varistors, Supercapacitor, contactor, controlled AC source/load, sensors, and Scope blocks from the installed libraries. See `docs/SIMSCAPE_COMPONENT_MODEL.md`.

The physical model now opens as a functional workflow with eight individual electrical stages: **03A PV ARRAY**, **03B SURGE SOURCE & CABLE**, **03C SPD1 PRIMARY PROTECTION**, **03D SPD2 COORDINATED PROTECTION**, **03E PROTECTED DC BUS**, **03F SUPERCAPACITOR BANK**, **03G RELAY & DC LOAD**, and **03H INVERTER & AC LOAD**. All 76 Simscape/Simscape Electrical library components remain in these stages. Every command input is labeled with its meaning and unit, and unused Mux/Demux ports and open signal stubs have been removed. Double-click **08 RESULTS - SCOPES & LOGGING** to open the eight numbered Scopes. Double-click **USER SETTINGS - DOUBLE CLICK**, edit inputs or thresholds, press **Apply** or **OK**, and run. No code editing or rebuild is needed.

`build_simscape_component_model` is needed only to regenerate the `.slx` from its source builder. The settings saved inside the model remain the normal user interface.

Run `verify_indirect_lightning_simscape` for the 10 kA 8/20 us path, `verify_simscape_against_coded` for the pre-surge normal-operation regression, and `verify_simscape_settings_panel` to execute changed current/voltage settings from the model control panel and confirm that the physical outputs change.

The illustrated measured-results summary is available in `docs/PV_Simscape_Step_by_Step_Report.docx`.

## Implementation

The model visibly separates scenario inputs, PV source, MPPT controller, averaged boost converter, cable/source impedance, surge generator, DC-bus dynamics, SPD/MOV, supercapacitor interface, protection controller, physical contactor, averaged microinverter/load, and measurements.

The physical companion model uses the installed Simscape and Simscape Electrical libraries. The original code-oriented model remains available for regression, parameter studies and the existing project test suite.

The selected SPD ratings are documented engineering assumptions with margins against executed design cases. One separate scenario intentionally exceeds the SPD envelope to verify capability detection; it is not used to support safe-design conclusions.

## Outputs

- `results/raw`: logged histories and scenario metrics
- `results/tables`: the 17 definitive XLSX/CSV evidence tables
- `results/figures`: PNG, FIG and PDF figures from the current run
- `results/reports`: browser-rendered HTML and A4 PDF evaluation report
- `results/logs/main_execution_log.txt`: one non-appended execution transcript

## Limitations

This is a low-voltage averaged laboratory study. It is not direct-strike reproduction, certified SPD testing, insulation coordination, full-system EMT validation, grid-compliance testing, or hardware qualification. Commercial component selection requires supplied manufacturer data and applicable standards.
