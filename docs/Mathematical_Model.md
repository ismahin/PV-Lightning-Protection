# Mathematical model

## Current and power conventions

Positive supercapacitor current flows from the DC bus into the supercapacitor and therefore means charging. The implemented equations are

`Vsc_terminal = Vsc_internal + Isc*RESR`

`Psc_terminal = Vsc_terminal*Isc`

and `Psc_terminal > 0` is absorbed power. When `Isc < 0`, released-energy magnitude is the integral of `-Psc_terminal`. ESR power is always

`Pesr = Isc^2*RESR >= 0`.

The bus balance subtracts positive charging current:

`Cbus*dVbus/dt = Iboost + Isurge - Ispd - Isc_bus - Iload`.

Positive SPD current flows from the DC bus into the protective branch.

## PV and converter

The PV source, I-V/P-V curves and MPP reference share

`I = Iph - I0*(exp((V + I*Rs)/(n*Ns*Vt)) - 1) - (V + I*Rs)/Rsh`.

The averaged boost inductor follows

`L*diL/dt = Vpv - (1-D)*Vbus - RL*iL`.

## MOV

Below MCOV the MOV carries configured leakage. Above its knee the demanded current is a configurable nonlinear power law. `mov_demanded_current`, `mov_actual_current`, `mov_capability_state` and `mov_energy_update` are shared by the system and both fast tests. Demanded current, actual finite current, saturation duration and energy status remain separate.

## Timing

Protection is armed only after blanking and a continuous healthy-voltage qualification. Automatic recovery starts at the beginning of the uninterrupted safe interval that ultimately leads to reconnect. Leaving the safe band resets the timer. Trip/reconnect command times are distinct from physical opening/closing times.

Settling time is an elapsed duration from the scenario-specific measurement start to the beginning of the first continuous stable dwell. It is never an absolute simulation timestamp.
