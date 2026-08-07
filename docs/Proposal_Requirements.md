# Proposal-derived requirements

Primary source: *Lightning and Surge Protection of Photovoltaic Installation*, Ihtisham Fazil, proposal pages 1–10 (remaining PDF pages are blank).

The proposal identifies lightning-induced and switching overvoltage as threats to exposed PV installations and sensitive MPPT, inverter, battery, and control electronics. Its research gap is that fixed-threshold diversion and immediate relay disconnection do not evaluate event duration or energy, can cause unnecessary shutdowns, and do not buffer short disturbances.

## Extracted requirements

| ID | Proposal requirement | Source |
|---|---|---|
| PR-01 | Small-scale laboratory PV source | Methodology, p. 6; Safety, p. 8 |
| PR-02 | MPPT-based charge/power extraction using voltage and current sensing | Methodology, p. 6 |
| PR-03 | DC-side SPD/MOV surge diversion and grounded coordination | Abstract; State of art, pp. 4–6 |
| PR-04 | Lightning-induced transient overvoltage injection | Simulation strategy, p. 8 |
| PR-05 | Supercapacitor buffering of brief ripple/residual energy | pp. 2–3 and 6–7 |
| PR-06 | Regulated switching interface, balance, and protection for supercapacitors | p. 7 |
| PR-07 | Controller evaluates both voltage magnitude and duration | pp. 3 and 7 |
| PR-08 | Brief disturbance handled without unnecessary disconnection | pp. 3 and 6–7 |
| PR-09 | Severe/prolonged overvoltage isolates the protected branch | pp. 3 and 7 |
| PR-10 | Relay driver/contactor behavior with automatic and manual reset | p. 7 |
| PR-11 | Normal and fault simulations verify response and coordination before hardware | p. 8 |
| PR-12 | Downstream microinverter/load representation | Abstract and p. 6 |
| PR-13 | Controlled, low-voltage laboratory interpretation rather than real lightning | Safety, p. 8 |
| PR-14 | Compare the integrated method against conventional protection | Problem and impact, pp. 2–3 |
| PR-15 | Improve voltage stability, uptime, and protection coordination | pp. 3 and 5 |

The proposal methodology names Proteus. This implementation uses MATLAB/Simulink at the user's explicit direction while preserving the proposed functional tests and safe low-voltage scope.
